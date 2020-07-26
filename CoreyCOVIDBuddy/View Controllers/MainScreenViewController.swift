//
//  MainScreenViewController.swift
//  CoreyCOVIDBuddy
//
//  Copyright © 2020 Gregory Okhuereigbe. All rights reserved.
//

import UIKit
import NVActivityIndicatorView
import Assistant
import MessageKit
import MapKit
import BMSCore
import FirebaseAuth
import Firebase
import FirebaseFirestore
import CoreGraphics

class MainScreenViewController: MessagesViewController, NVActivityIndicatorViewable {

    //Firebase Database
    let db = Firestore.firestore()
    
    //User Credentials
    let email = Auth.auth().currentUser?.email
    let uid = Auth.auth().currentUser?.uid
    
    fileprivate let kCollectionViewCellHeight: CGFloat = 12.5

    // Messages State
    var messageList: [AssistantMessages] = []

    var now = Date()

    // Conersation SDK
    var assistant: Assistant?
    var context: Context?

    // Watson Assistant Workspace
    var workspaceID: String?

    // Users
    var current = Sender(id: "123456", displayName: "Me")
    let watson = Sender(id: "654321", displayName: "Corey")

    

    // UIButton to initiate login
    @IBOutlet weak var logoutButton: UIButton!

    override func viewDidLoad() {

        super.viewDidLoad()
        
        // Instantiate Assistant Instance
        self.instantiateAssistant()

        // Instantiate activity indicator
        self.instantiateActivityIndicator()
        
        // Registers data sources and delegates + setup views
        self.setupMessagesKit()

        // Register observer
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didBecomeActive),
                                               name: Notification.Name("didBecomeActiveNotification"),
                                               object: nil)

        
        
        
        
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.becomeFirstResponder()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func didBecomeActive(_ notification: Notification) {
        
        
    }

    // MARK: - Setup Methods

    // Method to instantiate assistant service
    func instantiateAssistant() {

        // Start activity indicator
        startAnimating( message: "Connecting to Corey", type: NVActivityIndicatorType.ballScaleRipple)

        // Create a configuration path for the BMSCredentials.plist file then read in the Watson credentials
        // from the plist configuration dictionary
        guard let configurationPath = Bundle.main.path(forResource: "BMSCredentials", ofType: "plist"),
              let configuration = NSDictionary(contentsOfFile: configurationPath) else {

            showAlert(.missingCredentialsPlist)
            return
        }

        // API Version Date to initialize the Assistant API
        let date = "2020-04-01"

        // Set the Watson credentials for Assistant service from the BMSCredentials.plist
        // If using IAM authentication
        if let apikey = (configuration["conversation"] as? NSDictionary)?["apikey"] as? String,
           let url = (configuration["conversation"] as? NSDictionary)?["url"] as? String {

                // Initialize Watson Assistant object
                let authenticator = WatsonIAMAuthenticator(apiKey: apikey)
                let assistant = Assistant(version: date, authenticator: authenticator)

                // Set the URL for the Assistant Service
                assistant.serviceURL = url

                self.assistant = assistant

        } else {
            showAlert(.missingAssistantCredentials)
        }

        // Lets Handle the Workspace creation or selection from here.
        // If a workspace is found in the plist then use that WorkspaceID that is provided , otherwise
        // look up one from the service directly, Watson provides a sample so this should work directly
        if let workspaceID = configuration["workspaceID"] as? String {

            print("Workspace ID:", workspaceID)

            // Set the workspace ID Globally
            self.workspaceID = workspaceID

            // Ask Watson for its first message
            retrieveFirstMessage()
            
            //Test To Correct Chat Bar Issue
            //self.workspaceList()

        } else {

            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.5) {
                NVActivityIndicatorPresenter.sharedInstance.setMessage("Checking for Training...")
            }

            // Retrieve a list of Workspaces that have been trained and default to the first one
            // You can define your own WorkspaceID if you have a specific Assistant model you want to work with
            guard let assistant = assistant else {
              return
            }

            assistant.listWorkspaces { response, error in
                if let error = error {
                    self.failAssistantWithError(error)
                    return
                }

                guard let workspaces = response?.result else {
                    self.showAlert(.noWorkspacesAvailable)
                    return
                }

                self.workspaceList(workspaces)
            }
        }
    }

    // Method to start convesation from workspace list
    func workspaceList(_ list: WorkspaceCollection) {

        // Lets see if the service has any training model deployed
        guard let workspace = list.workspaces.first else {
            showAlert(.noWorkspacesAvailable)
            return
        }

        // Check if we have a workspace ID
        guard !workspace.workspaceID.isEmpty else {
            showAlert(.noWorkspaceId)
            return
        }

        // Now we have an WorkspaceID we can ask Watson Assisant for its first message
        self.workspaceID = workspace.workspaceID

        // Ask Watson for its first message
        retrieveFirstMessage()

    }

    // Method to handle errors with Watson Assistant
    func failAssistantWithError(_ error: Error) {
        showAlert(.error(error.localizedDescription))
    }

    // Method to set up the activity progress indicator view
    func instantiateActivityIndicator() {
        let size: CGFloat = 50
        let x = self.view.frame.width/2 - size
        let y = self.view.frame.height/2 - size

        let frame = CGRect(x: x, y: y, width: size, height: size)

        _ = NVActivityIndicatorView(frame: frame, type: NVActivityIndicatorType.ballScaleRipple)
    }

    // Method to set up messages kit data sources and delegates + configure
    func setupMessagesKit() {

        // Register datasources and delegates
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self

        // Configure views
        messageInputBar.sendButton.tintColor = UIColor(red: 69/255, green: 193/255, blue: 89/255, alpha: 1)
        scrollsToBottomOnKeybordBeginsEditing = true // default false
        maintainPositionOnKeyboardFrameChanged = true // default false
    }

    // Retrieves the first message from Watson
    func retrieveFirstMessage() {

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.5) {
            NVActivityIndicatorPresenter.sharedInstance.setMessage("Talking to Corey...")
        }

        guard let assistant = self.assistant else {
            showAlert(.missingAssistantCredentials)
            return
        }

        guard let workspace = workspaceID else {
            showAlert(.noWorkspaceId)
            return
        }

        // Initial assistant message from Watson
        assistant.message(workspaceID: workspace) { response, error in
            if let error = error {
                self.failAssistantWithError(error)
                return
            }
            guard let watsonMessages = response?.result else {
                self.showAlert(.noWorkspaceId)
                return
            }

            for watsonMessage in watsonMessages.output.text {
                // Set current context
                self.context = watsonMessages.context

                DispatchQueue.main.async {

                    // Add message to assistant message array
                    let uniqueID = UUID().uuidString
                    let date = self.dateAddingRandomTime()

                    let attributedText = NSAttributedString(string: watsonMessage,
                                                                        attributes: [.font: UIFont.systemFont(ofSize: 18),
                                                                                     .foregroundColor: UIColor.blue])

                    // Create a Message for adding to the Message View
                    let message = AssistantMessages(attributedText: attributedText, sender: self.watson, messageId: uniqueID, date: date)

                    // Add the response to the Message View
                    self.messageList.insert(message, at: 0)
                    self.messagesCollectionView.reloadData()
                    self.messagesCollectionView.scrollToBottom()
                    self.stopAnimating()
                }
            }
        }
    }

    // Method to create a random date
    func dateAddingRandomTime() -> Date {
        let randomNumber = Int(arc4random_uniform(UInt32(10)))
        var date: Date?
        if randomNumber % 2 == 0 {
            date = Calendar.current.date(byAdding: .hour, value: randomNumber, to: now) ?? Date()
        } else {
            let randomMinute = Int(arc4random_uniform(UInt32(59)))
            date = Calendar.current.date(byAdding: .minute, value: randomMinute, to: now) ?? Date()
        }
        now = date ?? Date()
        return now
    }

    // Method to show an alert with an alertTitle String and alertMessage String
    func showAlert(_ error: AssistantError) {
        // Log the error to the console
        print(error)

        DispatchQueue.main.async {

            // Stop animating if necessary
            self.stopAnimating()

            // If an alert is not currently being displayed
            if self.presentedViewController == nil {
                // Set alert properties
                let alert = UIAlertController(title: error.alertTitle,
                                              message: error.alertMessage,
                                              preferredStyle: .alert)
                // Add an action to the alert
                alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertAction.Style.default, handler: nil))
                // Show the alert
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    // Method to retrieve assistant avatar
    func getAvatarFor(sender: Sender) -> Avatar {
        switch sender {
        case current:
            return Avatar(image: UIImage(named: "avatar_small"), initials: "Me")
        case watson:
            return Avatar(image: UIImage(named: "watson_avatar"), initials: "C")
        default:
            return Avatar()
        }
    }
}

