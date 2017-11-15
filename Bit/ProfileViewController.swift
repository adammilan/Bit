//
//  ProfileViewController.swift
//  Bit
//
//  Created by Hen Levy on 20/04/2017.
//  Copyright © 2017 Hen Levy. All rights reserved.
//

import UIKit
import FirebaseAuth
import FirebaseStorage
import FirebaseDatabase
import TOCropViewController

class ProfileViewController: UIViewController {
    @IBOutlet weak var changeProfilePicButton: UIButton!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var bitsCountLabel: UILabel!
    @IBOutlet weak var friendsCountLabel: UILabel!
    @IBOutlet weak var lastBitsTableView: UITableView!
    
    let storageRef = FIRStorage.storage().reference()
    let dbRef = FIRDatabase.database().reference()
    var lastBitsSent = [LastBitItem]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.height = 44.0
        navigationController?.navigationBar.setupGradient()
        self.title = "Profile"
        lastBitsTableView.tableFooterView = UIView(frame: CGRect.zero)
        
        nameLabel.text = User.shared.name
        emailLabel.text = User.shared.email
        
        User.shared.getProfilePic(userId: User.shared.uid) { [weak self] userPhoto in
            self?.changeProfilePicButton.setImage(userPhoto, for: .normal)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        observeFriends()
    }
    
    @IBAction func logout() {
        do {
            try FIRAuth.auth()?.signOut()
            User.shared.clearUserCachedInfo()
            tabBarController?.dismiss(animated: true, completion: nil)
        }
        catch {
            debugPrint("Something went wrong when tried to sign out")
        }
    }
    
    @IBAction func changeProfilePicture() {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            actionSheet.addAction(UIAlertAction(title: "Take Photo", style: .default, handler: { alertAction in
                self.presentImagePicker(sourceType: .camera)
            }))
        }
        
        if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) {
            actionSheet.addAction(UIAlertAction(title: "Choose Photo", style: .default, handler: { alertAction in
                self.presentImagePicker(sourceType: .savedPhotosAlbum)
            }))
        }
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(actionSheet, animated: true, completion: nil)
    }
    
    func presentImagePicker(sourceType: UIImagePickerControllerSourceType) {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = sourceType
        imagePicker.allowsEditing = false
        present(imagePicker, animated: true, completion: nil)
    }
    
    func observeFriends() {
        
        let path = "users/" + User.shared.uid + "/friends"
        dbRef.child(path).observeSingleEvent(of: .value, with: { [weak self] (snapshot) in
            guard let friendsDic = snapshot.value as? [String: AnyObject] else {
                return
            }
            self?.friendsCountLabel.text = "\(friendsDic.count)"
            
            let df = DateFormatter()
            df.dateFormat = dateFormat
            
            var bitsISentCount = 0
            let friends = Array(friendsDic.values)
            self?.lastBitsSent.removeAll()
            for friend in friends {
                if let bitsDic = friend["bits"] as? [String: AnyObject] {
                    let bits = Array(bitsDic.values)
                    for bit in bits {
                        if let bitDic = bit as? [String: AnyObject],
                            let sent = bitDic["sent"] as? Bool,
                            sent == true {
                            bitsISentCount += 1
                            
                            let text = (bitDic["text"] as? String) ?? ""
                            let bitItem = LastBitItem(uid: "", text: text, pin: 0, coordinate: nil)
                            if let dateStr = bitDic["dateSent"] as? String {
                                bitItem.dateSent = df.date(from: dateStr)
                            }
                            bitItem.sent = true
                            bitItem.sentTo = (friend["name"] as? String) ?? ""
                            self?.lastBitsSent.append(bitItem)
                        }
                    }
                }
            }
            self?.bitsCountLabel.text = "\(bitsISentCount)"
            self?.lastBitsTableView.reloadData()
        })
    }
}


extension ProfileViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        guard let image  = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            dismiss(animated: true, completion: nil)
            return
        }
        let cropViewController = TOCropViewController(croppingStyle: .default, image: image)
        cropViewController.delegate = self
        cropViewController.aspectRatioPreset = .presetSquare
        cropViewController.aspectRatioLockEnabled = true
        cropViewController.resetAspectRatioEnabled = false
        picker.pushViewController(cropViewController, animated: true)
    }
}

extension ProfileViewController: TOCropViewControllerDelegate {
    
    @objc(cropViewController:didCropToImage:withRect:angle:) func cropViewController(_ cropViewController: TOCropViewController, didCropToImage image: UIImage, rect cropRect: CGRect, angle: Int) {
        changeProfilePicButton.setImage(image, for: .normal)
        dismiss(animated: true, completion: nil)
        
        User.shared.setProfilePic(image)
    }
    
    func cropViewController(_ cropViewController: TOCropViewController, didFinishCancelled cancelled: Bool) {
        dismiss(animated: true, completion: nil)
    }
}

extension ProfileViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return lastBitsSent.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LastBitCellIdentifier", for: indexPath) as! LastBitCell
        let lastBitSent = lastBitsSent[indexPath.row]
        cell.lastBitLabel.text = lastBitSent.text
        
        if let dateSent = lastBitSent.dateSent {
            let df = DateFormatter()
            df.dateFormat = dateFormat
            let dateStr = df.string(from: dateSent)
            let sentTo = lastBitSent.sentTo
            cell.detailsLabel.text = "Sent to \(sentTo) at \(dateStr)"
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return lastBitsSent.count > 0 ? "Last Bits I Sent:" : ""
    }
}

