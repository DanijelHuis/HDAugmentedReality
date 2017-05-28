//
//  ARPresenter.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 16/12/2016.
//  Copyright © 2016 Danijel Huis. All rights reserved.
//

import UIKit
import CoreLocation

/**
 Adds ARAnnotationViews on the screen and calculates its screen positions. Before anything 
 is done, it first filters annotations by distance and count for improved performance. This 
 class is also responsible for vertical stacking of the annotation views. 
 
 It can be subclassed if custom positioning is needed, e.g. if you wan't to position 
 annotations relative to its altitudes you would subclass ARPresenter and override 
 xPositionForAnnotationView and yPositionForAnnotationView.
 */
open class ARPresenter: UIView
{
    /**
     Stacks overlapping annotations vertically.
    */
    open var verticalStackingEnabled = false
    
    /**
     How much to vertically offset annotations by distance, in pixels per meter. Use it if distanceOffsetMode is manual or automaticOffsetMinDistance.
     
     Also look at distanceOffsetMinThreshold and distanceOffsetMode.
    */
    open var distanceOffsetMultiplier: Double?
    
    /**
     All annotations farther(from user) than this value will be offset using distanceOffsetMultiplier. Use it if distanceOffsetMode is manual.
     
     Also look at distanceOffsetMultiplier and distanceOffsetMode.
    */
    open var distanceOffsetMinThreshold: Double = 0
    
    /**
     Distance offset mode, it affects vertical offset of annotations by distance.
     */
    open var distanceOffsetMode = DistanceOffsetMode.automatic
    
    /**
     If set, it will be used instead of distanceOffsetMultiplier and distanceOffsetMinThreshold if distanceOffsetMode != none
     Use it to calculate vartical offset by given distance.
    */
    open var distanceOffsetFunction: ((_ distance: Double) -> Double)?
    
    /**
     How low on the screen is nearest annotation. 0 = top, 1  = bottom.
    */
    open var bottomBorder: Double = 0.55
    
    /**
     Distance offset mode, it affects vertical offset of annotations by distance.
     */
    public enum DistanceOffsetMode
    {
        /// Annotations are not offset vertically with distance.
        case none
        /// Use distanceOffsetMultiplier and distanceOffsetMinThreshold to control offset.
        case manual
        /// distanceOffsetMinThreshold is set to closest annotation, distanceOffsetMultiplier must be set by user.
        case automaticOffsetMinDistance
        /**
         distanceOffsetMinThreshold is set to closest annotation and distanceOffsetMultiplier
         is set to fit all annotations on screen vertically(before stacking)
         */
        case automatic
    }

    open weak var arViewController: ARViewController!
    /// All annotations
    open var annotations: [ARAnnotation] = []
    /// Annotations filtered by distance/maxVisibleAnnotations. Look at activeAnnotationsFromAnnotations.
    open var activeAnnotations: [ARAnnotation] = []
    /// AnnotionViews for all active annotations, this is set in createAnnotationViews.
    open var annotationViews: [ARAnnotationView] = []
    /// AnnotationViews that are on visible part of the screen or near its border.
    open var visibleAnnotationViews: [ARAnnotationView] = []

    init(arViewController: ARViewController)
    {
        self.arViewController = arViewController
        super.init(frame: CGRect.zero)
    }
    
    required public init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    /**
     Total maximum number of visible annotation views. Default value is 100. Max value is 500.
     This will affect performance, especially if verticalStackingEnabled.
    */
    open var maxVisibleAnnotations = 100
    {
        didSet
        {
            if(maxVisibleAnnotations > MAX_VISIBLE_ANNOTATIONS)
            {
                maxVisibleAnnotations = MAX_VISIBLE_ANNOTATIONS
            }
        }
    }
    /**
     Maximum distance(in meters) for annotation to be shown.
     Default value is 0 meters, which means that distances of annotations don't affect their visiblity.
     
     This can be used to increase performance.
    */
    open var maxDistance: Double = 0

    
    //==========================================================================================================================================================
    // MARK:                                                               Reload - main logic
    //==========================================================================================================================================================
    /**
     This is called from ARViewController, it handles main logic, what is called and when.
    */
    open func reload(annotations: [ARAnnotation], reloadType: ARViewController.ReloadType)
    {
        guard self.arViewController.arStatus.ready else { return }
        var relayoutIsNeeded = false
        
        //===== Filtering annotations and creating annotation views, only done on new reload location or when annotations changed.
        if reloadType == .annotationsChanged || reloadType == .reloadLocationChanged || self.annotations.count == 0
        {
            self.annotations = annotations
            self.activeAnnotations = self.activeAnnotationsFromAnnotations(annotations: annotations)
            self.createAnnotationViews()
            
            relayoutIsNeeded = true
        }
        
        //===== Here we do stuff that must be done even on .userLocationChanged
        if relayoutIsNeeded || reloadType == .userLocationChanged
        {
            self.adjustDistanceOffsetParameters()
            
            for annotationView in self.annotationViews
            {
                annotationView.bindUi()
            }
            
            relayoutIsNeeded = true
        }
    
        let stackIsNeeded = relayoutIsNeeded && self.verticalStackingEnabled
        if stackIsNeeded
        {
            // This must be done before layout
            self.resetStackParameters()
        }
        
        self.addRemoveAnnotationViews(arStatus: self.arViewController.arStatus)
        self.layoutAnnotationViews(arStatus: self.arViewController.arStatus, relayoutAll: relayoutIsNeeded)
        
        if stackIsNeeded
        {
            // This must be done after layout.
            self.stackAnnotationViews()
        }
    }
    