// MARK: - MessagesDataSource
extension MainScreenViewController: MessagesDataSource {

    func currentSender() -> Sender {
        return current
    }

    func numberOfMessages(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messageList.count
    }

    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messageList[indexPath.section]
    }

    func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let name = message.sender.displayName
        return NSAttributedString(string: name, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption1)])
    }

    func cellBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {

        struct AssistantDateFormatter {
            static let formatter: DateFormatter = {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter
            }()
        }
        let formatter = AssistantDateFormatter.formatter
        let dateString = formatter.string(from: message.sentDate)
        return NSAttributedString(string: dateString, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption2)])
    }

}

// MARK: - MessagesDisplayDelegate
extension MainScreenViewController: MessagesDisplayDelegate {

    // MARK: - Text Messages

    func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? .white : .darkText
    }

    func detectorAttributes(for detector: DetectorType, and message: MessageType, at indexPath: IndexPath) -> [NSAttributedString.Key: Any] {
        return MessageLabel.defaultAttributes
    }

    func enabledDetectors(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> [DetectorType] {
        return [.url, .address, .phoneNumber, .date]
    }

    // MARK: - All Messages

    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? UIColor(red: 8/255, green: 127/255, blue: 254/255, alpha: 1) : UIColor(red: 230/255, green: 230/255, blue: 230/255, alpha: 1)
    }

    func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        let corner: MessageStyle.TailCorner = isFromCurrentSender(message: message) ? .bottomRight : .bottomLeft
        return .bubbleTail(corner, .curved)
    }

    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {

        let avatar = getAvatarFor(sender: message.sender)
        avatarView.set(avatar: avatar)
    }

    // MARK: - Location Messages
    func annotationViewForLocation(message: MessageType, at indexPath: IndexPath, in messageCollectionView: MessagesCollectionView) -> MKAnnotationView? {
        let annotationView = MKAnnotationView(annotation: nil, reuseIdentifier: nil)
        let pinImage = #imageLiteral(resourceName: "pin")
        annotationView.image = pinImage
        annotationView.centerOffset = CGPoint(x: 0, y: -pinImage.size.height / 2)
        return annotationView
    }

    func animationBlockForLocation(message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> ((UIImageView) -> Void)? {
        return { view in
            view.layer.transform = CATransform3DMakeScale(0, 0, 0)
            view.alpha = 0.0
            UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0, options: [], animations: {
                view.layer.transform = CATransform3DIdentity
                view.alpha = 1.0
            }, completion: nil)
        }
    }
}

