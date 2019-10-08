//
//  RadarMapView.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 15/07/2019.
//  Copyright © 2019 Danijel Huis. All rights reserved.
//

import UIKit
import MapKit
import HDAugmentedReality
import SceneKit
/**
 
 Side note: Problems with MKMapView:
 - setting anything on MKMapCamera will cancel current map annimation, e.g. setting heading will cause map to jump to location instead of smoothly animate.
 - setting heading everytime it changes will disable user interaction with map and cancel all animations.
 */
open class RadarMapView: UIView, ARAccessory, MKMapViewDelegate
{
    public struct Configuration
    {
        public var indicatorSize: CGFloat = 8
        public var annotationImage = UIImage(named: "radarAnnotation")
        public var userAnnotationImage = UIImage(named: "userRadarAnnotation")
        public var userAnnotationAnchorPoint = CGPoint(x: 0.5, y: 0.860)
        public var indicatorImage = UIImage(named: "radarAnnotation")
        public var userIndicatorImage = UIImage(named: "userIndicator")
        public var radarSizeRatio: CGFloat = 1.75

    }
    
    //===== Public
    /// Defines map position and zoom at start.
    open var startMode: RadarStartMode = .centerUser(span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
    /// Defines map position and zoom when user location changes.
    open var trackingMode: RadarTrackingMode = .centerUserWhenNearBorder(span: nil)
    //open var trackingMode: RadarTrackingMode = .none

    open var configuration: Configuration = Configuration()
    
    
    //===== IB
    @IBOutlet weak private(set) public var mapViewContainer: UIView!
    @IBOutlet weak private(set) public var mapView: MKMapView!
    @IBOutlet weak private(set) public var indicatorContainerView: UIView!
    @IBOutlet weak private(set) public var resizeButton: UIButton!
    @IBOutlet weak private(set) public var zoomInButton: UIButton!
    @IBOutlet weak private(set) public var zoomOutButton: UIButton!

    
    //===== Private
    private var isFirstZoom = true
    private var isReadyToReload = false
    private var radarAnnotations: [ARAnnotation] = []
    private var userRadarAnnotation: ARAnnotation?
    private weak var userRadarAnnotationView: UserRadarAnnotationView?
    private var indicatorViewsDictionary: [ARAnnotation : UIImageView] = [:]
    override open var bounds: CGRect { didSet { self.layoutUi() } }

    //==========================================================================================================================================================
    // MARK:                                                       Init
    //==========================================================================================================================================================
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        self.addSubviewFromNib()
        self.loadUi()
        self.bindUi()
        self.styleUi()
        self.layoutUi()
    }
    
