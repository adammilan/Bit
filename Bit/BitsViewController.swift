//
//  BitsViewController.swift
//  Bit
//
//  Created by Hen Levy on 23/04/2017.
//  Copyright © 2017 Hen Levy. All rights reserved.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase
import GooglePlaces
import Alamofire

let dateFormat = "yyyy-MM-dd HH:mm"

class BitsViewController: UIViewController {
    @IBOutlet weak var bitsTableView: UITableView!
    @IBOutlet weak var suggestionsTableView: UITableView!
    @IBOutlet weak var friendNameLabel: UILabel!
    @IBOutlet weak var friendImageView: UIImageView!
    @IBOutlet weak var overlayView: UIView!
    @IBOutlet weak var addNewBitView: UIView!
    @IBOutlet weak var bitTextField: UITextField!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    var dbRef = FIRDatabase.database().reference()
    var friend: Friend!
    var bits = [BitItem]()
    var suggestions = [BitItem]()
    var selectedLocationBit: BitItem!
    let api = API()
    
    
    // MARK: View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bitsTableView.tableFooterView = UIView(frame: CGRect.zero)
        friendNameLabel.text = friend.name
        friendImageView.image = friend.image
        
        getFriendImage()
        observeFriendBits()
        setupSuggestedBits()
    }
    
    func getFriendImage() {
        if let friendImage = FriendsManager.shared.friendsImagesCache.object(forKey: NSString(string: friend.uid)) {
            friendImageView.image = friendImage
        } else {
            FriendsManager.shared.downloadFriendImage(friendUid: friend.uid) { [weak self] image in
                if let strongImage = image {
                    self?.friendImageView.image = strongImage
                }
            }
        }
    }
    
    func observeFriendBits() {

        let path = "users/" + User.shared.uid + "/friends/" + friend.uid + "/bits"
        dbRef.child(path).observe(.value, with: { [weak self] snapshot in
            if let bitsDic = snapshot.value as? [String: AnyObject] {
                
                guard let strongSelf = self else {
                    return
                }
                let bitsArray = Array(bitsDic.values)
                
                let df = DateFormatter()
                df.dateFormat = dateFormat
                
                for bit in bitsArray {
                    let uid = (bit["uid"] as? String) ?? ""
                    let text = (bit["text"] as? String) ?? ""
                    let pin = (bit["pin"] as? Int) ?? 0
                    let sent = (bit["sent"] as? Bool) ?? false
                    
                    var coordinate: CLLocationCoordinate2D?
                    if let location = bit["location"] as? [String: Double] {
                        coordinate = CLLocationCoordinate2D(latitude: location["lat"]!, longitude: location["long"]!)
                    }
                    var dateSent: Date?
                    if let dateStr = bit["dateSent"] as? String {
                        dateSent = df.date(from: dateStr)
                    }
                    
                    let bitItem = BitItem(uid: uid, text: text, pin: pin, coordinate: coordinate)
                    if !strongSelf.bits.contains { $0.text == text} {
                        strongSelf.bits.append(bitItem)
                    }
                    bitItem.sent = sent
                    bitItem.dateSent = dateSent
                }
                
                strongSelf.sortBits()
            }
        })
    }
    
    func sortBits() {
        bits = bits.sorted {$0.pin > $1.pin}
        bitsTableView.reloadData()
    }
    
    func setupSuggestedBits() {
        SuggestedBits.for(userUID: User.shared.uid, friendUID: friend.uid) { [weak self] (suggestedBitsTexts) in
            
            for bitText in suggestedBitsTexts {
                self?.suggestions.append(BitItem(uid: "", text: bitText, pin: 0, coordinate: nil))
            }
            self?.suggestionsTableView.reloadData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isStatusBarHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isStatusBarHidden = false
    }
    
    // MARK: Actions
    
    @IBAction func close() {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func addBit() {
        overlayView.isHidden = false
        view.addSubview(addNewBitView)
        addNewBitView.translatesAutoresizingMaskIntoConstraints = false
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-20-[newBitView]-20-|", options: .alignAllLeft, metrics: nil, views: ["newBitView": addNewBitView]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-180-[newBitView]", options: .alignAllLeft, metrics: nil, views: ["newBitView": addNewBitView]))
        
        bitTextField.becomeFirstResponder()
    }
    
    func pinBit(sender: UIButton) {
        
        if let cell = sender.superview?.superview as? BitCell,
            let indexPath = bitsTableView.indexPath(for: cell) {
            
            let bit = bits[indexPath.row]
            bit.pin = bit.pin == 0 ? 1 : 0
            var bitDic = ["uid": bit.uid,
                          "text": bit.text,
                          "pin": bit.pin,
                          "sent": bit.sent] as [String : Any]
            
            if let coordinate = bit.coordinate {
                bitDic["location"] = ["lat": coordinate.latitude,
                                      "long":coordinate.longitude]
            }
            
            let df = DateFormatter()
            df.dateFormat = dateFormat
            if let date = bit.dateSent {
                bitDic["dateSent"] = df.string(from: date)
            }
            
            let path = "users/" + User.shared.uid + "/friends/" + friend.uid + "/bits/" + bit.uid
            FIRDatabase.database().reference().child(path).setValue(bitDic)
            sortBits()
        }
    }
    
    func addBitLocation(sender: UIButton) {
        
        guard let cell = sender.superview?.superview as? BitCell,
            let indexPath = bitsTableView.indexPath(for: cell) else {
                return
        }
        selectedLocationBit = bits[indexPath.row]
        
        let autocompleteController = GMSAutocompleteViewController()
        autocompleteController.delegate = self
        
        // Set a filter to return only addresses.
        let filter = GMSAutocompleteFilter()
        filter.type = .address
        autocompleteController.autocompleteFilter = filter
        
        overlayView.isHidden = false
        
        addChildViewController(autocompleteController)
        view.addSubview(autocompleteController.view)
        
        autocompleteController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-20-[view]-20-|", options: .alignAllLeft, metrics: nil, views: ["view":autocompleteController.view]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-120-[view]-120-|", options: .alignAllLeft, metrics: nil, views: ["view":autocompleteController.view]))
        
        autocompleteController.didMove(toParentViewController: self)
    }
    
    // MARK: Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let bitsLocationsViewController = segue.destination as? BitsLocationsViewController {
            bitsLocationsViewController.friend = friend
        }
    }
}

