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
    open var annotations: [ARAnnotation] = []
    open var activeAnnotations: [ARAnnotation] = []
    open var annotationViews: [ARAnnotationView] = []
    
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
        var stackIsNeeded = false
        var recreated = false
        
        //===== Filtering annotations and creating annotation views, only done on new reload location or when annotations changed.
        if reloadType == .annotationsChanged || reloadType == .reloadLocationChanged || self.annotations.count == 0
        {
            self.annotations = annotations
            self.activeAnnotations = self.activeAnnotationsFromAnnotations(annotations: annotations)
            self.createAnnotationViews()
            
            recreated = true
        }
        
        //===== Determening if stacking is needed
        if recreated || reloadType == .userLocationChanged
        {
            self.adjustVerticalOffsetParameters()
            stackIsNeeded = self.verticalStackingEnabled
            
            for annotationView in self.annotationViews
            {
                annotationView.bindUi()
            }
        }
    
        if stackIsNeeded
        {
            // This must be done before layout
            self.resetStackParameters()
        }
        
        self.addRemoveAnnotationViews(arStatus: self.arViewController.arStatus)
        self.layoutAnnotationViews(arStatus: self.arViewController.arStatus, layoutAll: stackIsNeeded)
        
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
    }
    
    
    //==========================================================================================================================================================
    // MARK:                                                               Layout
    //==========================================================================================================================================================
    
    /**
     Adds/removes annotations to/from superview depending if view is visible or not. Eg. annotations
     that are behind user are not visible so we remove them from superview. This is called very often.
     
     The intention is to reduce number of views on screen, not sure if this helps...
    */
    open func addRemoveAnnotationViews(arStatus: ARStatus)
    {
        let degreesDeltaH = arStatus.hFov
        let heading = arStatus.heading

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
    
    /**
     Calls xPositionForAnnotationView and yPositionForAnnotationView for every annotationView
     - Parameter layoutAll: if true it will set frame to all views, if false it will set frame to only views with superviews
     */
    open func layoutAnnotationViews(arStatus: ARStatus, layoutAll: Bool)
    {
        for annotationView in self.annotationViews
        {
            guard layoutAll || annotationView.superview != nil else { continue }
            
            let x = self.xPositionForAnnotationView(annotationView, arStatus: arStatus)
            let y = self.yPositionForAnnotationView(annotationView, arStatus: arStatus)
            
            annotationView.frame = CGRect(x: x, y: y + annotationView.arStackOffset.y, width: annotationView.bounds.size.width, height: annotationView.bounds.size.height)
        }
    }

    /**
     Simplified formula:
     x = center_of_screen(in px) + (annotation_heading(in degrees) - device_heading(in degrees)) * pixelsPerDegree
    */
    open func xPositionForAnnotationView(_ annotationView: ARAnnotationView, arStatus: ARStatus) -> CGFloat
    {
        guard let annotation = annotationView.annotation else { return 0}
        let heading = arStatus.heading
        let hPixelsPerDegree = CGFloat(arStatus.hPixelsPerDegree)
        let centerX = self.bounds.size.width * 0.5
        let delta = CGFloat(deltaAngle(annotation.azimuth, heading))
        let x = centerX - (annotationView.bounds.size.width * annotationView.centerOffset.x) + delta * hPixelsPerDegree
        return x
    }
    
    /**
     Simplified formula:
     y = center_of_screen(in px) + device_pitch(in degrees) * pixelsPerDegree + distance_offset(px)
    */
    open func yPositionForAnnotationView(_ annotationView: ARAnnotationView, arStatus: ARStatus) -> CGFloat
    {
        guard let annotation = annotationView.annotation else { return 0}
        let pitch = arStatus.pitch
        let vPixelsPerDegree = arStatus.vPixelsPerDegree
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
        
        // Offset by pitch of device
        let pitchOffset = pitch * vPixelsPerDegree
        
        // y
        let y = bottomY - (annotationView.bounds.size.height * annotationView.centerOffset.y) + CGFloat(distanceOffset) + CGFloat(pitchOffset)
        return y
    }
    
    open func adjustVerticalOffsetParameters()
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











