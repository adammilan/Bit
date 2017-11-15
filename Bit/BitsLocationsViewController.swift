//
//  BitsLocationsViewController.swift
//  Bit
//
//  Created by Hen Levy on 25/04/2017.
//  Copyright © 2017 Hen Levy. All rights reserved.
//

import UIKit
import GoogleMaps
import FirebaseDatabase

class BitsLocationsViewController: UIViewController {
    var friend: Friend!
    var bitLocations = [LastBitItem]()
    @IBOutlet weak var mapView: GMSMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadLocations()
    }
    
    func loadLocations() {
        bitLocations.removeAll()
        
        if friend == nil {
            navigationController?.navigationBar.height = 44.0
            navigationController?.navigationBar.setupGradient()
            self.title = "Locations"
            
            let path = "users/" + User.shared.uid + "/friends"
            FIRDatabase.database().reference().child(path).observeSingleEvent(of: .value, with: {[weak self] (snapshot) in
                guard let friendsDic = snapshot.value as? [String: AnyObject]  else {
                    return
                }
                let friendsUIDs = Array(friendsDic.keys)
                for friendUid in friendsUIDs {

                    guard let friend = friendsDic[friendUid] as? [String: AnyObject],
                        let bitsDic = friend["bits"] as? [String: AnyObject],
                        let friendName = friend["name"] as? String else {
                            continue
                    }
                    
                    self?.observeFriend(bitsDic: bitsDic, friendUid: friendUid, friendName: friendName)
                    self?.loadBitsLocations()
                }
            })
        } else {
            let path = "users/" + User.shared.uid + "/friends/" + friend.uid + "/bits"
            FIRDatabase.database().reference().child(path).observeSingleEvent(of: .value, with: { [weak self] (snapshot) in
                
                guard let bitsDic = snapshot.value as? [String: AnyObject],
                    let strongSelf = self else {
                        return
                }
                
                strongSelf.observeFriend(bitsDic: bitsDic, friendUid: strongSelf.friend.uid, friendName: strongSelf.friend.name)
                strongSelf.loadBitsLocations()
            })
        }
    }
    
    func observeFriend(bitsDic: [String: AnyObject], friendUid: String, friendName: String) {
            let bitsArray = Array(bitsDic.values)
            
            for bit in bitsArray {
                let bitText = (bit["text"] as? String) ?? ""
                let bitUid = (bit["uid"] as? String) ?? ""
                
                if let coordinateDic = bit["location"] as? [String: Double] {
                    let coordinate = CLLocationCoordinate2D(latitude: coordinateDic["lat"]!, longitude: coordinateDic["long"]!)
                    
                    let bitLocation = LastBitItem(uid: bitUid, text: bitText, pin: 0, coordinate: coordinate)
                    bitLocation.sentTo = friendName
                    bitLocation.sentToUid = friendUid
                    
                    bitLocations.append(bitLocation)
                }
            }
    }
    
    func loadBitsLocations() {
        guard !bitLocations.isEmpty else {
            return
        }
        let camCoordinate = bitLocations[0].coordinate!
        
        let camera = GMSCameraPosition.camera(withLatitude: camCoordinate.latitude,
                                              longitude: camCoordinate.longitude,
                                              zoom: 12)
        mapView.camera = camera
        
        for (index, location) in bitLocations.enumerated() {
            let marker = GMSMarker()
            marker.position = location.coordinate!
            marker.snippet = location.sentTo + ": " + location.text
            marker.appearAnimation = .pop
            marker.isTappable = true
            marker.zIndex = Int32(index)
            DispatchQueue.global(qos: .default).async {
                User.shared.getProfilePic(userId: location.sentToUid, completion: { friendPhoto in
                    DispatchQueue.main.async {
                        let scaledImage = friendPhoto?.scaleImage(toSize: CGSize(width: 20, height: 20))
                        let iconView = UIImageView(image: scaledImage)
                        iconView.layer.masksToBounds = true
                        iconView.layer.cornerRadius = iconView.frame.size.height/2
                        marker.iconView = iconView
                    }
                })
            }
            marker.map = mapView
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if friend != nil {
            UIApplication.shared.isStatusBarHidden = true
        }
        loadLocations()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if friend != nil {
            UIApplication.shared.isStatusBarHidden = false
        }
    }
    
    @IBAction func close() {
        dismiss(animated: true, completion: nil)
    }
}
