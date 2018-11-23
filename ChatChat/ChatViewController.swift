
//  ChatChat
//
//  Created by Ferdinand Lösch on 23/11/2018.
//  Copyright © 2018 Razeware LLC. All rights reserved.
//

import UIKit
import Firebase
import JSQMessagesViewController
import Photos

final class ChatViewController: JSQMessagesViewController {
  
  // MARK: Properties
    lazy var outgoingBubbleImageView: JSQMessagesBubbleImage = self.setupOutgoingBubble()
    lazy var incomingBubbleImageView: JSQMessagesBubbleImage = self.setupIncomingBubble()
    private lazy var messageRef: DatabaseReference = self.channelRef!.child("messages")
    private var newMessageRefHandle: DatabaseHandle?
    private let imageULRNotSetKey = "NOTSET"
    private var photoMessageMap = [String: JSQPhotoMediaItem] ()
    private var updatedMessageRafHandle: DatabaseHandle?
      private var localTyping = false // 2 Store whether the local user is typing in a private property.
    private lazy var userIsTypingRef: DatabaseReference =
        
        self.channelRef!.child("typingIndicator").child(self.senderId) // 1 Create a Firebase reference that tracks whether the local user is typing.

    var messages = [JSQMessage] ()
    var channelRef: DatabaseReference?
    var channel: Channel? {
        didSet {
            title = channel?.name
        }
    }

