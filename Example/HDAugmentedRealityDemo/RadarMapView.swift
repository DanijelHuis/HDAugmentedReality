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
/**
 
 Problems with MKMapView
 - setting anything on MKMapCamera will cancel current map annimation, e.g. setting heading will cause map to jump to location instead of smoothly animate.
 - setting heading everytime it changes will disable user interaction with map and cancel all animations.
 
 */
open class RadarMapView: UIView, ARAccessory, MKMapViewDelegate
{
    //===== Public
    open var userTrackingMode: UserTrackingMode = .nativeRotatingMap { didSet { self.reloadUserTrackingMode() } }
    @IBOutlet weak open var mapView: MKMapView!
    override open var bounds: CGRect { didSet { self.layoutUi() } }
    @IBOutlet weak private var headingIndicatorView: UIImageView!
    
    //===== Private
    private var userLocationFound: Bool = false
    private var firstTime: Bool = true
    private var didLoadUi = false
    
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

    public func reload(reloadType: ARViewController.ReloadType, status: ARStatus)
    {
        guard self.didLoadUi, self.userTrackingMode == .exactRotatingMap || self.userTrackingMode == .exactStationaryMap || (self.userTrackingMode == .nativeRotatingMap && self.userLocationFound) else { return }
        guard let location = status.userLocation else { return }
        //===== Set first location and zoom
        if self.firstTime, [.exactRotatingMap, .exactStationaryMap].contains(self.userTrackingMode)
        {
            self.firstTime = false
            
            let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude), span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005))
            self.mapView.setRegion(self.mapView.regionThatFits(region), animated: false)
            return
        }

        if self.userTrackingMode == .exactRotatingMap
        {
            self.mapView.camera.centerCoordinate = location.coordinate
            self.mapView.camera.heading = status.heading
        }
        else if self.userTrackingMode == .exactStationaryMap
        {
            self.mapView.setCenter(location.coordinate, animated: true)
            self.headingIndicatorView.transform = CGAffineTransform.identity.rotated(by: CGFloat(status.heading.toRadians))
        }
    }
    
    //==========================================================================================================================================================
    // MARK:                                                       UI
    //==========================================================================================================================================================
    func loadUi()
    {
        self.backgroundColor = .darkGray
        self.clipsToBounds = true
                
        self.headingIndicatorView.layer.anchorPoint = CGPoint(x: 0.5, y: 1)

        // Other
        self.didLoadUi = true
        self.reloadUserTrackingMode()
    }
    
    func bindUi()
    {
        
    }
    
    func styleUi()
    {
        
    }
    
    func layoutUi()
    {
        self.layer.cornerRadius = self.bounds.size.width / 2.0
    }
    
    private var isChanginUserTrackingMode = false
    func reloadUserTrackingMode()
    {
        guard self.didLoadUi else { return }
        
        self.isChanginUserTrackingMode = true
        if self.userTrackingMode == .nativeRotatingMap && self.mapView.userTrackingMode != .followWithHeading
        {
            self.mapView.userTrackingMode = .followWithHeading
        }
        else if self.userTrackingMode == .exactRotatingMap && self.mapView.userTrackingMode != .none
        {
            self.mapView.userTrackingMode = .none
        }
        self.isChanginUserTrackingMode = false
    }
    
    //==========================================================================================================================================================
    // MARK:                                                    MKMapViewDelegate
    //==========================================================================================================================================================
    public func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation)
    {
        self.userLocationFound = true

        /*
         Setting self.mapView.userTrackingMode inside reloadUserTrackingMode() can call this method so we gotta make sure we don't end up in a loop.
         
         We gotta set mapView.userTrackingMode after location is found (Apple's bug?), and location is only found if mapView.userTrackingMode != .none so we gotta
         set it before and after...something is very wrong with this...
        */
        if !self.isChanginUserTrackingMode
        {
            DispatchQueue.main.asyncAfter(deadline:.now() + 0.1)
            {
                self.reloadUserTrackingMode()
            }
        }
    }
    
    //==========================================================================================================================================================
    // MARK:                                                    Other
    //==========================================================================================================================================================
    @IBInspectable var userTrackingModeIB: Int
    {
        get { return self.userTrackingMode.rawValue }
        set
        {
            if self.userTrackingMode.rawValue != newValue
            {
                self.userTrackingMode = UserTrackingMode(rawValue: newValue) ?? .nativeRotatingMap
            }
        }
    }
    
    public enum UserTrackingMode: Int, Equatable
    {
        case nativeRotatingMap = 0
        case exactRotatingMap = 1
        case exactStationaryMap = 2
    }
    
    
}


