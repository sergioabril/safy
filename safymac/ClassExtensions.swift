//
//  ClassExtensions.swift
//  safymac
//
//  Created by Sergio Abril Herrero on 23/11/16.
//  Copyright © 2016 Sergio Abril Herrero. All rights reserved.
//

import Foundation
import Cocoa

//To change color of button: Image from color
extension NSImage {
    class func swatchWithColor(color: NSColor, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.drawSwatch(in: NSMakeRect(0, 0, size.width, size.height))
        image.unlockFocus()
        return image
    }
}

//To get caracters from bytes
extension UInt8 {
    //para luego pasar de bytes a string
    var character: Character {
        return Character(UnicodeScalar(self))
    }
}

//Clean textfields on clicks
extension NSTextField{
    override open func becomeFirstResponder() -> Bool {
        //Clean
        self.stringValue = ""
        return true
    }
}
