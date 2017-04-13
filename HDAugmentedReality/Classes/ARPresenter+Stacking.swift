//
//  ARPresenter+Stacking.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 13/04/2017.
//  Copyright © 2017 Danijel Huis. All rights reserved.
//

import Foundation
import UIKit

extension ARPresenter
{
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
