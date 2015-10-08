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
public class ARAnnotationView: UIView
{
    public weak var annotation: ARAnnotation?
    private var initialized: Bool = false
    
    public init()
    {
        super.init(frame: CGRectZero)
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
    
    private func initializeInternal()
    {
        if self.initialized
        {
            return
        }
        self.initialized = true;
        self.initialize()
    }
    
    public override func awakeFromNib()
    {
        self.bindUi()
    }
    
    /// Will always be called once, no need to call super
    public func initialize()
    {
    
    }
    
    /// Called when distance/azimuth changes, intended to be used in subclasses
    public func bindUi()
    {
        
    }
}
