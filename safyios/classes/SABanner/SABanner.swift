//
//  SAOvalLoader.swift
//  SBLoader
//
//  Created by Satraj Bambra on 2015-03-17.
//  Copyright (c) 2015 Satraj Bambra. All rights reserved.
//

import UIKit

class SABanner: UIView {
    
    let zeroframe = CGRect(x: 0, y: 0, width: 0, height: 0)

    var parentView: UIView = UIView()
    
    var blurBackground: Bool = true
    var ovalColor:UIColor = UIColor.white
    
    var isShown: Bool = false
    
    
    var label:UILabel = UILabel()
    
    //Custom init
    init(onView: UIView, radius:CGFloat, blurBackground:Bool? = true, color:UIColor? = UIColor.white){
        super.init(frame: zeroframe)
        backgroundColor = UIColor.clear
        self.parentView = onView
        self.frame = onView.bounds
        self.blurBackground = blurBackground!
        self.ovalColor = color!
        onView.addSubview(self)
    }
    
    //Override init: We don't want anybody to initialize just with the frame
    private override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)!
    }
    
    //MARK: External functions to be called
    func show(text:String, duration:Int = 4){
        //If it's already shown, don't add again
        if(isShown){return}
        isShown = true
       
        Timer.scheduledTimer(timeInterval: TimeInterval(duration), target: self, selector: #selector(hidebanner),
                             userInfo: nil, repeats: false)
        if(blurBackground){
            createBlur()
        }
    }
    
    @objc private func hidebanner(){
        if(!isShown){return}
        isShown = false
        if(blurBackground){
            removeBlur()
        }
    }

    //MARK: Blur
    func createBlur(){
        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = parentView.frame
        blurEffectView.alpha = 0
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight] // for supporting device rotation
        parentView.addSubview(blurEffectView)
        parentView.bringSubview(toFront: self) //Move oval over blur
        UIView.animate(withDuration: 0.5, animations: {
            blurEffectView.alpha = 0.8
        }) { (Bool) in
            //
        }
        
    }
    
    func removeBlur(){
        var blurToRemove:UIVisualEffectView?
        for view in parentView.subviews {
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

