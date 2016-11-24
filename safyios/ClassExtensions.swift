//
//  ClassExtensions.swift
//  safymac
//
//  Created by Sergio Abril Herrero on 23/11/16.
//  Copyright © 2016 Sergio Abril Herrero. All rights reserved.
//

import Foundation
import UIKit



//To get caracters from bytes:  http://stackoverflow.com/questions/34079555/swift-2-1-uint8-utf8-string#34079948
extension Collection where Iterator.Element == UInt8 {
    var data: Data { return Data(bytes: Array(self)) }
    var utf8string: String { return String(data: data, encoding: .utf8) ?? "" }
}

extension String.UTF8View {
    var arrayofutf8bytes: [UInt8] { return Array(self) }
}

extension UIView{
    
    //Blurrea y devuelve una referencia a la view blurreadora, para quitarla
    func blurView(){
        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = frame
        blurEffectView.alpha = 0
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight] // for supporting device rotation
        self.addSubview(blurEffectView)
        UIView.animate(withDuration: 0.5, animations: {
            //
            blurEffectView.alpha = 0.8
        }) { (Bool) in
            //
        }
        
    }
    
    func unBlurView(){
        var blurToRemove:UIVisualEffectView?
        for view in self.subviews {
            if let blurview = view as? UIVisualEffectView {
                blurToRemove = blurview
            }
        }
        UIView.animate(withDuration: 0.5, animations: {
            //
            blurToRemove?.alpha = 0
        }) { (Bool) in
            //
            blurToRemove?.removeFromSuperview()
        }
        
    }
}
