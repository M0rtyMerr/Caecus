//
//  AppDelegate.swift
//  Caecus
//
//  Created by Anton Nazarov on 05/03/2019.
//  Copyright © 2019 Anton Nazarov. All rights reserved.
//

import UIKit
import Then
import Reusable

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow().then {
            $0.backgroundColor = .white
            $0.makeKeyAndVisible()
            $0.rootViewController = UINavigationController(rootViewController: CaptureViewController.instantiate())
        }
        return true
    }
}
