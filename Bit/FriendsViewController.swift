//
//  FriendsViewController.swift
//  Bit
//
//  Created by Hen Levy on 20/04/2017.
//  Copyright © 2017 Hen Levy. All rights reserved.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase
import FirebaseStorage

class FriendsViewController: PeopleViewController {
    @IBOutlet weak var friendsTableView: UITableView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    var allFriends = [Friend]()
    var searchResultsFriends = [Friend]()
    var friends: [Friend] {
        return isSearching ? searchResultsFriends : allFriends
    }
    
    // MARK: View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(receiveBitNotification(notification:)), name: NSNotification.Name(rawValue: "receiveBitNotification"), object: nil)
        
        barCustomView = BarCustomView(target: self)
        navigationController?.navigationBar.addSubview(barCustomView!)
        friendsTableView.tableFooterView = UIView(frame: CGRect.zero)
        observeFriends()
        
        // search for bits locations in area
        Radar.shared.start()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        barCustomView?.addFriendButton.isHidden = true
        searchBarCancelButtonClicked(barCustomView!.friendsSearchBar)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        barCustomView?.addFriendButton.isHidden = false
        barCustomView?.titleLabel.text = "Friends"
        barCustomView?.friendsSearchBar.delegate = self
        observeFriendsSingleEvent()
    }
    
    func observeFriendsSingleEvent() {
        let path = "users/" + User.shared.uid + "/friends"
        dbRef.child(path).observeSingleEvent(of: .value, with: { [weak self] (snapshot) in
            self?.extractAndUpdate(snapshot: snapshot)
        })
    }
    
    func observeFriends() {
        let path = "users/" + User.shared.uid + "/friends"
        dbRef.child(path).observe(.value, with: { [weak self] snapshot in
            self?.extractAndUpdate(snapshot: snapshot)
        })
        
    }
    
    func extractAndUpdate(snapshot: FIRDataSnapshot) {
        guard let friendsDic = snapshot.value as? [String: AnyObject]  else {
            spinner.stopAnimating()
            return
        }
        dbRef.child("users").observe(.value, with: { [weak self] snapshot in
            
            guard let strongSelf = self,
                let usersDic = snapshot.value as? [String: AnyObject] else {
                    self?.spinner.stopAnimating()
                    return
            }
            
            let friendsUIDs = Array(friendsDic.keys)
            
            for friendUid in friendsUIDs {
                if let user = usersDic[friendUid],
                    !strongSelf.allFriends.contains{$0.uid == friendUid} {
                    let name = (user["name"] as? String) ?? ""
                    let friend = Friend(uid: friendUid, name: name, image: nil)
                    strongSelf.allFriends.append(friend)
                }
            }
            
            for fKey in Array(friendsDic.keys) {
                let fDic = friendsDic[fKey] as! [String: AnyObject]
                if let lastBitSent = fDic["lastBitSent"] as? [String: AnyObject] {
                    for f in strongSelf.allFriends {
                        if f.uid == fKey {
                            f.lastBitText = lastBitSent["text"] as? String
                            f.lastBitSentDate = lastBitSent["date"] as? String
                        }
                    }
                }
            }
            strongSelf.sortFriends()
            strongSelf.spinner.stopAnimating()
        })
    }
    
    func sortFriends() {
        allFriends = allFriends.sorted(by: { (friendA, friendB) -> Bool in
            if let dateA = friendA.lastBitDate, let dateB = friendB.lastBitDate {
                return dateA > dateB
            }
            return false
        })
        friendsTableView.reloadData()
    }
    
    // MARK: Actions
    
    func addFriend() {
        performSegue(withIdentifier: "SegueToContacts", sender: nil)
    }
    
    // MARK: Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let contactsViewController = segue.destination as? ContactsViewController {
            contactsViewController.barCustomView = barCustomView
        } else if let bitsViewController = segue.destination as? BitsViewController {
            let indexPath = friendsTableView.indexPathForSelectedRow!
            bitsViewController.friend = friends[indexPath.row]
        }
    }
    
    // MARK: Notifications
    
    func receiveBitNotification(notification: Notification) {
        
        let aps = notification.userInfo as! [String: Any]
        if let alert = aps["alert"] as? [String: Any],
            let title = alert["title"] as? String,
            let body = alert["body"] as? String {
            
            let popup = UIAlertController(title: title, message: body, preferredStyle: .alert)
            popup.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            present(popup, animated: true, completion: { [weak self] in
                self?.observeFriends()
            })
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension FriendsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friends.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ContactCellIdentifier", for: indexPath) as! ContactCell
        let friend = friends[indexPath.row]
        cell.contactImageView.image = friend.image
        cell.nameLabel.text = friend.lastBitText
        
        if let lastDateStr = friend.lastBitSentDate {
            cell.subtitleLabel.text = lastDateStr + "  " + friend.name
        } else {
            cell.subtitleLabel.text = friend.name
        }
        
        if let friendImage = FriendsManager.shared.friendsImagesCache.object(forKey: NSString(string: friend.uid)) {
            cell.contactImageView.image = friendImage
        } else {
            DispatchQueue.global(qos: .default).async {
                FriendsManager.shared.downloadFriendImage(friendUid: friend.uid) { image in
                    if let strongImage = image {
                        DispatchQueue.main.async {
                            cell.contactImageView.image = strongImage
                        }
                    }
                }
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension FriendsViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if !searchText.isEmpty {
            findFriendsWithName(name: searchText)
        }
    }
    
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        searchBar.showsCancelButton = true
        isSearching = true
        return true
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.showsCancelButton = false
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        isSearching = false
        friendsTableView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        friendsTableView.reloadData()
    }
    
    func findFriendsWithName(name: String) {
        
        searchResultsFriends = allFriends.filter({ (friend) -> Bool in
            
            if friend.name.contains(name) {
                return true
            }
            return false
        })
        friendsTableView.reloadData()
    }
}
