//
//  ARPresenter+Stacking.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 13/04/2017.
//  Copyright © 2017 Danijel Huis. All rights reserved.
//

import Foundation
import UIKit

/**
 Responsible for transform/layout of annotations, usually after they have been layouted by ARPresenter. 
 e.g. stacking.
 
 ARPresenterTransform can change arPositionOffset of annotations, or set transform.

 */
public protocol ARPresenterTransform: class
{
    /// ARresenter, it is set when setting presenterTransform on presenter.
    var arPresenter: ARPresenter! { set get }

    func preLayout(arStatus: ARStatus, reloadType: ARViewController.ReloadType, needsRelayout: Bool)
    func postLayout(arStatus: ARStatus, reloadType: ARViewController.ReloadType, needsRelayout: Bool)

}

open class ARPresenterStackTransform: ARPresenterTransform
{
    open var arPresenter: ARPresenter!
    
    public init() {}
    
    public func preLayout(arStatus: ARStatus, reloadType: ARViewController.ReloadType, needsRelayout: Bool)
    {
        
    }
    
    public func postLayout(arStatus: ARStatus, reloadType: ARViewController.ReloadType, needsRelayout: Bool)
    {
        if needsRelayout
        {
            self.stackAnnotationViews()
        }
    }
    
    
    /**
     Stacks annotationViews vertically if they are overlapping. This works by comparing frames of annotationViews.
     
     This must be called if parameters that affect relative x,y of annotations changed.
     - if azimuths on annotations are calculated(This can change relative horizontal positions of annotations)
     - when adjustVerticalOffsetParameters is called because that can affect relative vertical positions of annotations
     
     Pitch/heading of the device doesn't affect relative positions of annotationViews.
     */
    open func stackAnnotationViews()
    {
        guard self.arPresenter.annotationViews.count > 0 else { return }
        guard let arStatus = self.arPresenter.arViewController?.arStatus else { return }
        
        // Sorting makes stacking faster
        let sortedAnnotationViews = self.arPresenter.annotationViews.sorted(by: { $0.frame.origin.y > $1.frame.origin.y })
        let centerX = self.arPresenter.bounds.size.width * 0.5
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
                annotationView1.arAlternateFrame = annotationView1.frame
                annotationView1.arAlternateFrame.origin.x = annotationView1.frame.origin.x - totalWidth
                hasAlternateFrame = true
            }
            else if left < (leftBorder + annotationView1.frame.size.width)
            {
                annotationView1.arAlternateFrame = annotationView1.frame
                annotationView1.arAlternateFrame.origin.x = annotationView1.frame.origin.x + totalWidth
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
                    annotationView1.arAlternateFrame.origin.y = annotationView1.frame.origin.y
                    hasCollision = true
                }
                else if hasAlternateFrame && annotationView1.arAlternateFrame.intersects(annotationView2.frame)
                {
                    annotationView1.frame.origin.y = annotationView2.frame.origin.y - annotationView1.frame.size.height - 5
                    annotationView1.arAlternateFrame.origin.y = annotationView1.frame.origin.y
                    hasCollision = true
                }
                
                i = i + 1
            }
            annotationView1.arPositionOffset.y = annotationView1.frame.origin.y - y;
        }
    }
    
}
