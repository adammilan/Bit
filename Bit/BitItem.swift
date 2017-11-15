//
//  BitItem.swift
//  Bit
//
//  Created by Hen Levy on 24/04/2017.
//  Copyright © 2017 Hen Levy. All rights reserved.
//

import Foundation
import CoreLocation

class BitItem {
    var uid = ""
    var text = ""
    var pin = 0
    var coordinate: CLLocationCoordinate2D?
    var sent = false
    var dateSent: Date?
    
    init(uid: String, text: String, pin: Int, coordinate: CLLocationCoordinate2D?) {
        self.uid = uid
        self.text = text
        self.pin = pin
        self.coordinate = coordinate
    }
}

class LastBitItem: BitItem {
    var sentTo = ""
    var sentToUid = ""
}
