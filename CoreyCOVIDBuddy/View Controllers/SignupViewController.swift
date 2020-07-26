//
//  SignupViewController.swift
//  CoreyCOVIDBuddy
//
//  Copyright © 2020 Gregory Okhuereigbe. All rights reserved.
//

import UIKit
import FirebaseAuth
import Firebase
import FirebaseFirestore


class SignupViewController: UIViewController
{
    
    @IBOutlet weak var emailTextField: UITextField!
    
    @IBOutlet weak var usernameTextField: UITextField!
    
    @IBOutlet weak var passwordTextField: UITextField!
    
    @IBOutlet weak var confirmPasswordTextField: UITextField!
    
    @IBOutlet weak var createAccountButton: UIButton!
    
    @IBOutlet weak var errorLabel: UILabel!
    
    
    override func
        viewDidLoad() {
        super.viewDidLoad()
        //Any additional setup after loading the view
        setUpElements()
    }
    
    func setUpElements()
    {
        errorLabel.alpha = 0
        FormUtilities.styleTextField(emailTextField)
        FormUtilities.styleTextField(usernameTextField)
        FormUtilities.styleTextField(passwordTextField)
        FormUtilities.styleTextField(confirmPasswordTextField)
    }
    
    
    // Check the fields and validate the data is correct. If everything is correct, this method returns nothing. If not, it returns the error message with custom message.
    func validateFields() -> String?
    {
        // Check that all fields are filled in
        if emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) == "" || usernameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) == "" ||
            passwordTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) == "" ||
            confirmPasswordTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) == ""
        {
            return "Please fill in all fields"
        }
        
        // Check if password if secure
        let cleanedPassword = passwordTextField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if FormUtilities.isPasswordValid(cleanedPassword) == false
        {
            //Password is not secure enough
            return "Password must contain at least 8 characters, a special character and a number"
        }
        
        // Check passwords match
        if confirmPasswordTextField.text!.trimmingCharacters(in: .whitespacesAndNewlines) != cleanedPassword
        {
            return "Passwords do not match"
        }
        
        return nil
    }
    
    @IBAction func createAccountTapped(_ sender: Any)
    {
        // Validate the fields
        let error = validateFields()
        
        if error != nil
        {
            showError(error!)
        }
        else
        {
            // Create cleaned versions of the data
            let email = emailTextField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
            let username = usernameTextField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
            let password = confirmPasswordTextField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
            
            
            // Create the user
            Auth.auth().createUser(withEmail: email, password: password) { (result, err) in
                // Check for errors
                if err != nil
                {
                    // There was an error creating the user
                    self.showError("Error creating user")
                }
                else
                {
                    // User created successfully. Now store username (or other info)
                    let db = Firestore.firestore()
                    
                    db.collection("users").document(email).setData( ["email":email,"username":username, "uid":result!.user.uid]) { (error) in
                        
                        if error != nil
                        {
                            // Show error message
                            self.showError("Error saving user data")
                        }
                    }
                    
                    
                    // Transition to home screen
                    self.transitionToHome()
                }
            }
        }
    }
    
    func showError(_ message:String)
    {
        errorLabel.text = message
        errorLabel.alpha = 1
    }
    
    func transitionToHome()
    {
        let homeViewController = storyboard?.instantiateViewController(identifier: Constants.Storyboard.homeViewController)
        
        view.window?.rootViewController = homeViewController
        view.window?.makeKeyAndVisible()
    }
    
}
