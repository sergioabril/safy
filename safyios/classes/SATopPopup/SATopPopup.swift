//
//  WelcomeScreen.swift
//  usafe
//
//  Created by Sergio Abril Herrero on 6/5/16.
//  Copyright © 2016 Sergio Abril Herrero. All rights reserved.
//

import Foundation
import UIKit


open class SATopPopup:UIView{
    
    
    @IBOutlet weak var img: UIImageView!
    @IBOutlet weak var label: UILabel!
    
    let bannerheight:CGFloat = 64;
    var statusBarHeight:CGFloat = 0//UIApplication.sharedApplication().statusBarFrame.size.height;

    var delay = 3.0
    var animationTime = 0.5

    //Custom init
    init(title: String, frame: CGRect, bgcolor: UIColor? = nil, image: UIImage? = nil, noStatusBar: Bool? = false) {
        //Init superclass with frame
        super.init(frame: frame)
        //Create popup with given parameters
        self.createWith(title, frame: frame, bgcolor: bgcolor, image: image, noStatusBar: noStatusBar)
    }
    //Required init coder
    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
    
    //Create instance and return
    fileprivate func createWith(_ title: String, frame: CGRect, bgcolor: UIColor? = nil, image: UIImage? = nil, noStatusBar: Bool? = false, timeIn:Double? = 3) -> SATopPopup
    {
        //Set new statusbar. By default is 20, but can be 0 if you don't have status bar
        if(noStatusBar! == true){
            self.statusBarHeight = 0
        }
        //Set delay until it hides
        delay = timeIn!
        //Load the xib with the banner
        let mySATopPopup = UINib(nibName: "SATopPopup", bundle: nil).instantiate(withOwner: nil, options: nil)[0] as? SATopPopup
        //Place it offsetted on Y an amount: statusBarHeight
        mySATopPopup!.frame = CGRect(x: 0, y: statusBarHeight,width: self.frame.size.width, height: bannerheight)
        //Set the frame of this view
        self.frame = CGRect(x: 0, y: -(bannerheight+statusBarHeight), width: mySATopPopup!.frame.width, height: bannerheight+statusBarHeight)
        //Set the text of the notification
        mySATopPopup!.label.text = title
        
        //Set an image?
        if image != nil
        {
            mySATopPopup!.img.image = image
        }
        
        //Change colors?
        if bgcolor != nil
        {
            mySATopPopup!.backgroundColor = bgcolor!
            self.backgroundColor = bgcolor!
        }else{
            self.backgroundColor = mySATopPopup!.backgroundColor!
        }
        
        //Add the banner as a subview to current instance. As a result, it will be offsetted +statusBarHeight
        self.addSubview(mySATopPopup!)

        //Return
        return self
    }
    
    //Show function with an optional completion function, which is
    func show(_ completion:((_ finished: Bool)->())? = nil){
        //Start animation
        UIView.animate (withDuration: self.animationTime, delay: 0.2, options: UIViewAnimationOptions() ,animations: {
            self.frame = CGRect(x: 0, y: 0, width: self.frame.width, height: self.bannerheight+self.statusBarHeight)
            }, completion: { _ in
                //Finished
        })
        
        //Close after delay
        UIView.animate (withDuration: self.animationTime, delay: self.delay, options: UIViewAnimationOptions() ,animations: {
            self.frame = CGRect(x: 0, y: -(self.bannerheight+self.statusBarHeight), width: self.frame.width, height: self.bannerheight+self.statusBarHeight)
            }, completion: { _ in
                //Return completion handler when finish (if asked, otherwise, it'll nil)
                if let comphandler = completion {
                    comphandler(true)
                }else{
                    print("valia nul")
                }
        })

    }
    
}
