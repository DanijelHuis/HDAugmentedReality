//
//  RadarMapView.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 15/07/2019.
//  Copyright © 2019 Danijel Huis. All rights reserved.
//
import UIKit
import MapKit
import SceneKit

/**
 RadarMapView consists of:
    - MKMapView showing annotations
    - ring around map that shows out of bounds annotations (indicators)
    - zoom in/out and shrink/expand buttons
 
 RadarMapView gets annotations and all other data via ARAccessory delegate. Intended to be used with ARViewController.
 
 Usage:
    - RadarMapView must have height constraint in order to resize/shrink properly (.
    - use startMode and trackingMode properties to adjust how map zoom/tracking behaves on start and later on.
    - use configuration property to customize.
 
 Internal note: Problems with MKMapView:
 - setting anything on MKMapCamera will cancel current map annimation, e.g. setting heading will cause map to jump to location instead of smoothly animate.
 - setting heading everytime it changes will disable user interaction with map and cancel all animations.
 */
open class RadarMapView: UIView, ARAccessory, MKMapViewDelegate
{
    public struct Configuration
    {
        /// Image for annotations that are shown on the map
        public var annotationImage = UIImage(named: "radarAnnotation", in: Bundle(for: RadarMapView.self), compatibleWith: nil)?.withRenderingMode(.alwaysTemplate)
        /// Image for user annotation that is shown on the map
        public var userAnnotationImage = UIImage(named: "radarUserAnnotation", in: Bundle(for: RadarMapView.self), compatibleWith: nil)
        /// Use it to set anchor point for your userAnnotationImage. This is where you center is on the image, in default image its on 201st pixel, image height is 240.
        public var userAnnotationAnchorPoint = CGPoint(x: 0.5, y: 201/240)
        /// Determines how much RadarMapView expands.
        public var radarSizeRatio: CGFloat = 1.75
        /// If true, resize button will be placed in top right corner which resizes whole radar.
        public var isResizeEnabled = true
        /// If true, +/- buttons are placed in lower right cornert which control map zoom level.
        public var isZoomEnabled = true
    }
    
    //===== Public
    /// Defines map position and zoom at start.
    open var startMode: RadarStartMode = .centerUser(span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
    /// Defines map position and zoom when user location changes.
    open var trackingMode: RadarTrackingMode = .centerUserWhenNearBorder(span: nil)
    /// Use it to configure and customize your radar. Must be done before RadarMapView is added to superview.
    open var configuration: Configuration = Configuration()
    /// If set it will show only annotations that are closer than given value (in meters).
    open var maxDistance: Double?
    /// Read MKAnnotationView.canShowCallout.
    open var annotationsCanShowCallout = false
    /// Radar ring type.
    open var indicatorRingType: IndicatorRingType = .none { didSet { self.updateIndicatorRingType() } }
    
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
    private weak var userRadarAnnotationView: RadarAnnotationView?
    override open var bounds: CGRect { didSet { self.layoutUi() } }
    private var allRadarAnnotationsCount: Int = 0
    
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
    
        self.resizeButton.isHidden = !self.configuration.isResizeEnabled
        self.zoomInButton.isHidden = !self.configuration.isZoomEnabled
        self.zoomOutButton.isHidden = !self.configuration.isZoomEnabled
    }
    
    override open func didMoveToSuperview()
    {
        super.didMoveToSuperview()
        if self.superview != nil { self.layoutUi() }
    }
    
    /// Can be called to reload some configuration properties.
    open func reload()
    {
        self.layoutUi()
    }

