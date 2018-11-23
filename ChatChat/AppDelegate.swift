
//  ChatChat
//
//  Created by Ferdinand Lösch on 23/11/2018.
//  Copyright © 2018 Razeware LLC. All rights reserved.
//

import UIKit
import Firebase

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    FirebaseApp.configure()
    return true
  }

}

