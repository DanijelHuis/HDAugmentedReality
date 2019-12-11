//
//  ARAnnotationView.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 23/04/15.
//  Copyright (c) 2015 Danijel Huis. All rights reserved.
//

import UIKit

/**
 The visual representation of your annotation on augmented reality screen. Analogue to MKAnnotationView. 
 It is usually subclassed to provide custom look.
 
 Annotation views should be lightweight, try to avoid xibs and autolayout.
 */
open class ARAnnotationView: UIView
{
    //===== Public
    /** 
     Normally, center of annotationView points to real location of POI, but this property can be used to alter that.
     E.g. if you have a downward arrow at center bottom part of your view then you should set this to (0.5, 1)
     */
    open var centerOffset = CGPoint(x: 0.5, y: 0.5)
    /// Annotation associated with this view.
    open weak var annotation: ARAnnotation?

    //===== Internal
    /// Internal usage. Position of annotation view without heading, pitch, stack offsets.
    internal var arPosition: CGPoint = CGPoint(x: 0, y: 0)
    /// Internal usage. Offset for arPosition, this is not offset for heading/pitch but offset that is set in ARPresenterTransform.
    internal var arPositionOffset = CGPoint(x: 0, y: 0)
    /// Internal usage. Used for calculations.
    internal var arAlternateFrame: CGRect = CGRect.zero

    fileprivate var initialized: Bool = false
    
    public init()
    {
        super.init(frame: CGRect.zero)
        self.initializeInternal()
    }

    public required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        self.initializeInternal()
    }
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        self.initializeInternal()
    }
    
    fileprivate func initializeInternal()
    {
        if self.initialized
        {
            return
        }
        self.initialized = true;
        self.initialize()
    }
    
    open override func awakeFromNib()
    {
        self.bindUi()
    }
    
    /// Will always be called once, no need to call super
    open func initialize()
    {
    
    }
    
    /// Called when distance/azimuth changes, intended to be used in subclasses
    open func bindUi()
    {
        
    }
    

}
