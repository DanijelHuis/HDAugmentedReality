//
//  RadarAnnotation.swift
//  HDAugmentedReality
//
//  Created by Danijel Huis on 30/10/2019.
//

import UIKit
import MapKit

//==========================================================================================================================================================
// MARK:                                                    RadarAnnotation
//==========================================================================================================================================================
/// Can be implemented by your ARAnnotation subclass to provide per-annotation customization.
public protocol RadarAnnotation
{
    /// Defines color of annotation on the map and color of annotation on precise ring indicator (if used).
    var radarAnnotationTintColor: UIColor? { get }
    /// Defines image for annotation on the map.
    var radarAnnotationImage: UIImage? { get }
}

public extension RadarAnnotation
{
    var radarAnnotationTintColor: UIColor? { return nil }
    var radarAnnotationImage: UIImage? { return nil }
}

//==========================================================================================================================================================
// MARK:                                                    RadarAnnotationView
//==========================================================================================================================================================

/// Custom MKAnnotationView.
open class RadarAnnotationView: MKAnnotationView
{
    open var imageView: UIImageView?
    open var heading: Double = 0 { didSet { self.layoutUi() } }
    
    public override init(annotation: MKAnnotation?, reuseIdentifier: String?)
    {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        self.loadUi()
    }
    
    required public init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    open func loadUi()
    {
        self.frame = CGRect(x: 0, y: 0, width: 100, height: 100) // Doesn't matter, it is set in RadarMapView.

        self.imageView?.removeFromSuperview()
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(imageView)
        imageView.pinToSuperview(leading: 0, trailing: 0, top: 0, bottom: 0, width: nil, height: nil)
        self.imageView = imageView
    }
    
    open func layoutUi()
    {
        self.imageView?.transform = CGAffineTransform.identity.rotated(by: CGFloat(self.heading.toRadians))
    }
}

//==========================================================================================================================================================
// MARK:                                                    Enums
//==========================================================================================================================================================
public enum RadarStartMode
{
    /// Centers on user
    case centerUser(span: MKCoordinateSpan)
    /// Fits annotations
    case fitAnnotations
}

public enum RadarTrackingMode
{
    case none
    /// Centers on user whenever location change is detected. Use span if you want to force zoom/span level.
    case centerUserAlways(span: MKCoordinateSpan?)
    /// Centers on user when its annotation comes near map border. Use span if you want to force zoom/span level.
    case centerUserWhenNearBorder(span: MKCoordinateSpan?)
}

/// Used by indicator rings on RadarMapView.
public protocol IndicatorRingProtocol: UIView
{
    func update(mapView: MKMapView, userAnnotation: ARAnnotation?)
}

public enum IndicatorRingType
{
    case none
    /// Shows 24 segmentes which light up when annotations are out of map bounds. Uses SegmentedIndicatorRing.
    /// If segmentColor and userSegmentColor, default ones will be used.
    case segmented(segmentColor: UIColor?, userSegmentColor: UIColor?)
    /// Shows all out of bounds annotations.
    /// WARNING: DRAINS BATTERY VERY QUICKLY WHEN THERE ARE MANY ANNOTATIONS (>200).
    case precise(indicatorColor: UIColor?, userIndicatorColor: UIColor?)
    /// Allows you to provide custom indicator ring.
    case custom(indicatorRing: IndicatorRingProtocol)
}

//==========================================================================================================================================================
// MARK:                                                    MKMapView
//==========================================================================================================================================================

/**
 MKMapView subclass that moves legal label to center (horizontally).
 */
class LegalMapView: MKMapView
{
    private var isLayoutingLegalLabel = false
    override func layoutSubviews()
    {
        super.layoutSubviews()
        guard !self.isLayoutingLegalLabel else { return }   // To prevent layout loops.
        
        self.isLayoutingLegalLabel = true
        for subview in self.subviews
        {
            if "\(type(of: subview))" == "MKAttributionLabel"   //MKAttributionLabel, _MKMapContentView
            {
                subview.layer.cornerRadius = subview.frame.size.height * 0.5
                subview.center.x = self.frame.size.width / 2
            }
        }
        self.isLayoutingLegalLabel = false
    }
}
