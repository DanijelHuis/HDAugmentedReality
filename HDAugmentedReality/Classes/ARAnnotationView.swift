//
//  ARAnnotationView.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 23/04/15.
//  Copyright (c) 2015 Danijel Huis. All rights reserved.
//

import UIKit

/**
 Responsible for presenting annotations visually. Analogue to MKAnnotationView. 
 It is usually subclassed to provide custom look.
 
 Annotation views should be lightweight, try to avoid xibs and autolayout.
 */
open class ARAnnotationView: UIView
{
    //===== Public
    /** 
     Normally, center of annotationView points to real location of POI, but this property can be used to alter that.
     E.g. if bottom-left edge of annotationView should point to real location, centerOffset should be (0, 1)
     */
    open var centerOffset = CGPoint(x: 0.5, y: 0.5)
    open weak var annotation: ARAnnotation?

    // Used internally for stacking
    internal var arStackOffset = CGPoint(x: 0, y: 0)
    internal var arStackAlternateFrame: CGRect = CGRect.zero
    internal var arStackAlternateFrameExists: Bool = false
    /// Position of annotation view without heading, pitch, stack offsets.
    internal var arZeroPoint: CGPoint = CGPoint(x: 0, y: 0)

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
