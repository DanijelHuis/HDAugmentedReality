//
//  TouchView.swift
//  HDAugmentedReality
//
//  Created by Danijel Huis on 30/05/2019.
//

import UIKit

/**
 View that passes touches through itself, unless some subview is touched.
 */
open class TouchView: UIView
{
    override open func point(inside point: CGPoint, with event: UIEvent?) -> Bool
    {
        for subview in self.subviews
        {
            if subview.isHidden || !subview.isUserInteractionEnabled { continue }
            
            if subview.frame.contains(point) { return true }
        }
        
        return false
    }
}