// MARK: - MessagesLayoutDelegate
extension MainScreenViewController: MessagesLayoutDelegate {

    func avatarPosition(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> AvatarPosition {
        return AvatarPosition(horizontal: .natural, vertical: .messageBottom)
    }

    func messagePadding(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIEdgeInsets {
        if isFromCurrentSender(message: message) {
            return UIEdgeInsets(top: 0, left: 30, bottom: 0, right: 4)
        } else {
            return UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 30)
        }
    }

    func cellTopLabelAlignment(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> LabelAlignment {
        if isFromCurrentSender(message: message) {
            return .messageTrailing(UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10))
        } else {
            return .messageLeading(UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0))
        }
    }

    func cellBottomLabelAlignment(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> LabelAlignment {
        if isFromCurrentSender(message: message) {
            return .messageLeading(UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0))
        } else {
            return .messageTrailing(UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10))
        }
    }

    func footerViewSize(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGSize {

        return CGSize(width: messagesCollectionView.bounds.width, height: 10)
    }

    // MARK: - Location Messages

    func heightForLocation(message: MessageType, at indexPath: IndexPath, with maxWidth: CGFloat, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 200
    }

}

// MARK: - MessageCellDelegate

extension MainScreenViewController: MessageCellDelegate {

    func didTapAvatar(in cell: MessageCollectionViewCell) {
        print("Avatar tapped")
    }

