//
//  ContactsViewController.swift
//  Bit
//
//  Created by Hen Levy on 23/04/2017.
//  Copyright © 2017 Hen Levy. All rights reserved.
//

import UIKit
import Contacts
import MessageUI
import PhoneNumberKit
import FirebaseAuth
import FirebaseDatabase

class ContactsViewController: PeopleViewController {
    @IBOutlet weak var contactsTableView: UITableView!
    var contacts: [CNContact] {
        return isSearching ? ContactsManager.shared.searchResultsContacts : ContactsManager.shared.contacts
    }
    var users = [String: String]()
    
    
    // MARK: View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ContactsManager.shared.delegate = self
        barCustomView?.friendsSearchBar.delegate = self
        loadPhones()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.setHidesBackButton(true, animated: false)
        barCustomView?.backButton.isHidden = false
        barCustomView?.titleLabel.text = "Contacts"
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        barCustomView?.backButton.isHidden = true
        searchBarCancelButtonClicked(barCustomView!.friendsSearchBar)
    }
    
    func loadPhones() {
        dbRef.child("phones").queryOrderedByKey().observe(.value, with: { [weak self] (snapshot) in
            if let usersDic = snapshot.value as? [String: String] {
                self?.users = usersDic
            }
        })
    }
    
    func contactIsSignedUp(contact: CNContact) -> (phone: String?, uid: String?) {
        
        let phoneNumberKit = PhoneNumberKit()
        var formattedPhoneNumber: String?
        var parsedPhoneNumber: PhoneNumber?
        
        for phoneNumber in contact.phoneNumbers {
            do {
                let phoneNumberString = phoneNumber.value.stringValue
                parsedPhoneNumber = nil
                
                parsedPhoneNumber = try phoneNumberKit.parse(phoneNumberString, withRegion: "IL", ignoreType: true)
            }
            catch {
                print("Phone number is invalid. Generic parser error")
                continue
            }
            
            if let validPhoneNumber = parsedPhoneNumber {
                formattedPhoneNumber = phoneNumberKit.format(validPhoneNumber, toType: .e164)
                
                if (formattedPhoneNumber != nil) && (users[formattedPhoneNumber!] != nil) {
                    return (formattedPhoneNumber!, users[formattedPhoneNumber!]!)
                } else if (formattedPhoneNumber != nil) {
                    return (formattedPhoneNumber!, nil)
                }
            }
        }
        
        return (nil, nil)
    }
    
    // MARK: Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let bitsViewController = segue.destination as! BitsViewController
        bitsViewController.friend = sender as! Friend
    }
}

// MARK: UISearchBarDelegate

extension ContactsViewController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if !searchText.isEmpty {
            ContactsManager.shared.findContactsWithName(name: searchText)
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
        contactsTableView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        contactsTableView.reloadData()
    }
}


// MARK: ContactsManagerDelegate

extension ContactsViewController: ContactsManagerDelegate {
    
    func finishLoadAllContacts() {
        contactsTableView.reloadData()
    }
    
    func finishSearchForContacts() {
        contactsTableView.reloadData()
    }
}


// MARK: TableView DataSource & Delegate

extension ContactsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contacts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ContactCellIdentifier", for: indexPath) as! ContactCell
        let contact = contacts[indexPath.row]
        cell.nameLabel.text = contact.fullName
        cell.contactImageView.image = contact.image
        cell.subtitleLabel.text = ""
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let contact = contacts[indexPath.row]
        let user = contactIsSignedUp(contact: contact)
        
        if let friendUid = user.uid {
            
            let myUID = User.shared.uid
            var path = "users/" + myUID + "/friends"
            
            // if contact isn't a friend yet
            dbRef.child(path).observeSingleEvent(of: .value, with: { [weak self] snapshot in

                if !snapshot.hasChild(friendUid) {
                    
                    // contact is signed up - add him as friend
                    path = "users/" + myUID + "/friends/" + friendUid
                    self?.dbRef.child(path).setValue(["name": contact.fullName])
                    
                    // your friend is adding you as a friend too
                    path = "users/" + friendUid + "/friends/" + myUID
                    self?.dbRef.child(path).setValue(["name": FIRAuth.auth()!.currentUser!.displayName!])
                }
            })
            
            let friend = Friend(uid: friendUid, name: contact.fullName, image: contact.image)
            performSegue(withIdentifier: "SegueToBits", sender: friend)
            
        } else if let contactPhone = user.phone {
            
            // contact isn't signed up -
            // send him an invite to install Bit app through SMS
            sendSMS(contact: contact, phone: contactPhone)
        }
    }
}


// MARK: Send SMS

extension ContactsViewController: MFMessageComposeViewControllerDelegate {
    
    func sendSMS(contact: CNContact, phone: String) {
        if (MFMessageComposeViewController.canSendText()) {
            let messageCompose = MFMessageComposeViewController()
            messageCompose.body = "Hey \(contact.fullName),\nYou're invited by \(FIRAuth.auth()!.currentUser!.displayName!) to join Bit app!\nhttp://google.com"
            messageCompose.recipients = [phone]
            messageCompose.messageComposeDelegate = self
            self.present(messageCompose, animated: true, completion: nil)
        }
    }
    
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        dismiss(animated: true, completion: nil)
    }
}
