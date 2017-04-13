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
 ARPresenter handles creation and layout of annotation views.
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

    
    
    fileprivate weak var arViewController: ARViewController!
    fileprivate var annotations: [ARAnnotation] = []
    fileprivate var activeAnnotations: [ARAnnotation] = []
    fileprivate var annotationViews: [ARAnnotationView] = []
    
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
    fileprivate func activeAnnotationsFromAnnotations(annotations: [ARAnnotation]) -> [ARAnnotation]
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
    fileprivate func createAnnotationViews()
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
    func addRemoveAnnotationViews(arStatus: ARStatus)
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
    fileprivate func xPositionForAnnotationView(_ annotationView: ARAnnotationView, arStatus: ARStatus) -> CGFloat
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
    fileprivate func yPositionForAnnotationView(_ annotationView: ARAnnotationView, arStatus: ARStatus) -> CGFloat
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
    
    fileprivate func adjustVerticalOffsetParameters()
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
    
    //==========================================================================================================================================================
    // MARK:                                                               Stacking
    //==========================================================================================================================================================
    
    /**
     Stacks annotationViews vertically if they are overlapping. This works by comparing frames of annotationViews.
     
     This must be called if parameters that affect relative x,y of annotations changed.
     - if azimuths on annotations are calculated(This can change relative horizontal positions of annotations)
     - when adjustVerticalOffsetParameters is called because that can affect relative vertical positions of annotations
     
     Pitch/heading of the device doesn't affect relative positions of annotationViews.
    */
    open func stackAnnotationViews()
    {
        guard self.annotationViews.count > 0 else { return }
        guard let arStatus = self.arViewController?.arStatus else { return }

        // Sorting makes stacking faster
        let sortedAnnotationViews = self.annotationViews.sorted(by: { $0.frame.origin.y > $1.frame.origin.y })
        let centerX = self.bounds.size.width * 0.5
        let totalWidth = CGFloat( arStatus.hPixelsPerDegree * 360 )
        let rightBorder = centerX + totalWidth / 2
        let leftBorder = centerX - totalWidth / 2
        
        // This is simple brute-force comparing of frames, compares annotationView1 to all annotationsViews beneath(before) it, if overlap is found,
        // annotationView1 is moved above it. This is done until annotationView1 is not overlapped by any other annotationView beneath it. Then it moves to
        // the next annotationView.
        for annotationView1 in sortedAnnotationViews
        {
            //===== Alternate frame
            // Annotation views are positioned left(0° - -180°) and right(0° - 180°) from the center of the screen. So if annotationView1
            // is on -180°, its x position is ~ -6000px, and if annoationView2 is on 180°, its x position is ~ 6000px. These two annotationViews
            // are basically on the same position (180° = -180°) but simply by comparing frames -6000px != 6000px we cannot know that.
            // So we are construcing alternate frame so that these near-border annotations can "see" each other.
            var hasAlternateFrame = false
            let left = annotationView1.frame.origin.x;
            let right = left + annotationView1.frame.size.width
            // Assuming that annotationViews have same width
            if right > (rightBorder - annotationView1.frame.size.width)
            {
                annotationView1.arStackAlternateFrame = annotationView1.frame
                annotationView1.arStackAlternateFrame.origin.x = annotationView1.frame.origin.x - totalWidth
                hasAlternateFrame = true
            }
            else if left < (leftBorder + annotationView1.frame.size.width)
            {
                annotationView1.arStackAlternateFrame = annotationView1.frame
                annotationView1.arStackAlternateFrame.origin.x = annotationView1.frame.origin.x + totalWidth
                hasAlternateFrame = true
            }
            
            //====== Detecting collision
            var hasCollision = false
            let y = annotationView1.frame.origin.y;
            var i = 0
            while i < sortedAnnotationViews.count
            {
                let annotationView2 = sortedAnnotationViews[i]
                if annotationView1 == annotationView2
                {
                    // If collision, start over because movement could cause additional collisions
                    if hasCollision
                    {
                        hasCollision = false
                        i = 0
                        continue
                    }
                    break
                }
                
                let collision = annotationView1.frame.intersects(annotationView2.frame)
                
                if collision
                {
                    annotationView1.frame.origin.y = annotationView2.frame.origin.y - annotationView1.frame.size.height - 5
                    annotationView1.arStackAlternateFrame.origin.y = annotationView1.frame.origin.y
                    hasCollision = true
                }
                else if hasAlternateFrame && annotationView1.arStackAlternateFrame.intersects(annotationView2.frame)
                {
                    annotationView1.frame.origin.y = annotationView2.frame.origin.y - annotationView1.frame.size.height - 5
                    annotationView1.arStackAlternateFrame.origin.y = annotationView1.frame.origin.y
                    hasCollision = true
                }
                
                i = i + 1
            }
            annotationView1.arStackOffset.y = annotationView1.frame.origin.y - y;
        }
    }
    
    /**
     Resets temporary stacking fields. This must be called before stacking and before layout.
    */
    open func resetStackParameters()
    {
        for annotationView in self.annotationViews
        {
            annotationView.arStackOffset = CGPoint.zero
            annotationView.arStackAlternateFrame = CGRect.zero
        }
    }
}