    func didTapMessage(in cell: MessageCollectionViewCell) {
        print("Message tapped")
    }

    func didTapTopLabel(in cell: MessageCollectionViewCell) {
        print("Top label tapped")
    }

    func didTapBottomLabel(in cell: MessageCollectionViewCell) {
        print("Bottom label tapped")
    }

}

// MARK: - MessageLabelDelegate

extension MainScreenViewController: MessageLabelDelegate {

    func didSelectAddress(_ addressComponents: [String: String]) {
        print("Address Selected: \(addressComponents)")
    }

    func didSelectDate(_ date: Date) {
        print("Date Selected: \(date)")
    }

    func didSelectPhoneNumber(_ phoneNumber: String) {
        print("Phone Number Selected: \(phoneNumber)")
    }

    func didSelectURL(_ url: URL) {
        print("URL Selected: \(url)")
    }

}

// MARK: - MessageInputBarDelegate

extension MainScreenViewController: MessageInputBarDelegate {

    func messageInputBar(_ inputBar: MessageInputBar, didPressSendButtonWith text: String) {

        //Possible Values of Severity Ratings
        //var severityRatings:[Int] = [1,2,3,4,5,6,7,8,9]
        
        var feverSeverity = 0
        let coughSeverity = 0
        let shortBreathSeverity = 0
        let fatigueSeverity = 0
        let muscleAcheSeverity = 0
        let headacheSeverity = 0
        let lossTasteSeverity = 0
        let soreThroatSeverity = 0
        let congestionSeverity = 0
        let nauseaSeverity = 0
        let diarrheaSeverity = 0
        
        guard let assist = assistant else {
            showAlert(.missingAssistantCredentials)
            return
        }

        guard let workspace = workspaceID else {
            showAlert(.noWorkspaceId)
            return
        }

        let attributedText = NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: 18), .foregroundColor: UIColor.blue])
        let id = UUID().uuidString
        let message = AssistantMessages(attributedText: attributedText, sender: currentSender(), messageId: id, date: Date())
        messageList.append(message)
        inputBar.inputTextView.text = String()
        messagesCollectionView.insertSections([messageList.count - 1])
        messagesCollectionView.scrollToBottom()

        // cleanup text that gets sent to Watson, which doesn't care about whitespace or newline characters
        let cleanText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: ". ")

        // Pass the intent to Watson Assistant and get the response based on user text create a message
        // Call the Assistant API
        let input = MessageInput(text: cleanText)
        assist.message(workspaceID: workspace, input: input, context: context) { response, error in

            if let error = error {
                self.failAssistantWithError(error)
                return
            }

            guard let message = response?.result else {
                self.showAlert(.noData)
                return
            }

            for watsonMessage in message.output.text {
                guard !watsonMessage.isEmpty else {
                    continue
                }

                // Set current context
                self.context = message.context
                DispatchQueue.main.async {

                    let attributedText = NSAttributedString(string: watsonMessage, attributes: [.font: UIFont.systemFont(ofSize: 18), .foregroundColor: UIColor.blue])
                    let id = UUID().uuidString
                    let message = AssistantMessages(attributedText: attributedText, sender: self.watson, messageId: id, date: Date())
                    self.messageList.append(message)
                    inputBar.inputTextView.text = String()
                    self.messagesCollectionView.insertSections([self.messageList.count - 1])
                    self.messagesCollectionView.scrollToBottom()
                    
// MARK: - Capture Data/Save To FB
                    
                    //Checking if severity score was given and what score is. I'ts checking the symptom asked before the symptom currently being asked. First chunk is the inital question and sets up for the next quesitons
                    let stringtext = attributedText.string
                    if stringtext.contains("Are you coughing?")
                    {
                        //Checks to see wether user has last symptom...Input Validation for "No"
                        if cleanText.contains("No") || cleanText.contains("no") || cleanText.contains("Nope") || cleanText.contains("nope") || cleanText.contains("Np") || cleanText.contains("np") || cleanText.contains("Nah") || cleanText.contains("nah")
                        {
                            print("User does not have Fever/Chills.")
                        }
                        else
                        {
                            //Loop to see what score was given
                            for a in 1...10
                            {
                                if cleanText.contains(String(a))
                                {
                                    print("User has symptom (Fever/Chills)")
                                    print("Severity Score: \(a)")
                                    feverSeverity = a
                                }
                            }
                        }
                        
                        //Initial method to create severity report document in Firebase Database
                        let date = Date()
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "MMM dd, yyyy"
                        let cleanDate = dateFormatter.string(from: date)
                        
                        self.db.collection("Symptom Severity Tracker").document("\(self.email!) \(cleanDate)").setData( [
                            "email":self.email!,
                            "uid":self.uid!,
                            "date": date,
                            "Fever/Chills Severity Rating": String(feverSeverity),
                            "Cough Severity Rating": String(coughSeverity),
                            "Shortness of Breath Severity Rating": String(shortBreathSeverity),
                            "Fatigue Severity Rating": String(fatigueSeverity),
                            "Muscle or Body Ache Severity Rating": String(muscleAcheSeverity),
                            "Headache Severity Rating": String(headacheSeverity),
                            "Loss of Taste or Smell Severity Rating": String(lossTasteSeverity),
                            "Sore Throat Severity Rating": String(soreThroatSeverity),
                            "Congestion Severity Rating": String(congestionSeverity),
                            "Nausea or Vomiting Severity Rating": String(nauseaSeverity),
                            "Diarrhea Severity Rating": String(diarrheaSeverity) ])
                    }
                    
                    //Following if-statements use a method that updates the symptom severity document in Firebase Database
                    if stringtext.contains("Are you experiencing shortness of breath")
                    {
                        self.updateSymptomDataInFirebaseDatabase(chatText: cleanText, rating: "Cough Severity Rating")
                    }
                    
                    if stringtext.contains("Are you experiencing fatigue?")
                    {
                        self.updateSymptomDataInFirebaseDatabase(chatText: cleanText, rating: "Shortness of Breath Severity Rating")
                    }
                    
                    if stringtext.contains("Are you experiencing muscle or body aches?")
                    {
                        self.updateSymptomDataInFirebaseDatabase(chatText: cleanText, rating: "Fatigue Severity Rating")
                    }
                    
                    if stringtext.contains("Do you have a headache?")
                    {
                        self.updateSymptomDataInFirebaseDatabase(chatText: cleanText, rating: "Muscle or Body Ache Severity Rating")
                    }
                    
                    if stringtext.contains("Are you experiencing new loss of taste or smell?")
                    {
                        self.updateSymptomDataInFirebaseDatabase(chatText: cleanText, rating: "Headache Severity Rating")
                    }
                    
                    if stringtext.contains("Are you experiencing sore throat?")
                    {
                        self.updateSymptomDataInFirebaseDatabase(chatText: cleanText, rating: "Loss of Taste or Smell Severity Rating")
                    }
                    
                    if stringtext.contains("Are you experiencing congestion or runny nose?")
                    {
                        self.updateSymptomDataInFirebaseDatabase(chatText: cleanText, rating: "Sore Throat Severity Rating")
                    }
                    
                    if stringtext.contains("Are you experiencing nausea and/or are vomiting?")
                    {
                        self.updateSymptomDataInFirebaseDatabase(chatText: cleanText, rating: "Congestion Severity Rating")
                    }
                    
                    if stringtext.contains("Are you experiencing diarrhea?")
                    {
                        self.updateSymptomDataInFirebaseDatabase(chatText: cleanText, rating: "Nausea or Vomiting Severity Rating")
                    }
                    
                    if stringtext.contains("Your ratings have been recorded")
                    {
                        self.updateSymptomDataInFirebaseDatabase(chatText: cleanText, rating: "Diarrhea Severity Rating")
                    }
                    
                    //This is where I call method to create PDF Severity Report
                    if stringtext.contains("Your severity report has been sent")
                    {
                        self.retrieveAndEmailSeverityReport()
                    }
                }

            }

        
        }

    }
    
    //Function that's updating severity report document in Firebase Database
    func updateSymptomDataInFirebaseDatabase(chatText: String, rating: String)
    {
        var symptomSeverity = 0
        if chatText.contains("No") || chatText.contains("no") || chatText.contains("Nope") || chatText.contains("nope") || chatText.contains("Np") || chatText.contains("np") || chatText.contains("Nah") || chatText.contains("nah")
        {
            print("User does not have symptom")
        }
        else
        {
            for i in 1...10
            {
                if chatText.contains(String(i))
                {
                    print("User has symptom")
                    print("Severity Score: \(i)")
                    symptomSeverity = i
                }
            }
        }
            
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy"
        let cleanDate = dateFormatter.string(from: date)
            
        self.db.collection("Symptom Severity Tracker").document("\(self.email!) \(cleanDate)").updateData( [ rating: String(symptomSeverity) ])
    }
    
