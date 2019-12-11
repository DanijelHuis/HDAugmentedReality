//
//  CGView.swift
//  CoreGraphicsDemo
//
//  Created by Danijel Huis on 14/11/2019.
//  Copyright © 2019 Danijel Huis. All rights reserved.
//

import UIKit
import MapKit
import SceneKit

/// When annotations on radar are out of visible area, segments around map indicate direction where annotations are.
open class SegmentedIndicatorRing: UIView, IndicatorRingProtocol
{
    /// Number of segments. If you change it on the fly, call resetSegments.
    public let segmentCount: Int = 24
    /// Arc line width
    public var lineWidth: CGFloat = 3
    /// Arc color
    public var segmentColor = UIColor.white.cgColor
    /// Color for segment that points to user
    public var userSegmentColor = UIColor(displayP3Red: 5/255, green: 123/255, blue: 255/255, alpha: 1.0).cgColor
    /// Empty space between arc segments
    public var segmentDistance: Double = 0.5
    private(set) open var segments: [RingSegment] = []
    override open var bounds: CGRect { didSet { self.loadSegments(animate: true) } }

    /// Creates and updates segments (arcs).
    open func loadSegments(animate: Bool)
    {
        let parentLayer = self.layer
        let width = parentLayer.frame.size.width
        let height = parentLayer.frame.size.height
        let radius = min(width, height) / 2
        let segmentAngleRange = Double(360) / Double(self.segmentCount)
        
        for segmentIndex in 0..<self.segmentCount
        {
            let startAngle = Int(Double(segmentIndex) * segmentAngleRange)
            let endAngle = Int(Double(startAngle) + Double(segmentAngleRange))
            let arc = UIBezierPath(arcCenter: CGPoint(x:width/2, y:height/2), radius: CGFloat(radius - self.lineWidth/2), startAngle: CGFloat((Double(startAngle) + self.segmentDistance).toRadians), endAngle: CGFloat((Double(endAngle) - self.segmentDistance).toRadians), clockwise: true)
            let segment = segmentIndex < self.segments.count ? self.segments[segmentIndex] : nil
            let layer: CAShapeLayer
            
            if let segment = segment { layer = segment.layer }
            else
            {
                layer = CAShapeLayer()
                parentLayer.addSublayer(layer)
                layer.strokeColor = self.segmentColor
                layer.lineWidth = self.lineWidth
                layer.fillColor = UIColor.clear.cgColor
                
                let segment = RingSegment(angleRange: startAngle...endAngle, layer: layer)
                self.segments.append(segment)
            }
            
            layer.frame = CGRect(x: 0, y: 0, width: width, height: height)
            if animate
            {
                let animation = CABasicAnimation(keyPath: "path")
                animation.duration = 1/3
                animation.fromValue = layer.path
                animation.toValue = arc.cgPath
                animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName(rawValue: "easeInEaseOut"))
                layer.add(animation, forKey: "path")
            }
            layer.path = arc.cgPath
        }
    }
    
    /// Changes opacity of segments according to annotations.
    open func update(mapView: MKMapView, userAnnotation: ARAnnotation?)
    {
        let mapRadius = Double(mapView.frame.size.width) / 2
        let mapCenter = simd_double2(x: mapRadius, y: mapRadius)
        let anglesPerSegment = Double(360) / Double(self.segmentCount)

        // Set default values
        for segment in self.segments
        {
            segment.isActive = false
            segment.isUser = false
        }
        
        // Set opacity and color
        for annotation in mapView.annotations
        {
            //===== Opacity
            let annotationCenterCGPoint = mapView.convert(annotation.coordinate, toPointTo: mapView)
            let annotationCenter = simd_double2(x: Double(annotationCenterCGPoint.x) , y: Double(annotationCenterCGPoint.y))
            let centerToAnnotationVector = annotationCenter - mapCenter
            if simd_length(centerToAnnotationVector) < mapRadius { continue }
            let angle = ARMath.normalizeDegree(atan2(centerToAnnotationVector.y, centerToAnnotationVector.x).toDegrees)
            
            let segmentIndex = Int(angle / anglesPerSegment)
            if segmentIndex >= 0 && segmentIndex < self.segments.count
            {
                let segment = self.segments[segmentIndex]
                segment.isActive = true
                if annotation === userAnnotation { segment.isUser = true }
            }
        }
        
        // Doing it like this because every change of some layer property will actually init new layer, so we try to reduce changing layer properies (setting same value doesn't make it reinit).
        for segment in self.segments
        {
            if segment.isActive
            {
                if segment.isUser
                {
                    CATransaction.begin()
                    CATransaction.setValue(true, forKey: kCATransactionDisableActions)
                }
                
                segment.layer.opacity = 1.0
                if segment.isUser { segment.layer.strokeColor = self.userSegmentColor }
                else { segment.layer.strokeColor = self.segmentColor }
                
                if segment.isUser
                {
                    CATransaction.commit()
                }
            }
            else
            {
                segment.layer.opacity = 0.1
                segment.layer.strokeColor = self.segmentColor
            }
        }

    }
    
    /// Removes all segments and their layers. Usefell if you change segmentCount on the fly.
    open func resetSegments()
    {
        self.segments.removeAll()
    }
    
    /// Helper class for keeping segments data.
    open class RingSegment
    {
        open var angleRange: ClosedRange<Int>
        open var layer: CAShapeLayer
        open var isActive: Bool = false
        open var isUser: Bool = false

        public init(angleRange: ClosedRange<Int>, layer: CAShapeLayer)
        {
            self.angleRange = angleRange
            self.layer = layer
        }
        
        deinit
        {
            self.layer.removeFromSuperlayer()
        }
    }
}







