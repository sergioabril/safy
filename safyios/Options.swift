//
//  Options.swift
//  safymac
//
//  Created by Sergio Abril Herrero on 31/12/16.
//  Copyright © 2016 Sergio Abril Herrero. All rights reserved.
//

import Foundation
import UIKit

class Options:UITableViewController{
    
    override func viewDidLoad() {
        //Remove navigation bar lines and shadows
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
    }
}