    // 3 Use a computed property to update localTyping and userIsTypingRef each time it’s changed. Now add the following:
    var isTyping: Bool {         get {
            return localTyping
        }
        set {
            // 3
            localTyping = newValue
            userIsTypingRef.setValue(newValue)
        }
    }
    private lazy var usersTypinQuery: DatabaseQuery = self.channelRef!.child("typingIndicator").queryOrderedByValue().queryEqual(toValue: true)
    lazy var stoerageRef: StorageReference = Storage.storage().reference(forURL: "gs://chatchat-40bfd.appspot.com")

    
    

    
  // MARK: View Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    self.senderId  = Auth.auth().currentUser?.uid
    collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
    collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero
    observeMessages()
    
  }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        odserveTyping()
    }
  
    
  // MARK: Collection view data source (and related) methods
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages[indexPath.item]
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int{
        return messages.count
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = messages[indexPath.item]
        if message.senderId == senderId {
            return outgoingBubbleImageView
        } else {
            return incomingBubbleImageView
        }

    }
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        return nil
    }
    
    private func addMessage(withId id: String, name: String, text: String) {
        if let message = JSQMessage(senderId: id, displayName: name, text: text) {
            messages.append(message)
        }
    }
    // some housekeeping and clean things up when the ChatViewController disappears
    deinit {
        if let refHandle = newMessageRefHandle {
            messageRef.removeObserver(withHandle: refHandle)
        }
        if let refHandle = updatedMessageRafHandle {
            messageRef.removeObserver(withHandle: refHandle)
        }
    }
    
  // MARK: Firebase related methods
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        let itemRef = messageRef.childByAutoId() // 1 Using childByAutoId(), you create a child reference with a unique key.
        let messageItem = [ // 2 Then you create a dictionary to represent the message.

            "senderId": senderId!,
            "senderName": senderDisplayName!,
            "text": text!,
            ]
        
        itemRef.setValue(messageItem) // 3 Next, you Save the value at the new child location.

        
        JSQSystemSoundPlayer.jsq_playMessageSentSound() // 4 You then play the canonical “message sent” sound.
        
        finishSendingMessage() // 5 Finally, complete the “send” action and reset the input toolbar to empty.
        // to indikat for no typing is ok
        isTyping = false
    }
    
    private func observeMessages(){
        messageRef = channelRef!.child("messages")
        
        // 1. Start by creating a query that limits the synchronization to the last 25 messages.

        let messageQuery = messageRef.queryLimited(toLast:30)
        
        // 2. We can use the observe method to listen for new
        // messages being written to the Firebase DB
        newMessageRefHandle = messageQuery.observe(.childAdded, with: { (snapshot) -> Void in
            // 3 Extract the messageData from the snapshot.

            let messageData = snapshot.value as! Dictionary<String, String>
            
            if let id = messageData["senderId"], let name = messageData["senderName"], let text = messageData["text"], text.count > 0 {
                // 4 Call addMessage(withId:name:text) to add the new message to the data source
                self.addMessage(withId: id, name: name, text: text)
                
                // 5
                self.finishReceivingMessage()
                
            } else if let id = messageData["senderId"],
                let photoURL = messageData["photoURL"] { // 1
                // 2 If so, create a new JSQPhotoMediaItem. This object encapsulates rich media in messages — exactly what you need here!

                if let mediaItem = JSQPhotoMediaItem(maskAsOutgoing: id == self.senderId) {
                    // 3 With that media item, call addPhotoMessage
                    self.addPhotoMesssage(with: id, key: snapshot.key, mediaItem: mediaItem)
                    // 4 Finally, check to make sure the photoURL contains the prefix for a Firebase Storage object. If so, fetch the image data.
                    if photoURL.hasPrefix("gs://") {
                        self.fetchImageDataAtURL(photoURL, forMediaItem: mediaItem, clearsPhotoMessageMapOnSuccessForKey: nil)
                    }
                }
            } else {
                print("Error! Could not decode message data")
            }
        })
        // We can also use the observer method to listen for
        // changes to existing messages.
        // We use this to be notified when a photo has been stored
        // to the Firebase Storage, so we can update the message data
        updatedMessageRafHandle = messageRef.observe(.childChanged, with: {(snapshot) in
            let key = snapshot.key
            let messageData = snapshot.value as! Dictionary<String, String> //1 Grabs the message data dictionary from the Firebase snapshot.
            
            if let photoURL = messageData["photoURL"] { // 2 Checks to see if the dictionary has a photoURL key set.
                //  The photo has been updated.

                if let mediaItem = self.photoMessageMap[key] { // 3 Checks to see if the dictionary has a photoURL key set.
                    self.fetchImageDataAtURL(photoURL, forMediaItem: mediaItem, clearsPhotoMessageMapOnSuccessForKey: key) // 4 Finally, fetches the image data and update the message with the image
           }
         }
       })
        
    }

    private func fetchImageDataAtURL(_ photoURL: String, forMediaItem mediaItem: JSQPhotoMediaItem, clearsPhotoMessageMapOnSuccessForKey key: String?) {
        // 1 Get a reference to the stored image.
        let storageRef = Storage.storage().reference(forURL: photoURL)
        
        // 2 Get the image data from the storage.

            
        storageRef.getData(maxSize: INT64_MAX, completion: { (data, error) in
            if let error = error {
                print("Error downloading image data: \(error)")
                return
            }
            
            // 3  Get the image metadata from the storage
            storageRef.getMetadata(completion: { (metadata, metadataErr) in
                if let error = metadataErr {
                    print("Error downloading metadata: \(error)")
                    return
                }
                
        
                
                // 4 If the metadata suggests that the image is a GIF you use a category on UIImage that was pulled in via the SwiftGifOrigin Cocapod. This is needed because UIImage doesn’t handle GIF images out of the box. Otherwise you just use UIImage in the normal fashion.

                if (metadata?.contentType == "image/gif") {
                 //   mediaItem.image = UIImage.gifWithData(data!)
                    print("GIF Errer")
                } else {
                    mediaItem.image = UIImage.init(data: data!)
                }
                self.collectionView.reloadData()
                
                // 5 Finally, you remove the key from your photoMessageMap now that you’ve fetched the image data.
                guard key != nil else {
                    return
                }
                self.photoMessageMap.removeValue(forKey: key!)
            })
        })
    }

    
    
    
    // MARK: UI and User Interaction
    private func  setupOutgoingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.outgoingMessagesBubbleImage(with: UIColor.jsq_messageBubbleBlue())    }
    
    private func setupIncomingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleLightGray())
    }
    
    // for set up text color by UIcolor
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! JSQMessagesCollectionViewCell
    let message = messages[indexPath.item]
        if message.senderId == senderId {
            cell.textView?.textColor = UIColor.white
        } else {
            cell.textView?.textColor = UIColor.black
        }
        return cell
    }
    override func textViewDidChange(_ textView: UITextView) {
        super.textViewDidChange(textView)
        // if the text is to empty the user is tyoing 
        isTyping = textView.text != ""
    }
    
    private func odserveTyping() {
        let typingIndicatorRef =  channelRef!.child("typingIndicator")
        userIsTypingRef = typingIndicatorRef.child(senderId)
        userIsTypingRef.onDisconnectRemoveValue()
        
       // You observe for changes using .value; this will call the completion block anytime it changes
        usersTypinQuery.observe(.value) { (data: DataSnapshot) in
            //You observe for changes using .value; this will call the completion block anytime it changes.

            if data.childrenCount == 1 && self.isTyping {
                return
            }
           // At this point, if there are users, it’s safe to set the indicator. Call scrollToBottomAnimated(animated:) to ensure the indicator is displayed.
            self.showTypingIndicator = data.childrenCount > 0
            self.scrollToBottom(animated: true)
        }
    }
    
    func sendPhotoMessage() -> String? {
        let itemRef = messageRef.childByAutoId()
        let messageItem = [
            "photoURL" : imageULRNotSetKey,
            "senderId" : senderId
            ] as [String : Any] as [String : Any]
        
        itemRef.setValue(messageItem)
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        finishSendingMessage()
        return itemRef.key
    }
    func setimageURL(_ url: String, forPhotoMessageWithKey key: String){
        let itemRef = messageRef.child(key)
        itemRef.updateChildValues(["photoURL": url])
    }
  
  // MARK: UITextViewDelegate methods
    // Here, you store the JSQPhotoMediaItem in your new property if the image key hasn’t yet been set. This allows you to retrieve it and update the message when the image is set later on.
    
    private func addPhotoMesssage(with id : String, key: String, mediaItem: JSQPhotoMediaItem){
        if let message = JSQMessage(senderId: id, displayName: "", media: mediaItem) {
            messages.append(message)
            if (mediaItem.image == nil) {
                photoMessageMap[key] = mediaItem
        }
            collectionView.reloadData()
    }
}
    
    
    override func didPressAccessoryButton(_ sender: UIButton) {
        let picker = UIImagePickerController()
        picker.delegate = self
        if (UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.camera)) {
            picker.sourceType = UIImagePickerController.SourceType.camera
        } else {
            picker.sourceType = UIImagePickerController.SourceType.photoLibrary
        }
        
        present(picker, animated: true, completion:nil)
    }
}