extension BitsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableView == bitsTableView ? bits.count : suggestions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BitCellIdentifier", for: indexPath) as! BitCell
        
        let bit = tableView == bitsTableView ? bits[indexPath.row] : suggestions[indexPath.row]
        cell.bitTextLabel.text = bit.text
        
        let pinImageNamed = bit.pin == 0 ? "favorite_border" : "favorite"
        cell.pinButton.setImage(UIImage(named: pinImageNamed), for: .normal)
        
        let locationImageNamed = bit.coordinate == nil ? "location_off" : "location_on"
        cell.bitLocationButton.setImage(UIImage(named: locationImageNamed), for: .normal)
        
        if !cell.pinButton.allTargets.isEmpty {
            cell.pinButton.removeTarget(self, action: #selector(pinBit(sender:)), for: .touchUpInside)
        }
        cell.pinButton.addTarget(self, action: #selector(pinBit(sender:)), for: .touchUpInside)
        
        if !cell.bitLocationButton.allTargets.isEmpty {
            cell.bitLocationButton.removeTarget(self, action: #selector(addBitLocation(sender:)), for: .touchUpInside)
        }
        cell.bitLocationButton.addTarget(self, action: #selector(addBitLocation(sender:)), for: .touchUpInside)
        
        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return tableView == bitsTableView
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        
        let bit = tableView == bitsTableView ? bits[indexPath.row] : suggestions[indexPath.row]
        let path = "users/" + User.shared.uid + "/friends/" + friend.uid + "/bits/" + bit.uid
        dbRef.child(path).removeValue()
        bits.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let bit = tableView == bitsTableView ? bits[indexPath.row] : suggestions[indexPath.row]
        
//        requestSendBit(bit: bit)
        
        api.requestSendBit(senderName: User.shared.name, bitText: bit.text, friendUID: friend.uid, spinner: self.spinner)
        
        let df = DateFormatter()
        df.dateFormat = dateFormat
        let dateSentStr = df.string(from: Date())
        
        // update database that the bit was sent
        var path = "users/" + friend.uid + "/friends/" + User.shared.uid + "/lastBitSent"
        dbRef.child(path).setValue(["date": dateSentStr,
                                    "text": bit.text])
        
        // update specific bit with date
        var bitDic = ["uid": bit.uid,
                      "text": bit.text,
                      "pin": bit.pin,
                      "sent": true,
                      "dateSent": dateSentStr] as [String : Any]
        
        if let coordinate = bit.coordinate {
            bitDic["location"] = ["lat": coordinate.latitude,
                                  "long":coordinate.longitude]
        }
        // if the bit is in suggestions - save it as a new bit in bits
        if tableView == suggestionsTableView {
            path = "users/" + User.shared.uid + "/friends/" + friend.uid + "/bits"
            let uid = dbRef.child(path).childByAutoId().key
            bitDic["uid"] = uid
            path = path + "/" + uid
        } else {
            path = "users/" + User.shared.uid + "/friends/" + friend.uid + "/bits/" + bit.uid
        }
        dbRef.child(path).setValue(bitDic)
        
        // show alert that says that the bit was sent
        let alertController = UIAlertController(title: "Bit was sent!", message: bit.text, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
        

    }
    
//    func requestSendBit(bit: BitItem) {
//        
//        FIRDatabase.database().reference().child("users/\(friend.uid)").observeSingleEvent(of: .value, with: { [weak self] (snapshot) in
//            
//            guard let friendDic = snapshot.value as? [String: AnyObject],
//            let token = friendDic["registrationToken"] as? String else {
//                self?.spinner.stopAnimating()
//                return
//            }
//            
//            let params: Parameters = ["notification": ["title": User.shared.name, "body": bit.text],
//                                      "to": token]
//            
//            Alamofire.request("https://fcm.googleapis.com/fcm/send",
//                              method: HTTPMethod.post,
//                              parameters: params, encoding: JSONEncoding.default,
//                              headers: ["Authorization": "key=\(serverKey)"]).responseJSON(completionHandler: { (response) in
//                                
//                                if let json = response.result.value as? Dictionary<String, Any> {
//                                    debugPrint(json)
//                                }
//                              })
//        })
//    }
}

extension BitsViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        bitTextField.resignFirstResponder()
        spinner.startAnimating()
        DispatchQueue.main.async { [weak self] in
            self?.saveNewBit()
        }
        return true
    }
    
    @IBAction func saveNewBit() {
        guard let bitText = bitTextField.text else {
            spinner.stopAnimating()
            return
        }
        
        saveNewBitWithText(bitText)
        
        spinner.stopAnimating()
        cancel()
    }
    
    func saveNewBitWithText(_ bitText: String) {
        var path = "users/" + User.shared.uid + "/friends/" + friend.uid + "/bits"
        let uid = dbRef.child(path).childByAutoId().key
        
        let bitDic = ["uid": uid,
                      "text": bitText,
                      "pin": 0] as [String : Any]
        path = path + "/" + uid
        dbRef.child(path).setValue(bitDic)
    }
    
    @IBAction func cancel() {
        bitTextField.resignFirstResponder()
        overlayView.isHidden = true
        addNewBitView.removeFromSuperview()
    }
}


extension BitsViewController: GMSAutocompleteViewControllerDelegate {
    
    // Handle the user's selection.
    func viewController(_ viewController: GMSAutocompleteViewController, didAutocompleteWith place: GMSPlace) {
        
        let path = "users/" + User.shared.uid + "/friends/" + friend.uid + "/bits/" + selectedLocationBit.uid + "/location"
        dbRef.child(path).setValue(["lat": place.coordinate.latitude,
                                    "long": place.coordinate.longitude])
        selectedLocationBit.coordinate = place.coordinate
        bitsTableView.reloadData()
        closePopup(viewController)
    }
    
    func closePopup(_ viewController: GMSAutocompleteViewController) {
        viewController.willMove(toParentViewController: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParentViewController()
        overlayView.isHidden = true
    }
    
    func viewController(_ viewController: GMSAutocompleteViewController, didFailAutocompleteWithError error: Error) {
        // TODO: handle the error.
        print("Error: ", error.localizedDescription)
    }
    
    func wasCancelled(_ viewController: GMSAutocompleteViewController) {
        closePopup(viewController)
    }
    
    // Show the network activity indicator.
    func didRequestAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }
    
    // Hide the network activity indicator.
    func didUpdateAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
    
}
