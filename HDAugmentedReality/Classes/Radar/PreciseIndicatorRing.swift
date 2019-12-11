//
//  PreciseIndicatorRing.swift
//  HDAugmentedReality
//
//  Created by Danijel Huis on 04/12/2019.
//

import UIKit
import MapKit
import SceneKit

/// When annotations on radar are out of visible area, indicators are shown in a ring around radar.
/// Each annotation on radar has its own indicator.
/// Used on RadarMapView. Very heavy battery drain if annotation count is big (>200).
open class PreciseIndicatorRing: UIView, IndicatorRingProtocol
{
    /// Indicator size
    open var indicatorSize: CGFloat = 8
    /// Default color for annotatons. This is used only if ARAnnotation doesn't implement RadarAnnotation protocol (radarAnnotationTintColor).
    open var indicatorColor = UIColor(displayP3Red: 5/255, green: 123/255, blue: 255/255, alpha: 1.0)
    /// Default color for user annotation.
    open var userIndicatorColor: UIColor = .white
    private var indicatorViewsDictionary: [ARAnnotation : UIView] = [:]

    open func update(mapView: MKMapView, userAnnotation: ARAnnotation?)
    {
        let mapRadius = Double(mapView.frame.size.width) / 2
        let mapCenter = simd_double2(x: mapRadius, y: mapRadius)

        var newIndicatorViewsDictionary: [ARAnnotation : UIView] = [:]
        let allViews = Set(self.subviews)
        var usedViews: Set<UIView> = Set()
        let indicatorSize = self.indicatorSize
        
        for annotation in mapView.annotations
        {
            guard let arAnnotation = annotation as? ARAnnotation else { continue }
            let isUserAnnotation = arAnnotation === userAnnotation
            let existingIndicatorView = self.indicatorViewsDictionary[arAnnotation]
            if let existingIndicatorView = existingIndicatorView { newIndicatorViewsDictionary[arAnnotation] = existingIndicatorView  }
            
            // Calculate point on circumference
            let annotationCenterCGPoint = mapView.convert(annotation.coordinate, toPointTo: mapView)
            let annotationCenter = simd_double2(x: Double(annotationCenterCGPoint.x) , y: Double(annotationCenterCGPoint.y))
            let centerToAnnotationVector = annotationCenter - mapCenter
            let pointOnCircumference = mapCenter + simd_normalize(centerToAnnotationVector) * (mapRadius + 1.5)
            if simd_length(centerToAnnotationVector) < mapRadius { continue } // It is not added to usedViews so it will be removed from superView

            // Create indicator view if not reusing old view.
            let indicatorView: UIView
            if let existingIndicatorView = existingIndicatorView { indicatorView = existingIndicatorView }
            else
            {
                let newIndicatorView = UIView()
                let radarAnnotation = annotation as? RadarAnnotation
                if isUserAnnotation { newIndicatorView.backgroundColor = self.userIndicatorColor }
                else
                {
                    newIndicatorView.backgroundColor = radarAnnotation?.radarAnnotationTintColor ?? self.indicatorColor
                }
                    
                // x,y not important her, it is set after.
                newIndicatorView.frame = CGRect(x: 0, y: 0, width: indicatorSize, height: indicatorSize)
                newIndicatorView.layer.cornerRadius = indicatorSize * 0.5
                newIndicatorViewsDictionary[arAnnotation] = newIndicatorView
                indicatorView = newIndicatorView
            }
            
            indicatorView.center = self.convert(CGPoint(x: pointOnCircumference.x, y: pointOnCircumference.y), from: mapView)
            self.insertSubview(indicatorView, at: 0)
            if isUserAnnotation { self.bringSubviewToFront(indicatorView) }
            
            usedViews.insert(indicatorView)
        }
        
        // Remove all views that are not used
        let unusedViews = allViews.subtracting(usedViews)
        for view in unusedViews { view.removeFromSuperview() }
        
        // Update newIndicatorViewsDictionary (also removes unused items)
        self.indicatorViewsDictionary = newIndicatorViewsDictionary
    }
}