    //==========================================================================================================================================================
    // MARK:                                                    Reload
    //==========================================================================================================================================================
    /// This is called from ARPresenter
    open func reload(reloadType: ARViewController.ReloadType, status: ARStatus, presenter: ARPresenter)
    {
        guard self.isReadyToReload, let location = status.userLocation else { return }
        var didChangeAnnotations = false
        
        //===== Add/remove radar annotations if annotations changed
        if reloadType == .annotationsChanged || self.allRadarAnnotationsCount != presenter.annotations.count || (reloadType == .reloadLocationChanged && self.maxDistance != nil)
        {
            self.allRadarAnnotationsCount = presenter.annotations.count
            if let maxDistance = self.maxDistance { self.radarAnnotations = presenter.annotations.filter { $0.distanceFromUser <= maxDistance } }
            else { self.radarAnnotations = presenter.annotations }
            
            // Remove everything except the user annotation
            self.mapView.removeAnnotations(self.mapView.annotations.filter { $0 !== self.userRadarAnnotation })
            self.mapView.addAnnotations(self.radarAnnotations)
            didChangeAnnotations = true
        }
        
        //===== Add/remove user map annotation when user location changes
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
                    let region = MKCoordinateRegion(center: location.coordinate, span: span)
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
                    let region = MKCoordinateRegion(center: location.coordinate, span: span)
                    self.mapView.setRegion(self.mapView.regionThatFits(region), animated: true)
                }
                else if case .centerUserWhenNearBorder(let trackingModeSpan) = self.trackingMode
                {
                    if self.isUserRadarAnnotationNearOrOverBorder
                    {
                        let span = trackingModeSpan ?? self.mapView.region.span
                        let region = MKCoordinateRegion(center: location.coordinate, span: span)
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
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as! RadarAnnotationView?) ?? RadarAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
            view.annotation = annotation
            if #available(iOS 11.0, *)
            {
                view.displayPriority = .required
            }
            view.canShowCallout = false
            view.isSelected = true  // Keeps it above other annotations (hopefully)
            view.imageView?.image = self.configuration.userAnnotationImage
            view.imageView?.layer.anchorPoint = self.configuration.userAnnotationAnchorPoint
            view.frame.size = self.configuration.userAnnotationImage?.size ?? CGSize(width: 100, height: 100)
            self.userRadarAnnotationView = view

            return view
        }
        // Other annotations
        else
        {
            let reuseIdentifier = "radarAnnotation"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as! RadarAnnotationView?) ?? RadarAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
            view.annotation = annotation
            if #available(iOS 11.0, *)
            {
                view.displayPriority = .required
            }
            view.canShowCallout = self.annotationsCanShowCallout
            
            let radarAnnotation = annotation as? RadarAnnotation
            view.imageView?.image = radarAnnotation?.radarAnnotationImage ?? self.configuration.annotationImage
            view.imageView?.tintColor = radarAnnotation?.radarAnnotationTintColor ?? nil
            view.frame.size = CGSize(width: 9, height: 9)
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
    private var lastTimeInterval: TimeInterval = Date().timeIntervalSince1970
    private var indicatorsRefreshInterval: Double = 1/25
    private(set) open var indicatorRing: IndicatorRingProtocol?

    private func updateIndicatorRingType()
    {
        self.indicatorRing?.removeFromSuperview()
        self.indicatorRing = nil
        var indicatorRing: IndicatorRingProtocol?
        
        switch self.indicatorRingType
        {
        case .none:
            break
        case .segmented(let segmentColor, let userSegmentColor):
            let segmentedIndicatorRing = SegmentedIndicatorRing(frame: .zero)
            if let segmentColor = segmentColor { segmentedIndicatorRing.segmentColor = segmentColor.cgColor }
            if let userSegmentColor = userSegmentColor { segmentedIndicatorRing.userSegmentColor = userSegmentColor.cgColor }
            indicatorRing = segmentedIndicatorRing
        case .precise(let indicatorColor, let userIndicatorColor):
            let preciseIndicatorRing = PreciseIndicatorRing(frame: .zero)
            if let userIndicatorColor = userIndicatorColor { preciseIndicatorRing.userIndicatorColor = userIndicatorColor }
            if let indicatorColor = indicatorColor { preciseIndicatorRing.indicatorColor = indicatorColor }
            indicatorRing = preciseIndicatorRing
            break
        case .custom(let customIndicatorRing):
            indicatorRing = customIndicatorRing
        }
        
        if let indicatorRing = indicatorRing
        {
            indicatorRing.translatesAutoresizingMaskIntoConstraints = false
            self.indicatorContainerView.addSubview(indicatorRing)
            indicatorRing.pinToSuperview(leading: 0, trailing: 0, top: 0, bottom: 0, width: nil, height: nil)
            self.indicatorRing = indicatorRing
        }
    }
    
    /**
     Updates indicators position.
     */
    private func updateIndicators()
    {
        let currentTimeInterval = Date().timeIntervalSince1970
        if abs(self.lastTimeInterval - currentTimeInterval) < self.indicatorsRefreshInterval
        {
            return;
        }
        
        self.indicatorRing?.update(mapView: self.mapView, userAnnotation: self.userRadarAnnotation)
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
        
        return simd_length(centerToAnnotationVector) > (mapRadius - threshold)
    }
    
    //==========================================================================================================================================================
    // MARK:                                                    Utility
    //==========================================================================================================================================================
   
    /**
     Zooms map by given factor.
     */
    open func zoomMap(by factor: Double, animated: Bool)
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
    open func setRegionToAnntations(animated: Bool)
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
        guard let heightConstraint = self.findConstraint(attribute: .height), let heightBeforeResizing = self.heightBeforeResizing else
        {
            print("Cannot resize, RadarMapView must have height constraint.")
            return
        }
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
            
            self.mapView.setNeedsLayout()   // Needed because of legal label.
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

