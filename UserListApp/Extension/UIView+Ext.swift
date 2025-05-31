//
//  UIView+Ext.swift
//  SumaMind
//
//  Created by vantientu on 4/17/25.
//

import UIKit

public extension UIView {
    
    func roundCornerWithShadow(cornerRadius: CGFloat,
                               shadowRadius: CGFloat,
                               offsetX: CGFloat,
                               offsetY: CGFloat,
                               color: UIColor,
                               opacity: Float) {
        self.clipsToBounds = false
        let layer = self.layer
        layer.masksToBounds = false
        layer.cornerRadius = cornerRadius
        layer.shadowOffset = CGSize(width: offsetX, height: offsetY);
        layer.shadowColor = color.cgColor
        layer.shadowRadius = shadowRadius
        layer.shadowOpacity = opacity
        layer.speed = 0
        layer.shadowPath = UIBezierPath(roundedRect: layer.bounds, cornerRadius: layer.cornerRadius).cgPath
        
        let bColour = self.backgroundColor
        self.backgroundColor = nil
        layer.backgroundColor = bColour?.cgColor
    }
    
    func removeRoundCornerWithShadow() {
        self.clipsToBounds = false
        let layer = self.layer
        self.backgroundColor = self.layer.backgroundColor != nil ? UIColor(cgColor: self.layer.backgroundColor!) : .clear
        layer.masksToBounds = false
        layer.cornerRadius = 0
        layer.shadowOffset = CGSize(width: 0, height: 0);
        layer.shadowColor = UIColor.clear.cgColor
        layer.shadowRadius = 0
        layer.shadowOpacity = 0
        layer.speed = 0
        layer.shadowPath = UIBezierPath(roundedRect: layer.bounds, cornerRadius: layer.cornerRadius).cgPath
    }
}
