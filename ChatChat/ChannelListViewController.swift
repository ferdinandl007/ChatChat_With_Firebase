

//  ChatChat
//
//  Created by Ferdinand Lösch on 23/11/2018.
//  Copyright © 2018 Razeware LLC. All rights reserved.
//

import UIKit
import Firebase


enum Section: Int {
    case createNewChannelSection = 0
    case currentChannelsSection
}



class ChannelListViewController: UITableViewController {
    // make properties 
    var senderDisplayName: String? // 1 Add a simple property to store the sender’s name.
    var newChannelTextField: UITextField? // 2 Add a text field, which you’ll use later for adding new Channels.
    private var channels: [Channel] = [] // 3 Create an empty array of Channel objects to store your channels. This is a simple model class provided in the starter project that simply contains a name and an ID.

    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "RW"
        observeChannels()
    }
    deinit {
        if let refHandle = channelRefHandle {
            channelRef.removeObserver(withHandle: refHandle)
        }
    }
    
    
    
    
    // MARK: UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2 // 1 Set the number of sections. Remember, the first section will include a form for adding new channels, and the second section will show a list of channels.
    }
    
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { // 2 Set the number of rows for each section. This is always 1 for the first section, and the number of channels for the second section.

        if let currentSection: Section = Section(rawValue: section) {
            switch currentSection {
            case .createNewChannelSection:
                return 1
            case .currentChannelsSection:
                return channels.count
            }
        } else {
            return 0
        }
    }
    
    // § Define what goes in each cell. For the first section, you store the text field from the cell in your newChannelTextField property. For the second section, you just set the cell’s text label as your channel name
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = (indexPath as NSIndexPath).section == Section.createNewChannelSection.rawValue ? "NewChannel" : "ExistingChannel"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        
        if (indexPath as NSIndexPath).section == Section.createNewChannelSection.rawValue {
            if let createNewChannelCell = cell as? CreateChannelCell {
                newChannelTextField = createNewChannelCell.newChannelNameField
            }
        } else if (indexPath as NSIndexPath).section == Section.currentChannelsSection.rawValue {
            cell.textLabel?.text = channels[(indexPath as NSIndexPath).row].name
        }
        
        return cell
    }
    
    // Make : UITabelViewDaleget 
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == Section.currentChannelsSection.rawValue {
            let channel = channels[(indexPath as NSIndexPath).row]
            self.performSegue(withIdentifier: "ShowChannel", sender: channel)
        }
    }
    // Make Navigation 
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        if let channel = sender as? Channel {
            let chatVc = segue.destination as! ChatViewController
            
            chatVc.senderDisplayName = senderDisplayName
            chatVc.channel = channel
            chatVc.channelRef = channelRef.child(channel.id)
        }
    }

    
    
    private lazy var channelRef: DatabaseReference = Database.database().reference().child("channels")
    private var channelRefHandle: DatabaseHandle?
    
    // MARK: Firebase related methods
    private func observeChannels() {
        // Use the observe method to listen for new
        // channels being written to the Firebase DB
        channelRefHandle = channelRef.observe(.childAdded, with: { (snapshot) -> Void in // 1 You call observe:with: on your channel reference, storing a handle to the reference. This calls the completion block every time a new channel is added to your database.
            let channelData = snapshot.value as! Dictionary<String, AnyObject> // 2 The completion receives a FIRDataSnapshot (stored in snapshot), which contains the data and other helpful methods.

            let id = snapshot.key
            if let name = channelData["name"] as! String!, name.characters.count > 0 { // 3 You pull the data out of the snapshot and, if successful, create a Channel model and add it to your channels array.
                self.channels.append(Channel(id: id, name: name))
                self.tableView.reloadData()
            } else {
                print("Error! Could not decode channel data")
            }
        })
    }

    // Make :Actione 
    
    @IBAction func createChannel(_ sender: AnyObject) {
        if let name = newChannelTextField?.text { // 1 First check if you have a channel name in the text field.
            let newChannelRef = channelRef.childByAutoId()// 2 Create a new channel reference with a unique key using childByAutoId()
            let channelItem = [ //3 Create a dictionary to hold the data for this channel. A [String: AnyObject] works as a JSON-like object.
                "name" : name
            ]
            newChannelRef.setValue(channelItem) // 4 Finally, set the name on this new channel, which is saved to Firebase automatically!
    }
 }

}