// MARK: Image Picker Delegate
extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
// Local variable inserted by Swift 4.2 migrator.
let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)

        
        picker.dismiss(animated: true, completion:nil)
        
        // 1 First, check to see if a photo URL is present in the info dictionary. If so, you know you have a photo from the library.
        if let photoReferenceUrl = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.phAsset)] as? URL {
            // Handle picking a Photo from the Photo Library
            // 2 Next, pull the PHAsset from the photo URL
            let assets = PHAsset.fetchAssets(withALAssetURLs: [photoReferenceUrl], options: nil)
            let asset = assets.firstObject
            
            // 3 You call sendPhotoMessage and receive the Firebase key.
            if let key = sendPhotoMessage() {
                // 4 Get the file URL for the image.

                asset?.requestContentEditingInput(with: nil, completionHandler: { (contentEditingInput, info) in
                    let imageFileURL = contentEditingInput?.fullSizeImageURL
                    
                    // 5 Create a unique path based on the user’s unique ID and the current time.

                    let path = "\(String(describing: Auth.auth().currentUser?.uid))/\(Int(Date.timeIntervalSinceReferenceDate * 1000))/\(photoReferenceUrl.lastPathComponent)"
                    
                    // 6 And (finally!) save the image file to Firebase Storage
                    self.stoerageRef.child(path).putFile(from: imageFileURL!, metadata: nil) { (metadata, error) in
                        if let error = error {
                            print("Error uploading photo: \(error.localizedDescription)")
                            return
                        }
                        // 7 Once the image has been saved, you call setImageURL() to update your photo message with the correct URL
                        self.setimageURL(self.stoerageRef.child((metadata?.path)!).description, forPhotoMessageWithKey: key)
                    }
                })
            }
        } else {
            // Handle picking a Photo from the Camera - TODO
            // 1 First you grab the image from the info dictionary.

            let image = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as! UIImage
            // 2 Then call your sendPhotoMessage() method to save the fake image URL to Firebase.
            if let key = sendPhotoMessage() {
                // 3  Next you get a JPEG representation of the photo, ready to be sent to Firebase storage.
                let imageData = image.jpegData(compressionQuality: 1.0)
                // 4 As before, create a unique URL based on the user’s unique id and the current time.

                let imagePath = Auth.auth().currentUser!.uid + "/\(Int(Date.timeIntervalSinceReferenceDate * 1000)).jpg"
                // 5  Create a FIRStorageMetadata object and set the metadata to image/jpeg.
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                // 6 Then save the photo to Firebase Storage
                stoerageRef.child(imagePath).putData(imageData!, metadata: metadata) { (metadata, error) in
                    if let error = error {
                        print("Error uploading photo: \(error)")
                        return
                    }
                    // 7 Once the image has been saved, you call setImageURL() again.
                    self.setimageURL(self.stoerageRef.child((metadata?.path)!).description, forPhotoMessageWithKey: key)
                }
            }
            
        }
    }
    
    
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion:nil)
    }
}


// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
	return input.rawValue
}
