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


//To get caracters from bytes:  http://stackoverflow.com/questions/34079555/swift-2-1-uint8-utf8-string#34079948
extension Collection where Iterator.Element == UInt8 {
    var data: Data { return Data(bytes: Array(self)) }
    var utf8string: String { return String(data: data, encoding: .utf8) ?? "" }
}

extension String.UTF8View {
    var arrayofutf8bytes: [UInt8] { return Array(self) }
}

//Clean textfields on clicks
extension NSTextField{
    override open func becomeFirstResponder() -> Bool {
        //Clean
        self.stringValue = ""
        return true
    }
}
