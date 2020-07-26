//
//  FormUtilities.swift
//  CoreyCOVIDBuddy
//
//  Copyright © 2020 Gregory Okhuereigbe. All rights reserved.
//

import Foundation

import UIKit

class FormUtilities
{
    static func styleTextField(_ textfield:UITextField)
    {
        // Make bottom line
        let bottomLine = CALayer()
        
        bottomLine.frame = CGRect(x: 0, y: textfield.frame.height - 2, width: textfield.frame.width, height:2)
        
        bottomLine.backgroundColor = UIColor.init(red: 0/255, green: 149/255, blue: 255/255, alpha: 1).cgColor
        
        // Remove border on text field
        textfield.borderStyle = .none
        
        //Add the line to the text field
        textfield.layer.addSublayer(bottomLine)
    }
    
    static func isPasswordValid(_ password : String) -> Bool
    {
        let passwordTest = NSPredicate(format: "SELF MATCHES %@", "^(?=.*[a-z])(?=.*[$@#!%*?&])[A-Za-z\\d$@$#!%*?&]{8,}")
        
        return passwordTest.evaluate(with: password)
    }
}
