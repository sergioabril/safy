//
//  SAOvalLoader.swift
//  SBLoader
//
//  Created by Satraj Bambra on 2015-03-17.
//  Copyright (c) 2015 Satraj Bambra. All rights reserved.
//

import UIKit

class SALoaderOvalBlur: UIView {
    
    let zeroframe = CGRect(x: 0, y: 0, width: 0, height: 0)
    var ovalLayer:OvalLayer!
    var parentView: UIView = UIView()
    var radius:CGFloat = 20
    
    var blurBackground: Bool = true
    var ovalColor:UIColor = UIColor.white
    
    var isShown: Bool = false
    
    //Custom init
    init(onView: UIView, radius:CGFloat, blurBackground:Bool? = true, color:UIColor? = UIColor.white){
        super.init(frame: zeroframe)
        backgroundColor = UIColor.clear
        self.parentView = onView
        self.radius = radius
        self.frame = self.calculateFrame()
        self.blurBackground = blurBackground!
        self.ovalColor = color!
        self.ovalLayer = OvalLayer(withColor: self.ovalColor)
        onView.addSubview(self)
    }
    
    //Override init: We don't want anybody to initialize just with the frame
    private override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)!
    }
    
    //Calculate new frame of this view, based on the desired radius and the frame of its parent view (which might have changed)
    func calculateFrame() -> CGRect{
        let rect = CGRect(x: self.parentView.frame.width/2 - self.radius,y: self.parentView.frame.height/2 - self.radius,width: self.radius*2, height: self.radius*2)
        return rect
    }

    //MARK: External functions to be called
    func show(){
        //If it's already shown, don't add again
        if(isShown){return}
        //Resize frame (sometimes it has changed since it was added to the view)
        self.frame = self.calculateFrame()
        //Adding and Animating wobble
        isShown = true
        layer.addSublayer(ovalLayer)
        ovalLayer.expand()
        Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(self.wobbleOval),
                             userInfo: nil, repeats: false)
        if(blurBackground){
            createBlur()
        }
    }
    
    func hide(){
        if(!isShown){return}
        isShown = false
        ovalLayer.removeFromSuperlayer()
        if(blurBackground){
            removeBlur()
        }
    }
    
    //MARK: Oval animation wobble
    func wobbleOval() {
        ovalLayer.wobble()
    }
    
    //MARK: Blur
    func createBlur(){
        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.dark)
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

//MARK: Shape Layer Class
class OvalLayer: CAShapeLayer {
    
    let animationDuration: CFTimeInterval = 0.4
    
    init(withColor: UIColor){
        super.init()
        fillColor = withColor.cgColor;
        path = ovalPathSmall.cgPath
    }
    
    override init() {
        super.init()
        fillColor = UIColor.white.cgColor
        path = ovalPathSmall.cgPath
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var ovalPathSmall: UIBezierPath {
        return UIBezierPath(ovalIn: CGRect(x: 20.0, y: 20.0, width: 0.0, height: 0.0))
    }
    
    var ovalPathLarge: UIBezierPath {
        return UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 40.0, height: 40.0))
    }
    
    var ovalPathSquishVertical: UIBezierPath {
        return UIBezierPath(ovalIn: CGRect(x: 0, y: 2.5, width: 40.0, height: 35.0))
    }
    
    var ovalPathSquishHorizontal: UIBezierPath {
        return UIBezierPath(ovalIn: CGRect(x: 2.5, y: 0, width: 35.0, height: 40.0))
    }
    
    func expand() {
        let expandAnimation: CABasicAnimation = CABasicAnimation(keyPath: "path")
        expandAnimation.fromValue = ovalPathSmall.cgPath
        expandAnimation.toValue = ovalPathLarge.cgPath
        expandAnimation.duration = 0.3 //because wobble starts after 0.3f
        expandAnimation.fillMode = kCAFillModeForwards
        expandAnimation.isRemovedOnCompletion = false
        add(expandAnimation, forKey: nil)
    }
    
    func wobble() {
        // 1
        let wobbleAnimation1: CABasicAnimation = CABasicAnimation(keyPath: "path")
        wobbleAnimation1.fromValue = ovalPathLarge.cgPath
        wobbleAnimation1.toValue = ovalPathSquishVertical.cgPath
        wobbleAnimation1.beginTime = 0.0
        wobbleAnimation1.duration = animationDuration
        
        // 2
        let wobbleAnimation2: CABasicAnimation = CABasicAnimation(keyPath: "path")
        wobbleAnimation2.fromValue = ovalPathSquishVertical.cgPath
        wobbleAnimation2.toValue = ovalPathSquishHorizontal.cgPath
        wobbleAnimation2.beginTime = wobbleAnimation1.beginTime + wobbleAnimation1.duration
        wobbleAnimation2.duration = animationDuration
        
        // 3
        let wobbleAnimation3: CABasicAnimation = CABasicAnimation(keyPath: "path")
        wobbleAnimation3.fromValue = ovalPathSquishHorizontal.cgPath
        wobbleAnimation3.toValue = ovalPathSquishVertical.cgPath
        wobbleAnimation3.beginTime = wobbleAnimation2.beginTime + wobbleAnimation2.duration
        wobbleAnimation3.duration = animationDuration
        
        // 4
        let wobbleAnimation4: CABasicAnimation = CABasicAnimation(keyPath: "path")
        wobbleAnimation4.fromValue = ovalPathSquishVertical.cgPath
        wobbleAnimation4.toValue = ovalPathLarge.cgPath
        wobbleAnimation4.beginTime = wobbleAnimation3.beginTime + wobbleAnimation3.duration
        wobbleAnimation4.duration = animationDuration
        
        // 5
        let wobbleAnimationGroup: CAAnimationGroup = CAAnimationGroup()
        wobbleAnimationGroup.animations = [wobbleAnimation1, wobbleAnimation2, wobbleAnimation3,
                                           wobbleAnimation4]
        wobbleAnimationGroup.duration = wobbleAnimation4.beginTime + wobbleAnimation4.duration
        wobbleAnimationGroup.repeatCount = 20
        add(wobbleAnimationGroup, forKey: nil)
    }
    
}
