//
//  SplashViewController.swift
//  Bit
//
//  Created by Hen Levy on 20/04/2017.
//  Copyright © 2017 Hen Levy. All rights reserved.
//

import UIKit
import FirebaseAuth

class SplashViewController: UIViewController {
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // if user already logged in -> continue to Friends screen
        if FIRAuth.auth()?.currentUser != nil {
            performSegue(withIdentifier: "SegueFriends", sender: nil)
        } else {
            performSegue(withIdentifier: "SegueWelcome", sender: nil)
        }
    }
}