    //==========================================================================================================================================================
    // MARK:                                                               Filtering(Active annotations)
    //==========================================================================================================================================================
    
    /**
     Gives opportunity to the presenter to filter annotations and reduce number of items it is working with.
     
     Default implementation filters by maxVisibleAnnotations and maxDistance.
     */
    open func activeAnnotationsFromAnnotations(annotations: [ARAnnotation]) -> [ARAnnotation]
    {
        var activeAnnotations: [ARAnnotation] = []
        
        for annotation in annotations
        {
            // maxVisibleAnnotations filter
            if activeAnnotations.count >= self.maxVisibleAnnotations
            {
                annotation.active = false
                continue
            }
            
            // maxDistance filter
            if self.maxDistance != 0 && annotation.distanceFromUser > self.maxDistance
            {
                annotation.active = false
                continue
            }
            
            annotation.active = true
            activeAnnotations.append(annotation)
        }
        
        return activeAnnotations
    }
    
    //==========================================================================================================================================================
    // MARK:                                                               Creating annotation views
    //==========================================================================================================================================================
    
    /**
     Creates views for active annotations and removes views from inactive annotations.
     @IMPROVEMENT: Add reuse logic
    */
    open func createAnnotationViews()
    {
        var annotationViews: [ARAnnotationView] = []
        let activeAnnotations = self.activeAnnotations
        
        // Removing existing annotation views and reseting some properties
        for annotationView in self.annotationViews
        {
            annotationView.removeFromSuperview()
        }
        
        // Destroy views for inactive anntotations
        for annotation in self.annotations
        {
            if(!annotation.active)
            {
                annotation.annotationView = nil
            }
        }
        
        // Create views for active annotations
        for annotation in activeAnnotations
        {
            var annotationView: ARAnnotationView? = nil
            if annotation.annotationView != nil
            {
                annotationView = annotation.annotationView
            }
            else
            {
                annotationView = self.arViewController.dataSource?.ar(self.arViewController, viewForAnnotation: annotation)
            }
            
            annotation.annotationView = annotationView
            if let annotationView = annotationView
            {
                annotationView.annotation = annotation
                annotationViews.append(annotationView)
            }
        }
        
        self.annotationViews = annotationViews
    }
    
    /// Removes all annotation views from screen and resets annotations
    open func clear()
    {
        for annotation in self.annotations
        {
            annotation.active = false
            annotation.annotationView = nil
        }
        
        for annotationView in self.annotationViews
        {
            annotationView.removeFromSuperview()
        }
        
        self.annotations = []
        self.activeAnnotations = []
        self.annotationViews = []
        self.visibleAnnotationViews = []
    }
    
    
    //==========================================================================================================================================================
    // MARK:                                                               Add/Remove
    //==========================================================================================================================================================
    
    /**
     Adds/removes annotation views to/from superview depending if view is on visible part of the screen.
     Also, if annotation view is on visible part, it is added to visibleAnnotationViews.
    */
    open func addRemoveAnnotationViews(arStatus: ARStatus)
    {
        let degreesDeltaH = arStatus.hFov
        let heading = arStatus.heading
        self.visibleAnnotationViews.removeAll()
        
        for annotation in self.activeAnnotations
        {
            guard let annotationView = annotation.annotationView else { continue }
            
            // This is distance of center of annotation to the center of screen, measured in degrees
            let delta = deltaAngle(heading, annotation.azimuth)
            
            if fabs(delta) < degreesDeltaH
            {
                if annotationView.superview == nil
                {
                    self.addSubview(annotationView)
                }
                self.visibleAnnotationViews.append(annotationView)
            }
            else
            {
                if annotationView.superview != nil
                {
                    annotationView.removeFromSuperview()
                }
            }
        }
    }

