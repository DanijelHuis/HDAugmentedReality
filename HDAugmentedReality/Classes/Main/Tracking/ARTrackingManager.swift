//
//  ARTrackingManager.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 22/04/15.
//  Copyright (c) 2015 Danijel Huis. All rights reserved.
//

import UIKit
import CoreMotion
import CoreLocation
import simd

protocol ARTrackingManagerDelegate : NSObjectProtocol
{
    func arTrackingManager(_ trackingManager: ARTrackingManager, didUpdateUserLocation location: CLLocation)
    func arTrackingManager(_ trackingManager: ARTrackingManager, didUpdateReloadLocation location: CLLocation)
    func arTrackingManager(_ trackingManager: ARTrackingManager, didFailToFindLocationAfter elapsedSeconds: TimeInterval)
    func logText(_ text: String)
}

/**
 Class used internally by ARViewController for tracking and filtering location/heading/pitch etc.
 ARViewController takes all these informations and stores them in ARViewController.arStatus object,
 which is then passed to ARPresenter. Not intended for subclassing.
 */
public class ARTrackingManager: NSObject, CLLocationManagerDelegate
{    
    /**
     Specifies how often are new annotations fetched and annotation views are recreated.
     Default value is 50m.
     */
    public var reloadDistanceFilter: CLLocationDistance!
    
    /**
     Specifies how often are distances and azimuths recalculated for visible annotations. Stacking is also done on this which is heavy operation.
     Default value is 15m.
     */
    public var userDistanceFilter: CLLocationDistance!
    {
        didSet
        {
            self.locationManager.distanceFilter = self.userDistanceFilter
        }
    }
    
    //===== Internal variables
    /// Delegate
    internal weak var delegate: ARTrackingManagerDelegate?
    fileprivate(set) internal var locationManager: CLLocationManager = CLLocationManager()
    /// Tracking state.
    fileprivate(set) internal var tracking = false
    /// Last detected user location
    fileprivate(set) internal var userLocation: CLLocation?
    /// Heading. This is set when calculateHeading is called.
    fileprivate(set) internal var heading: Double = 0
    /// Pitch. This is set when calculatePitch is called.
    fileprivate(set) internal var pitch: Double = 0
    internal var isDebugging = false

    /// Return value for locationManagerShouldDisplayHeadingCalibration.
    public var allowCompassCalibration: Bool = false
    /// Locations with greater horizontalAccuracy than this will be disregarded. In meters.
    public var minimumLocationHorizontalAccuracy: Double = 500
    /// Locations older than this will be disregarded. In seconds.
    public var minimumLocationAge: Double = 30
    
    //===== Private variables
    fileprivate var motionManager: CMMotionManager = CMMotionManager()
    fileprivate var reloadLocationPrevious: CLLocation?
    fileprivate var reportLocationTimer: Timer?
    fileprivate var reportLocationDate: TimeInterval?
    fileprivate var locationSearchTimer: Timer? = nil
    fileprivate var locationSearchStartTime: TimeInterval? = nil
    fileprivate var orientation: CLDeviceOrientation = CLDeviceOrientation.portrait
    {
        didSet
        {
            self.locationManager.headingOrientation = self.orientation
        }
    }

    override init()
    {
        super.init()
        self.initialize()
    }
    
    deinit
    {
        self.stopTracking()
        NotificationCenter.default.removeObserver(self)
    }
    
