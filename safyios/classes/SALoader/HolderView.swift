//
//  HolderView.swift
//  SBLoader
//
//  Created by Satraj Bambra on 2015-03-17.
//  Copyright (c) 2015 Satraj Bambra. All rights reserved.
//

import UIKit

protocol HolderViewDelegate:class {
  func animateLabel()
}

class HolderView: UIView {
    
    let ovalLayer = OvalLayer()
    var parentFrame :CGRect = CGRect(x: 0, y: 0, width: 0, height: 0)
    weak var delegate:HolderViewDelegate?
    
    //Esto se crea y lo responde
    public func create(frame:CGRect) -> UIView{
        return HolderView.init(frame: frame)
    }
    
    //Sobreescribir init
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear
        
        //Adding and Animating wobble
        self.addOval()
        Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(self.wobbleOval),
                                               userInfo: nil, repeats: false)
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)!
    }
    
    func addOval() {
        layer.addSublayer(ovalLayer)
        ovalLayer.expand()
    }
    
    func wobbleOval() {
        ovalLayer.wobble()
    }
}
