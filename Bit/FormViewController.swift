//
//  FormViewController.swift
//  Bit
//
//  Created by Hen Levy on 20/04/2017.
//  Copyright © 2017 Hen Levy. All rights reserved.
//

import UIKit

class FormViewController: UIViewController, UITextFieldDelegate {
    var currentTextField: UITextField?
    
    @IBAction func dismissKeyboard() {
        if let current = currentTextField, current.isFirstResponder {
            current.resignFirstResponder()
        }
    }
    
    // MARK: UITextFieldDelegate
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        currentTextField = textField
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.layoutIfNeeded()
        currentTextField = nil
    }
}
