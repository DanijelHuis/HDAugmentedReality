//
//  ARAnnotationView.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 23/04/15.
//  Copyright (c) 2015 Danijel Huis. All rights reserved.
//

import UIKit

/// View for annotation. Subclass to customize. Annotation views should be lightweight,
/// try to avoid xibs and autolayout.
/// bindUi method is called when distance/azimuth is set in ARViewController.
open class ARAnnotationView: UIView
{
    open weak var annotation: ARAnnotation?
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