// MARK: - Retrieve/EmailReport

    //This function retrieves the severity report data from Firebase Database and send an email to the user containing their Severity Report
    func retrieveAndEmailSeverityReport()
    {
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy"
        let cleanDate = dateFormatter.string(from: date)
        
        let docRef = self.db.collection("Symptom Severity Tracker").document("\(self.email!) \(cleanDate)")
        
        //Retrieve Report (Need to sort next)
        docRef.getDocument { (document, error) in
            if let document = document, document.exists {
                let dataDescription = document.data().map(String.init(describing:)) ?? "nil"
                print("Document data: \(dataDescription)")
                
                let sortedReport = self.sortSeverityReport(report: dataDescription)
                
                // MARK: - Email Report
                self.db.collection("mail").document("\(self.email!) \(date)").setData( [
                    "to":self.email!,
                    "message": [
                        "subject": "Symptom Severity Report on \(cleanDate)",
                        "text": "\(sortedReport)"
                    ]
                ])
                
            } else {
                print("Document does not exist")
            }
        }
        
    }
    
    // MARK: - Sort Report
    //Sorts the Severity Report
    func sortSeverityReport(report: String) -> String
    {
        var sortedReport = "There was an error attaching your symptom severity report. Error Code: E-SORT1"
        
        var feverSeverity = 0
        var coughSeverity = 0
        var shortBreathSeverity = 0
        var fatigueSeverity = 0
        var muscleAcheSeverity = 0
        var headacheSeverity = 0
        var lossTasteSeverity = 0
        var soreThroatSeverity = 0
        var congestionSeverity = 0
        var nauseaSeverity = 0
        var diarrheaSeverity = 0
        
        //This is the initial sorting of the report.
        sortedReport = "Symptom \t\t| \tHas Symptom? Severity\n"
        
        //Each chunk below runs a loop to determine each symptoms specific score(0-10). When found, it saves the value to a variable and changes the report accordingly
        for a in 0...10
        {
            //I have it checking for the comma at the end of each score to ensure I'm catching double digit numbers. The bracket is incase the symptom is at the end of the string (string always ends with bracket)
            let stringValue = String(a)
            if report.contains("Fever/Chills Severity Rating\": \(stringValue),") || report.contains("Fever/Chills Severity Rating\": \(stringValue)]")
            {
                //Save Value
                feverSeverity = a
                
                if a == 0
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nFever/Chills \t\t\t No"
                }
                else
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nFever/Chills \t\t\t Yes, \(feverSeverity)"
                }
            }
        }
        
        for b in 0...10
        {
            let stringValue = String(b)
            if report.contains("Cough Severity Rating\": \(stringValue),") || report.contains("Cough Severity Rating\": \(stringValue)]")
            {
                //Save Value
                coughSeverity = b
                
                if b == 0
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nCough \t\t\t\t  No"
                }
                else
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nCough \t\t\t\t  Yes, \(coughSeverity)"
                }
            }
        }
        
        for c in 0...10
        {
            let stringValue = String(c)
            if report.contains("Shortness of Breath Severity Rating\": \(stringValue),") || report.contains("Shortness of Breath Severity Rating\": \(stringValue)]")
            {
                //Save Value
                shortBreathSeverity = c
                
                if c == 0
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nShortness of Breath \t   No"
                }
                else
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nShortness of Breath \t   Yes, \(shortBreathSeverity)"
                }
            }
        }
        
        for d in 0...10
        {
            let stringValue = String(d)
            if report.contains("Fatigue Severity Rating\": \(stringValue),") || report.contains("Fatigue Severity Rating\": \(stringValue)]")
            {
                //Save Value
                fatigueSeverity = d
                
                if d == 0
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nFatigue \t\t\t   No"
                }
                else
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nFatigue \t\t\t   Yes, \(fatigueSeverity)"
                }
            }
        }
        
        for e in 0...10
        {
            let stringValue = String(e)
            if report.contains("Muscle or Body Ache Severity Rating\": \(stringValue),") || report.contains("Muscle or Body Ache Severity Rating\": \(stringValue)]")
            {
                //Save Value
                muscleAcheSeverity = e
                
                if e == 0
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nMuscle/Body Aches \t No"
                }
                else
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nMuscle/Body Aches \t Yes, \(muscleAcheSeverity)"
                }
            }
        }
        
        for f in 0...10
        {
            let stringValue = String(f)
            if report.contains("Headache Severity Rating\": \(stringValue),") || report.contains("Headache Severity Rating\": \(stringValue)]")
            {
                //Save Value
                headacheSeverity = f
                
                if f == 0
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nHeadache \t\t       No"
                }
                else
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nHeadache \t\t       Yes, \(headacheSeverity)"
                }
            }
        }
        
        for g in 0...10
        {
            let stringValue = String(g)
            if report.contains("Loss of Taste or Smell Severity Rating\": \(stringValue),") || report.contains("Loss of Taste or Smell Severity Rating\": \(stringValue)]")
            {
                //Save Value
                lossTasteSeverity = g
                
                if g == 0
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nLoss of Taste/Smell \t    No"
                }
                else
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nLoss of Taste/Smell \t    Yes, \(lossTasteSeverity)"
                }
            }
        }
        
        for h in 0...10
        {
            let stringValue = String(h)
            if report.contains("Sore Throat Severity Rating\": \(stringValue),") || report.contains("Sore Throat Severity Rating\": \(stringValue)]")
            {
                //Save Value
                soreThroatSeverity = h
                
                if h == 0
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nSore Throat \t\t\tNo"
                }
                else
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nSore Throat \t\t\tYes, \(soreThroatSeverity)"
                }
            }
        }
        
        for i in 0...10
        {
            let stringValue = String(i)
            if report.contains("Congestion Severity Rating\": \(stringValue),") || report.contains("Congestion Severity Rating\": \(stringValue)]")
            {
                //Save Value
                congestionSeverity = i
                
                if i == 0
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nCongestion \t\t\tNo"
                }
                else
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nCongestion \t\t\tYes, \(congestionSeverity)"
                }
            }
        }
        
        for j in 0...10
        {
            let stringValue = String(j)
            if report.contains("Nausea or Vomiting Severity Rating\": \(stringValue),") || report.contains("Nausea or Vomiting Severity Rating\": \(stringValue)]")
            {
                //Save Value
                nauseaSeverity = j
                
                if j == 0
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nNausea/Vomiting \t   No"
                }
                else
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nNausea/Vomiting \t   Yes, \(nauseaSeverity)"
                }
            }
        }
        
        for k in 0...10
        {
            let stringValue = String(k)
            if report.contains("Diarrhea Severity Rating\": \(stringValue),") || report.contains("Diarrhea Severity Rating\": \(stringValue)]")
            {
                //Save Value
                diarrheaSeverity = k
                
                if k == 0
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nDiarrhea \t\t\t  No"
                }
                else
                {
                    //Edit Report
                    sortedReport = sortedReport + "\nDiarrhea \t\t\t  Yes, \(diarrheaSeverity)"
                }
            }
        }
        
        return sortedReport
    }
    
}




/*
 //THIS IS CODE TO VIEW VIDEO ON CLICK
@IBAction func videoOnePressed(_ sender: Any)
{
    guard let url = URL(string: "https://firebasestorage.googleapis.com/v0/b/animarena-14ef2.appspot.com/o/MHASea4Ep11.mp4?alt=media&token=40b968a9-dfb6-4db4-a1e2-b8fc255bf797")
    else
    {
        return
    }
    
    let player = AVPlayer(url: url)
    let controller = AVPlayerViewController()
    controller.player = player
    
    present(controller, animated: true)
    {
        player.play()
    }
}
    */