    //==========================================================================================================================================================
    // MARK:                                                               Layout
    //==========================================================================================================================================================
       /**
     Layouts annotation views.
     - Parameter relayoutAll: If true it will call xPositionForAnnotationView/yPositionForAnnotationView for each annotation view, else
                              it will only take previously calculated x/y positions and add heading/pitch offsets to visible annotation views.
     */
    open func layoutAnnotationViews(arStatus: ARStatus, relayoutAll: Bool)
    {
        let pitchYOffset = CGFloat(arStatus.pitch * arStatus.vPixelsPerDegree)
        let annotationViews = relayoutAll ? self.annotationViews : self.visibleAnnotationViews
        
        for annotationView in annotationViews
        {
            guard let annotation = annotationView.annotation else { continue }
            
            if(relayoutAll)
            {
                let x = self.xPositionForAnnotationView(annotationView, arStatus: arStatus)
                let y = self.yPositionForAnnotationView(annotationView, arStatus: arStatus)
                annotationView.arZeroPoint = CGPoint(x: x, y: y)
            }
            let headingXOffset = CGFloat(deltaAngle(annotation.azimuth, arStatus.heading)) * CGFloat(arStatus.hPixelsPerDegree)

            let x: CGFloat = annotationView.arZeroPoint.x + headingXOffset
            let y: CGFloat = annotationView.arZeroPoint.y + pitchYOffset + annotationView.arStackOffset.y
            
            // Final position of annotation
            annotationView.frame = CGRect(x: x, y: y, width: annotationView.bounds.size.width, height: annotationView.bounds.size.height)
        }
    }
    
    /**
     x position without the heading, heading offset is added in layoutAnnotationViews due to performance.
     */
    open func xPositionForAnnotationView(_ annotationView: ARAnnotationView, arStatus: ARStatus) -> CGFloat
    {
        let centerX = self.bounds.size.width * 0.5
        let x = centerX - (annotationView.bounds.size.width * annotationView.centerOffset.x)
        return x
    }
    
    /**
     y position without the pitch, pitch offset is added in layoutAnnotationViews due to performance.
     */
    open func yPositionForAnnotationView(_ annotationView: ARAnnotationView, arStatus: ARStatus) -> CGFloat
    {
        guard let annotation = annotationView.annotation else { return 0}
        let bottomY = self.bounds.size.height * CGFloat(self.bottomBorder)
        let distance = annotation.distanceFromUser
        
        // Offset by distance
        var distanceOffset: Double = 0
        if self.distanceOffsetMode != .none
        {
            if let function = self.distanceOffsetFunction
            {
                distanceOffset = function(distance)
            }
            else if distance > self.distanceOffsetMinThreshold, let distanceOffsetMultiplier = self.distanceOffsetMultiplier
            {
                let distanceForOffsetCalculation = distance - self.distanceOffsetMinThreshold
                distanceOffset = -(distanceForOffsetCalculation * distanceOffsetMultiplier)
                
            }
        }
        
        // y
        let y = bottomY - (annotationView.bounds.size.height * annotationView.centerOffset.y) + CGFloat(distanceOffset)
        return y
    }
    
    //==========================================================================================================================================================
    // MARK:                                                               DistanceOffset
    //==========================================================================================================================================================
    open func adjustDistanceOffsetParameters()
    {
        guard var minDistance = self.activeAnnotations.first?.distanceFromUser else { return }
        guard let maxDistance = self.activeAnnotations.last?.distanceFromUser else { return }
        if minDistance > maxDistance { minDistance = maxDistance }
        let deltaDistance = maxDistance - minDistance
        let availableHeight = Double(self.bounds.size.height) * self.bottomBorder - 30 // 30 because we don't want them to be on top but little bit below
        
        if self.distanceOffsetMode == .automatic
        {
            self.distanceOffsetMinThreshold = minDistance
            self.distanceOffsetMultiplier = deltaDistance > 0 ? availableHeight / deltaDistance : 0
        }
        else if self.distanceOffsetMode == .automaticOffsetMinDistance
        {
            self.distanceOffsetMinThreshold = minDistance
        }
    }
}