    fileprivate func initialize()
    {
        // Defaults
        self.reloadDistanceFilter = 50
        self.userDistanceFilter = 15
        
        // Setup location manager
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.distanceFilter = CLLocationDistance(self.userDistanceFilter)
        self.locationManager.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(ARTrackingManager.deviceOrientationDidChange), name: UIDevice.orientationDidChangeNotification, object: nil)
        self.deviceOrientationDidChange()
    }
    
    @objc internal func deviceOrientationDidChange()
    {
        if let deviceOrientation = CLDeviceOrientation(rawValue: Int32(UIDevice.current.orientation.rawValue))
        {
            if deviceOrientation == .landscapeLeft || deviceOrientation == .landscapeRight || deviceOrientation == .portrait || deviceOrientation == .portraitUpsideDown
            {
                self.orientation = deviceOrientation
            }
        }
    }
    
    //==========================================================================================================================================================
    // MARK:                                                        Tracking
    //==========================================================================================================================================================
    
    /**
     Starts location and motion manager
     
     - Parameter notifyFailure:     If true, will call arTrackingManager:didFailToFindLocationAfter: if location is not found.
     */
    public func startTracking(notifyLocationFailure: Bool = false)
    {
        self.resetAllTrackingData()

        // Request authorization if state is not determined
        if CLLocationManager.locationServicesEnabled()
        {
            if CLLocationManager.authorizationStatus() == CLAuthorizationStatus.notDetermined
            {
                self.locationManager.requestWhenInUseAuthorization()
            }
        }
        
        // Location search. Used for finding first location, so if location cannot be found, app can throw alert or something.
        if notifyLocationFailure
        {
            self.startLocationSearchTimer()
            
            // Calling delegate with value 0 to be flexible, for example user might want to show indicator when search is starting.
            self.delegate?.arTrackingManager(self, didFailToFindLocationAfter: 0)
        }
        
        // Start motion and location managers
        self.motionManager.startDeviceMotionUpdates(using: CMAttitudeReferenceFrame.xTrueNorthZVertical)
        self.locationManager.startUpdatingLocation()
        self.tracking = true
    }
    
    /// Stops location and motion manager
    public func stopTracking()
    {
        self.resetAllTrackingData()
        
        // Stop motion and location managers
        self.motionManager.stopDeviceMotionUpdates()
        self.locationManager.stopUpdatingLocation()
        self.tracking = false
    }
    
    /// Stops all timers and resets all data.
    public func resetAllTrackingData()
    {
        self.stopLocationSearchTimer()
        self.locationSearchStartTime = nil

        self.stopReportLocationTimer()
        self.reportLocationDate = nil
        //self.reloadLocationPrevious = nil // Leave it, bcs of reload

        self.userLocation = nil
        self.heading = 0
        self.pitch = 0
    }
    
    //==========================================================================================================================================================
    // MARK:                                                        CLLocationManagerDelegate
    //==========================================================================================================================================================
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation])
    {
        guard !self.isDebugging else { return }
        guard let location = locations.first else { return }
        
        //===== Disregarding old and low quality location detections
        let age = location.timestamp.timeIntervalSinceNow;
        if age < -self.minimumLocationAge || location.horizontalAccuracy > self.minimumLocationHorizontalAccuracy || location.horizontalAccuracy < 0
        {
            print("Disregarding location: age: \(age), ha: \(location.horizontalAccuracy)")
            return
        }
        // Location found, stop timer that is responsible for measuring how long location is not found.
        self.stopLocationSearchTimer()

        //===== Set current user location
        self.userLocation = location
        //self.userLocation = CLLocation(coordinate: location.coordinate, altitude: 95, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: Date())
        if self.reloadLocationPrevious == nil { self.reloadLocationPrevious = self.userLocation }
        
        //@DEBUG
        /*if let location = self.userLocation
        {
            print("== \(location.horizontalAccuracy), \(age) \(location.coordinate.latitude), \(location.coordinate.longitude), \(location.altitude)" )
        }*/
        
        //===== Reporting location 5s after we get location, this will filter multiple locations calls and make only one delegate call
        let reportIsScheduled = self.reportLocationTimer != nil
        
        // First time, reporting immediately
        if self.reportLocationDate == nil
        {
            self.reportLocationToDelegate()
        }
        // Report is already scheduled, doing nothing, it will report last location delivered in max 5s
        else if reportIsScheduled
        {
            
        }
        // Scheduling report in 5s
        else
        {
            self.startReportLocationTimer()
        }
    }
    
    public func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool
    {
        return self.allowCompassCalibration
    }
    
    internal func stopReportLocationTimer()
    {
        self.reportLocationTimer?.invalidate()
        self.reportLocationTimer = nil
    }
    
    internal func startReportLocationTimer()
    {
        self.stopReportLocationTimer()
        self.reportLocationTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(ARTrackingManager.reportLocationToDelegate), userInfo: nil, repeats: false)
    }
    
    @objc internal func reportLocationToDelegate()
    {
        self.stopReportLocationTimer()
        self.reportLocationDate = Date().timeIntervalSince1970
        
        guard let userLocation = self.userLocation, let reloadLocationPrevious = self.reloadLocationPrevious else { return }
        guard let reloadDistanceFilter = self.reloadDistanceFilter else { return }
        
        if reloadLocationPrevious.distance(from: userLocation) > reloadDistanceFilter
        {
            self.reloadLocationPrevious = userLocation
            self.delegate?.arTrackingManager(self, didUpdateReloadLocation: userLocation)
        }
        else
        {
            self.delegate?.arTrackingManager(self, didUpdateUserLocation: userLocation)
        }
    }
    
    //==========================================================================================================================================================
    // MARK:                                                        Pitch and heading calculations
    //==========================================================================================================================================================
    internal func calculatePitch()
    {
        guard !self.isDebugging else { return }
        guard let gravity = self.motionManager.deviceMotion?.gravity else { return }
        let deviceOrientation = self.orientation
        
        self.pitch = self.calculatePitch(gravity: simd_double3(gravity), deviceOrientation: deviceOrientation)
    }
    
    /// Pitch. -90(looking down), 0(looking straight), 90(looking up)
    internal func calculatePitch(gravity: simd_double3, deviceOrientation: CLDeviceOrientation) -> Double
    {
        // Calculate pitch
        var pitch: Double = 0
        if deviceOrientation == CLDeviceOrientation.portrait { pitch = atan2(gravity.y, gravity.z) }
        else if deviceOrientation == CLDeviceOrientation.portraitUpsideDown { pitch = atan2(-gravity.y, gravity.z) }
        else if deviceOrientation == CLDeviceOrientation.landscapeLeft { pitch = atan2(gravity.x, gravity.z) }
        else if deviceOrientation == CLDeviceOrientation.landscapeRight { pitch = atan2(-gravity.x, gravity.z) }
        
        // Set pitch angle so that it suits us (0 = looking straight)
        pitch = pitch.toDegrees
        pitch += 90
        // Not really needed but, if pointing device down it will return 0...-30...-60...270...240 but like this it returns 0...-30...-60...-90...-120
        if(pitch > 180) { pitch -= 360 }

        return pitch
    }
    
    internal func calculateHeading()
    {
        guard !self.isDebugging else { return }
        guard let gravity = self.motionManager.deviceMotion?.gravity else { return }
        guard let attitude = self.motionManager.deviceMotion?.attitude.quaternion else { return }
        let deviceOrientation = self.orientation

        self.heading = self.calculateHeading(attitude: simd_quatd(attitude), gravity: simd_double3(gravity), deviceOrientation: deviceOrientation)
    }
    
    /**
     Calculates heading from attitude and gravity.
     This is used because deviceMotion.heading doesn't work when pitch > 135.
     Same effect can be observerd in Compass app: Start with iphone lying on the ground with screen pointing toward the sky (pitch = 0), now rotate iphone around its x axis (axes link below). Once you
     rotate more than 135 degrees, heading will jump.
     
     iphone axes: https://developer.apple.com/documentation/coremotion/getting_processed_device-motion_data/understanding_reference_frames_and_device_attitude
     */
    internal func calculateHeading(attitude: simd_quatd, gravity: simd_double3, deviceOrientation: CLDeviceOrientation) -> Double
    {
        /**
         1) Determine device's local up and right vector when in reference position (not rotated).
         */
        var upVector: simd_double3
        var rightVector: simd_double3
        if deviceOrientation == .portraitUpsideDown { upVector = simd_double3(0,-1,0); rightVector = simd_double3(-1,0,0); }
        else if deviceOrientation == .landscapeLeft{ upVector = simd_double3(1,0,0); rightVector = simd_double3(0,-1,0); }
        else if deviceOrientation == .landscapeRight { upVector = simd_double3(-1,0,0); rightVector = simd_double3(0,1,0); }
        else { upVector = simd_double3(0,1,0); rightVector = simd_double3(1,0,0); }
        
        /**
         2) Calculate device's local up vector when device is rotated. To calculate it, take device's local up vector in reference position and rotate it by device's attitude.
         Do the same with right vector.
         */
        let deviceUpVector = attitude.act(upVector)
        let deviceRightVector = attitude.act(rightVector)
        
        /**
         3) Now rotate device's local up vector by -pitch around devices's local right vector. In other words - rotate device's local up vector to reference xy plane.
         Note: Pitch has to be 0 when device is lying flat on the ground with screen towards the sky. Pitch changes 0...360 as you rotate it around x axis (right hand rule).
         */
        let pitch = self.pitch + 90
        let rotationToHorizontalPlane = simd_quatd(angle: -pitch.toRadians, axis: deviceRightVector)
        var deviceDirectionHorizontalVector = rotationToHorizontalPlane.act(deviceUpVector)
        
        /**
         4) Calculate heading from deviceDirectionHorizontalVector.
         */
        var heading = atan2(deviceDirectionHorizontalVector.y, deviceDirectionHorizontalVector.x).toDegrees
        heading = 360 - normalizeDegree(heading)
        
        return heading
    }

    //==========================================================================================================================================================
    // MARK:                                                    Utility
    //==========================================================================================================================================================
    /**
     Calculates bearing between userLocation and location.
     */
    internal func bearingFromUserToLocation(userLocation: CLLocation, location: CLLocation, approximate: Bool = false) -> Double
    {
        var bearing: Double = 0
        
        if approximate
        {
            bearing = self.approximateBearingBetween(startLocation: userLocation, endLocation: location)
        }
        else
        {
            bearing = self.bearingBetween(startLocation: userLocation, endLocation: location)
        }
        
        return bearing;
    }
    
    /**
     Precise bearing between two points.
    */
    internal func bearingBetween(startLocation : CLLocation, endLocation : CLLocation) -> Double
    {
        var bearing: Double = 0
        
        let lat1 = startLocation.coordinate.latitude.toRadians
        let lon1 = startLocation.coordinate.longitude.toRadians
        
        let lat2 = endLocation.coordinate.latitude.toRadians
        let lon2 = endLocation.coordinate.longitude.toRadians
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)
        bearing = radiansBearing.toDegrees
        if(bearing < 0) { bearing += 360 }
        
        return bearing
    }
    
    /**
     Approximate bearing between two points, good for small distances(<10km). 
     This is 30% faster than bearingBetween but it is not as precise. Error is about 1 degree on 10km, 5 degrees on 300km, depends on location...
     
     It uses formula for flat surface and multiplies it with LAT_LON_FACTOR which "simulates" earth curvature.
    */
    internal func approximateBearingBetween(startLocation: CLLocation, endLocation: CLLocation) -> Double
    {
        var bearing: Double = 0
        
        let startCoordinate: CLLocationCoordinate2D = startLocation.coordinate
        let endCoordinate: CLLocationCoordinate2D = endLocation.coordinate
        
        let latitudeDistance: Double = startCoordinate.latitude - endCoordinate.latitude;
        let longitudeDistance: Double = startCoordinate.longitude - endCoordinate.longitude;
        
        bearing = (atan2(longitudeDistance, (latitudeDistance * Double(LAT_LON_FACTOR)))).toDegrees
        bearing += 180.0
        
        return bearing
    }
    
    //==========================================================================================================================================================
    // MARK:                                                        Location search
    //==========================================================================================================================================================
    
    internal func startLocationSearchTimer(resetStartTime: Bool = true)
    {
        self.stopLocationSearchTimer()
        
        if resetStartTime
        {
            self.locationSearchStartTime = Date().timeIntervalSince1970
        }
        self.locationSearchTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(ARTrackingManager.locationSearchTimerTick), userInfo: nil, repeats: false)
    }
    
    internal func stopLocationSearchTimer(resetStartTime: Bool = true)
    {
        self.locationSearchTimer?.invalidate()
        self.locationSearchTimer = nil
    }
    
    @objc internal func locationSearchTimerTick()
    {
        guard let locationSearchStartTime = self.locationSearchStartTime else { return }
        let elapsedSeconds = Date().timeIntervalSince1970 - locationSearchStartTime
        
        self.startLocationSearchTimer(resetStartTime: false)
        self.delegate?.arTrackingManager(self, didFailToFindLocationAfter: elapsedSeconds)
    }
}