    required public init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        self.addSubviewFromNib()
    }
    
    override open func awakeFromNib()
    {
        super.awakeFromNib()
        self.loadUi()
        self.bindUi()
        self.styleUi()
        self.layoutUi()
    }
    
    //==========================================================================================================================================================
    // MARK:                                                       UI
    //==========================================================================================================================================================
    func loadUi()
    {
        // Other
        self.isReadyToReload = true
 }
    
    func bindUi()
    {
        self.bindResizeButton()
    }
    
    func styleUi()
    {
        self.backgroundColor = .clear
    }
    
    func layoutUi()
    {
        self.mapView.setNeedsLayout()
        self.mapView.layoutIfNeeded()
        self.mapView.layer.cornerRadius = self.mapView.bounds.size.width / 2.0
        
        self.indicatorContainerView.setNeedsLayout()
        self.indicatorContainerView.layoutIfNeeded()
        self.indicatorContainerView.layer.cornerRadius = self.indicatorContainerView.bounds.size.width / 2.0
        self.indicatorContainerView.clipsToBounds = true
    }

    //==========================================================================================================================================================
    // MARK:                                                    Reload
    //==========================================================================================================================================================
    public func reload(reloadType: ARViewController.ReloadType, status: ARStatus, presenter: ARPresenter)
    {
        guard self.isReadyToReload, let location = status.userLocation else { return }
        var didChangeAnnotations = false
        
        //===== Add/remove radar annotations
        if self.radarAnnotations.count != presenter.annotations.count || reloadType == .annotationsChanged
        {
            self.radarAnnotations = presenter.annotations
            // Remove everything except the user annotation
            self.mapView.removeAnnotations(self.mapView.annotations.filter { $0 !== self.userRadarAnnotation })
            self.mapView.addAnnotations(self.radarAnnotations)
            didChangeAnnotations = true
        }
        
        //===== Add/remove user map annotation
        if [.reloadLocationChanged, .userLocationChanged].contains(reloadType) || self.userRadarAnnotation == nil
        {
            // It doesn't work if we just update annotation's coordinate, we have to remove it and add again.
            if let userRadarAnnotation = self.userRadarAnnotation
            {
                self.mapView.removeAnnotation(userRadarAnnotation)
                self.userRadarAnnotation = nil
            }
            
            if let newUserRadarAnnotation = ARAnnotation(identifier: "userRadarAnnotation", title: nil, location: location)
            {
                self.mapView.addAnnotation(newUserRadarAnnotation)
                self.userRadarAnnotation = newUserRadarAnnotation
            }
            didChangeAnnotations = true
        }
        
        //===== Track user (map position and zoom)
        if self.isFirstZoom || [.reloadLocationChanged, .userLocationChanged].contains(reloadType)
        {
            let isFirstZoom = self.isFirstZoom
            self.isFirstZoom = false
            
            if isFirstZoom
            {
                if case .centerUser(let span) = self.startMode
                {
                    let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude), span: span)
                    self.mapView.setRegion(self.mapView.regionThatFits(region), animated: false)
                }
                else if case .fitAnnotations = self.startMode
                {
                    self.setRegionToAnntations(animated: false)
                }
            }
            else
            {
                if case .centerUserAlways(let trackingModeSpan) = self.trackingMode
                {
                    let span = trackingModeSpan ?? self.mapView.region.span
                    let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude), span: span)
                    self.mapView.setRegion(self.mapView.regionThatFits(region), animated: true)
                }
                else if case .centerUserWhenNearBorder(let trackingModeSpan) = self.trackingMode
                {
                    if self.isUserRadarAnnotationNearOrOverBorder
                    {
                        let span = trackingModeSpan ?? self.mapView.region.span
                        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude), span: span)
                        self.mapView.setRegion(self.mapView.regionThatFits(region), animated: true)
                    }
                }
            }
        }
        
        //===== Heading
        self.userRadarAnnotationView?.heading = status.heading
        
        //===== Indicators
        if didChangeAnnotations
        {
            self.updateIndicators()
        }
  }
    
    //==========================================================================================================================================================
    // MARK:                                                    MKMapViewDelegate
    //==========================================================================================================================================================
    public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView?
    {
        // User annotation
        if annotation === self.userRadarAnnotation
        {
            let reuseIdentifier = "userRadarAnnotation"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as! UserRadarAnnotationView?) ?? UserRadarAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
            view.annotation = annotation
            view.displayPriority = .required
            view.canShowCallout = false
            view.isSelected = true  // Keeps it above other annotations (hopefully)
            view.imageView?.image = self.configuration.userAnnotationImage
            view.imageView?.layer.anchorPoint = self.configuration.userAnnotationAnchorPoint
            self.userRadarAnnotationView = view

            return view
        }
        // Other annotations
        else
        {
            let reuseIdentifier = "radarAnnotation"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)) ?? MKAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
            view.annotation = annotation
            view.displayPriority = .required
            view.canShowCallout = false
            view.image = self.configuration.annotationImage
            return view
        }
    }
    
    public func mapViewDidChangeVisibleRegion(_ mapView: MKMapView)
    {
        self.updateIndicators()
    }
    
    //==========================================================================================================================================================
    // MARK:                                                    Indicators
    //==========================================================================================================================================================
    
    /**
     Updates indicators position.
     */
    private func updateIndicators()
    {
         let mapRadius = Double(self.mapView.frame.size.width) / 2
         let mapCenter = simd_double2(x: mapRadius, y: mapRadius)

        var newIndicatorViewsDictionary: [ARAnnotation : UIImageView] = [:]
        let allViews = Set(self.indicatorContainerView.subviews)
        var usedViews: Set<UIView> = Set()
        let indicatorSize = self.configuration.indicatorSize
        
        for annotation in self.mapView.annotations
        {
            guard let arAnnotation = annotation as? ARAnnotation else { continue }
            let isUserAnnotation = arAnnotation === self.userRadarAnnotation
            let existingIndicatorView = self.indicatorViewsDictionary[arAnnotation]
            if let existingIndicatorView = existingIndicatorView { newIndicatorViewsDictionary[arAnnotation] = existingIndicatorView  }
            
            // Calculate point on circumference
            let annotationCenterCGPoint = self.mapView.convert(annotation.coordinate, toPointTo: self.mapView)
            let annotationCenter = simd_double2(x: Double(annotationCenterCGPoint.x) , y: Double(annotationCenterCGPoint.y))
            let centerToAnnotationVector = annotationCenter - mapCenter
            let pointOnCircumference = mapCenter + simd_normalize(centerToAnnotationVector) * (mapRadius + 1.5)
            if simd_length(centerToAnnotationVector) < mapRadius { continue }

            // Create indicator view if not reusing old view.
            let indicatorView: UIImageView
            if let existingIndicatorView = existingIndicatorView { indicatorView = existingIndicatorView }
            else
            {
                let newIndicatorView = UIImageView()
                newIndicatorView.image = isUserAnnotation ? self.configuration.userIndicatorImage : self.configuration.indicatorImage
                // x,y not important her, it is set after.
                newIndicatorView.frame = CGRect(x: self.frame.size.width / 2 - indicatorSize / 2, y: self.frame.size.height / 2 - indicatorSize / 2, width: indicatorSize, height: indicatorSize)
                newIndicatorViewsDictionary[arAnnotation] = newIndicatorView
                indicatorView = newIndicatorView
            }
            
            indicatorView.center = self.indicatorContainerView.convert(CGPoint(x: pointOnCircumference.x, y: pointOnCircumference.y), from: self.mapView)
            self.indicatorContainerView.insertSubview(indicatorView, at: 0)
            if isUserAnnotation { self.indicatorContainerView.bringSubviewToFront(indicatorView) }
            
            usedViews.insert(indicatorView)
        }
        
        // Remove all views that are not used
        let unusedViews = allViews.subtracting(usedViews)
        for view in unusedViews { view.removeFromSuperview() }
        
        // Update newIndicatorViewsDictionary (also removes unused items)
        self.indicatorViewsDictionary = newIndicatorViewsDictionary
    }
    
    /**
     Returns true if user annotation is near or over border of the map.
     */
    private var isUserRadarAnnotationNearOrOverBorder: Bool
    {
        let mapRadius = Double(self.mapView.frame.size.width) / 2
        guard let annotation = self.userRadarAnnotation, mapRadius > 30 else { return false }

        let threshold = mapRadius * 0.4
        let mapCenter = simd_double2(x: mapRadius, y: mapRadius)
        let annotationCenterCGPoint = self.mapView.convert(annotation.coordinate, toPointTo: self.mapView)
        let annotationCenter = simd_double2(x: Double(annotationCenterCGPoint.x) , y: Double(annotationCenterCGPoint.y))
        let centerToAnnotationVector = annotationCenter - mapCenter
        
        if simd_length(centerToAnnotationVector) > (mapRadius - threshold)
        {
            return true
        }
        
        return false
    }
    
    //==========================================================================================================================================================
    // MARK:                                                    Utility
    //==========================================================================================================================================================
   
    /**
     Zooms map by given factor.
     */
    private func zoomMap(by factor: Double, animated: Bool)
    {
        var region: MKCoordinateRegion = self.mapView.region
        var span: MKCoordinateSpan = self.mapView.region.span
        span.latitudeDelta *= factor
        span.longitudeDelta *= factor
        region.span = span
        self.mapView.setRegion(region, animated: animated)
    }
    
    /**
     Zooms map to fit all annotations (considering rounded map).
     */
    private func setRegionToAnntations(animated: Bool)
    {
        var zoomRect = MKMapRect.null
        let edgePadding = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)    // Maybe make ratio of map size?
        for annotation in self.mapView.annotations
        {
            let annotationPoint = MKMapPoint(annotation.coordinate)
            let annotationRect = MKMapRect(x: annotationPoint.x, y: annotationPoint.y, width: 0.1, height: 0.1)
            zoomRect = zoomRect.union(annotationRect)
        }
        
        if zoomRect.width > 0 || zoomRect.height > 0 { self.mapView.setVisibleMapRect(zoomRect, edgePadding: edgePadding, animated: animated) }
    }
    
    private var isResized: Bool = false
    private var heightBeforeResizing: CGFloat?
    private func resizeRadar()
    {
        if self.heightBeforeResizing == nil { self.heightBeforeResizing = self.frame.size.height }
        guard let heightConstraint = self.findConstraint(attribute: .height), let heightBeforeResizing = self.heightBeforeResizing else { return }
        self.isResized = !self.isResized
        
        heightConstraint.constant = self.isResized ? heightBeforeResizing * self.configuration.radarSizeRatio : heightBeforeResizing

        UIView.animate(withDuration: 1/3, animations:
        {
            self.superview?.layoutIfNeeded()
            self.bindResizeButton()
            self.updateIndicators()
        })
        {
            (finished) in
        }
    }
    
    private func bindResizeButton()
    {
        self.resizeButton.isSelected = self.isResized
    }

    
    //==========================================================================================================================================================
    // MARK:                                                    User interaction
    //==========================================================================================================================================================
    @IBAction func sizeButtonTapped(_ sender: Any)
    {
        self.resizeRadar()
    }
    
    @IBAction func zoomInButtonTapped(_ sender: Any)
    {
        self.zoomMap(by: 75/100, animated: false)
    }
    
    @IBAction func zoomOutButtonTapped(_ sender: Any)
    {
        self.zoomMap(by: 100/75, animated: false)
    }
}

//==========================================================================================================================================================
// MARK:                                                    Helper classes
//==========================================================================================================================================================

open class UserRadarAnnotationView: MKAnnotationView
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
        self.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

        self.imageView?.removeFromSuperview()
        let imageView = UIImageView()
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

public enum RadarStartMode
{
    case centerUser(span: MKCoordinateSpan)
    case fitAnnotations
}

public enum RadarTrackingMode
{
    case none
    case centerUserAlways(span: MKCoordinateSpan?)
    case centerUserWhenNearBorder(span: MKCoordinateSpan?)
}
