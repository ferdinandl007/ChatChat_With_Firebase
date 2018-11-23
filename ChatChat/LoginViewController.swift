
//  ChatChat
//
//  Created by Ferdinand Lösch on 23/11/2018.
//  Copyright © 2018 Razeware LLC. All rights reserved.
//

import UIKit
import Firebase

class LoginViewController: UIViewController {
  
  @IBOutlet weak var nameField: UITextField!
  @IBOutlet weak var bottomLayoutGuideConstraint: NSLayoutConstraint!
  
  // MARK: View Lifecycle
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShowNotification(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHideNotification(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
    NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
  }
  
  @IBAction func loginDidTouch(_ sender: AnyObject) {
    if nameField?.text != "" {
        Auth.auth().signInAnonymously(completion: { (user, error) in
            if let err = error {
                print(err.localizedDescription)
                return
            }
            self.performSegue(withIdentifier: "LoginToChat", sender: nil)
        })
    }
  }
    
    
  
  // MARK: - Notifications
  
  @objc func keyboardWillShowNotification(_ notification: Notification) {
    let keyboardEndFrame = ((notification as NSNotification).userInfo![UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
    let convertedKeyboardEndFrame = view.convert(keyboardEndFrame, from: view.window)
    bottomLayoutGuideConstraint.constant = view.bounds.maxY - convertedKeyboardEndFrame.minY
  }
  
// mark Navigation 
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        let navVc = segue.destination as! UINavigationController
        let channelVc = navVc.viewControllers.first as! ChannelListViewController
        
        channelVc.senderDisplayName = nameField?.text
    }
    

    
    @objc func keyboardWillHideNotification(_ notification: Notification) {
    bottomLayoutGuideConstraint.constant = 48
  }
  
}

