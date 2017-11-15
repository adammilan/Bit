//
//  PeopleViewController.swift
//  Bit
//
//  Created by Hen Levy on 23/04/2017.
//  Copyright © 2017 Hen Levy. All rights reserved.
//

import UIKit
import FirebaseDatabase

class PeopleViewController: UIViewController {
    var dbRef = FIRDatabase.database().reference()
    var barCustomView: BarCustomView?
    var isSearching = false
}
