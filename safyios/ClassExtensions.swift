//
//  ClassExtensions.swift
//  safymac
//
//  Created by Sergio Abril Herrero on 23/11/16.
//  Copyright © 2016 Sergio Abril Herrero. All rights reserved.
//

import Foundation
import UIKit



//To get caracters from bytes
extension UInt8 {
    //para luego pasar de bytes a string
    var character: Character {
        return Character(UnicodeScalar(self))
    }
}
