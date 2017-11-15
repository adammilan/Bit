//
//  SignUpViewController.swift
//  Bit
//
//  Created by Hen Levy on 20/04/2017.
//  Copyright © 2017 Hen Levy. All rights reserved.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase
import PhoneNumberKit

class SignUpViewController: FormViewController {
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var phoneTextField: PhoneNumberTextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var rePasswordTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        phoneTextField.defaultRegion = "IL"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nameTextField.becomeFirstResponder()
    }
    
    // MARK: Actions
    
    @IBAction func signUp() {
        
        dismissKeyboard()
        
        // validate email + password
        guard let email = emailTextField.text,
            let pass = passwordTextField.text,
            let rePass = rePasswordTextField.text,
            let phone = phoneTextField.text,
            let validPhone = Validate.phone(phone: phone),
            Validate.email(email: email),
            Validate.defaultText(text: pass),
            
            pass == rePass else {
                return
        }
        
        // sign up
        FIRAuth.auth()?.createUser(withEmail: email, password: pass, completion: { [weak self] (user, error) in
            if let strongError = error {
                debugPrint(strongError.localizedDescription)
            } else if let strongSelf = self {
                
                let ref = FIRDatabase.database().reference()
                
                ref.child("users").child(user!.uid).setValue(
                    ["name": strongSelf.nameTextField.text!,
                     "phone": validPhone,
                     "email": user!.email])
                
                ref.child("phones").child(validPhone).setValue(user!.uid)
                
                if let _ = User.shared.registrationToken {
                    User.shared.saveRegistrationToken()
                }
                
                // update user display name
                let changeRequest = FIRAuth.auth()?.currentUser?.profileChangeRequest()
                changeRequest?.displayName = strongSelf.nameTextField.text
                changeRequest?.commitChanges() { (error) in
                    if let strongError = error {
                        debugPrint(strongError.localizedDescription)
                    } else {
                        strongSelf.performSegue(withIdentifier: "SignUpSegueToFriends", sender: nil)
                    }
                }
            }
        })
    }
    
    @IBAction func back() {
        let _ = navigationController?.popViewController(animated: true)
    }
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == nameTextField {
            phoneTextField.becomeFirstResponder()
        } else if textField == phoneTextField {
            emailTextField.becomeFirstResponder()
        } else if textField == emailTextField {
            passwordTextField.becomeFirstResponder()
        } else if textField == passwordTextField {
            rePasswordTextField.becomeFirstResponder()
        } else {
            signUp()
        }
        return true
    }
}
