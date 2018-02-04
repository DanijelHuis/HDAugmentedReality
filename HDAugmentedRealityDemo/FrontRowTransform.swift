//
//  TestARPresenter.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 13/04/2017.
//  Copyright © 2017 Danijel Huis. All rights reserved.
//

import UIKit
import HDAugmentedReality

class FrontRowTransform: ARPresenterTransform
{
    open var arPresenter: ARPresenter!
    
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
            let y = annotationView1.frame.origin.y;
            var i = 0
            annotationView1.alpha = 1.0
            while i < sortedAnnotationViews.count
            {
                let annotationView2 = sortedAnnotationViews[i]
                if annotationView1 == annotationView2
                {
                    break
                }
                
                let collision = annotationView2.alpha == 1.0 &&
                    (annotationView1.frame.intersects(annotationView2.frame) ||
                        (hasAlternateFrame && annotationView1.arAlternateFrame.intersects(annotationView2.frame)))
                
                if collision
                {
                    annotationView1.alpha = 0.1
                }
                
                i = i + 1
            }
            annotationView1.arPositionOffset.y = annotationView1.frame.origin.y - y;
        }
    }
}
