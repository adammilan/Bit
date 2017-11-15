//
//  ForgotPasswordViewController.swift
//  Bit
//
//  Created by Hen Levy on 20/04/2017.
//  Copyright © 2017 Hen Levy. All rights reserved.
//

import UIKit
import FirebaseAuth

class ForgotPasswordViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var emailTextField: UITextField!
    
    // MARK: Actions
    
    @IBAction func send() {
        
        // validate email
        if let email = emailTextField.text,
            Validate.email(email: email) {
            
            // send rest password to user's email
            FIRAuth.auth()?.sendPasswordReset(withEmail: email, completion: { [weak self] (error) in
                if let strongError = error {
                    debugPrint(strongError.localizedDescription)
                } else if let strongSelf = self {
                    let _ = strongSelf.navigationController?.popViewController(animated: true)
                }
            })
        }
    }
    
    @IBAction func back() {
        let _ = navigationController?.popViewController(animated: true)
    }
    
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        send()
        return true
    }
}
