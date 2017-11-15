//
//  ViewController.swift
//  Bit
//
//  Created by Hen Levy on 20/04/2017.
//  Copyright © 2017 Hen Levy. All rights reserved.
//

import UIKit
import FirebaseAuth

class WelcomeViewController: FormViewController {
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    // MARK: Actions
    
    @IBAction func login() {
        
        dismissKeyboard()

        // validate email
        guard let email = emailTextField.text,
            Validate.email(email: email) else {
                showErrorMessage(title: "Email is invalid")
                return
        }
        
        // validate password
        guard let pass = passwordTextField.text,
            Validate.defaultText(text: pass) else {
                showErrorMessage(title: "Password is invalid")
                return
        }
        
        // sign in
        FIRAuth.auth()?.signIn(withEmail: email, password: pass, completion: {(user,error)
            in
            if let strongError = error {
                self.showErrorMessage(title: strongError.localizedDescription)
            } else {
                if User.shared.registrationToken != nil {
                    User.shared.saveRegistrationToken()
                }
                self.performSegue(withIdentifier: "SegueToFriends", sender: nil)
            }
        })
    }
    
    func showErrorMessage(title: String) {
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
    
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailTextField {
            passwordTextField.becomeFirstResponder()
        } else {
            login()
        }
        return true
    }
}

