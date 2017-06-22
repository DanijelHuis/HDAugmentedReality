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
import GLKit


@objc protocol ARTrackingManagerDelegate : NSObjectProtocol
{
    @objc optional func arTrackingManager(_ trackingManager: ARTrackingManager, didUpdateUserLocation location: CLLocation)
    @objc optional func arTrackingManager(_ trackingManager: ARTrackingManager, didUpdateReloadLocation location: CLLocation)
    @objc optional func arTrackingManager(_ trackingManager: ARTrackingManager, didFailToFindLocationAfter elapsedSeconds: TimeInterval)
    
    @objc optional func logText(_ text: String)
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
    public var reloadDistanceFilter: CLLocationDistance!    // Will be set in init
    
    /**
     Specifies how often are distances and azimuths recalculated for visible annotations. Stacking is also done on this which is heavy operation.
     Default value is 15m.
     */
    public var userDistanceFilter: CLLocationDistance!      // Will be set in init
    {
        didSet
        {
            self.locationManager.distanceFilter = self.userDistanceFilter
        }
    }
    
    /**
     Filter(Smoothing) factor for heading in range 0-1. It affects horizontal movement of annotaion views. The lower the value the bigger the smoothing.
     Value of 1 means no smoothing, should be greater than 0. Default value is 0.05
     */
    public var headingFilterFactor: Double = 0.05
    private var _headingFilterFactor: Double = 0.05
    
    
    /**
     Filter(Smoothing) factor for pitch in range 0-1. It affects vertical movement of annotaion views. The lower the value the bigger the smoothing.
     Value of 1 means no smoothing, should be greater than 0. Default value is 0.05
     */
    public var pitchFilterFactor: Double = 0.05
    
    //===== Internal variables
    /// Delegate
    internal weak var delegate: ARTrackingManagerDelegate?
    fileprivate(set) internal var locationManager: CLLocationManager = CLLocationManager()
    /// Tracking state.
    fileprivate(set) internal var tracking = false
    /// Last detected user location
    fileprivate(set) internal var userLocation: CLLocation?
    /// Set automatically when heading changes. Also see filteredHeading.
    fileprivate(set) internal var heading: Double = 0
    /// Set in filterHeading. filterHeading must be called manually and often(display timer) bcs of filtering function.
    fileprivate(set) internal var filteredHeading: Double = 0
    /// Set in filterPitch. filterPitch must be called manually and often(display timer) bcs of filtering function.
    fileprivate(set) internal var filteredPitch: Double = 0
    /// If set, userLocation will return this value
    internal var debugLocation: CLLocation?
    /// If set, filteredHeading will return this value
    internal var debugHeading: Double?
    /// If set, filteredPitch will return this value
    internal var debugPitch: Double?
    
    /// Headings with greater headingAccuracy than this will be disregarded. In Degrees.
    public var minimumHeadingAccuracy: Double = 120
    /// Return value for locationManagerShouldDisplayHeadingCalibration.
    public var allowCompassCalibration: Bool = false
    /// Locations with greater horizontalAccuracy than this will be disregarded. In meters.
    public var minimumLocationHorizontalAccuracy: Double = 500
    /// Locations older than this will be disregarded. In seconds.
    public var minimumLocationAge: Double = 30
    
    //===== Private variables
    fileprivate var motionManager: CMMotionManager = CMMotionManager()
    fileprivate var previousAcceleration: CMAcceleration = CMAcceleration(x: 0, y: 0, z: 0)
    fileprivate var reloadLocationPrevious: CLLocation?
    fileprivate var reportLocationTimer: Timer?
    fileprivate var reportLocationDate: TimeInterval?
    fileprivate var locationSearchTimer: Timer? = nil
    fileprivate var locationSearchStartTime: TimeInterval? = nil
    fileprivate var catchupPitch = false;
    fileprivate var headingStartDate: Date?
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
        self.locationManager.headingFilter = 1
        self.locationManager.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(ARTrackingManager.deviceOrientationDidChange), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
        self.deviceOrientationDidChange()
    }
    
    internal func deviceOrientationDidChange()
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
        
        // Location search
        if notifyLocationFailure
        {
            self.startLocationSearchTimer()
            
            // Calling delegate with value 0 to be flexible, for example user might want to show indicator when search is starting.
            self.delegate?.arTrackingManager?(self, didFailToFindLocationAfter: 0)
        }
        
        // Debug
        if let debugLocation = self.debugLocation
        {
            self.userLocation = debugLocation
        }
        
        // Start motion and location managers
        self.motionManager.startAccelerometerUpdates()
        self.locationManager.startUpdatingHeading()
        self.locationManager.startUpdatingLocation()
        self.tracking = true
    }
    
    /// Stops location and motion manager
    public func stopTracking()
    {
        self.resetAllTrackingData()
        
        // Stop motion and location managers
        self.motionManager.stopAccelerometerUpdates()
        self.locationManager.stopUpdatingHeading()
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

        self.previousAcceleration = CMAcceleration(x: 0, y: 0, z: 0)

        self.userLocation = nil
        self.heading = 0
        self.filteredHeading = 0
        self.filteredPitch = 0
        
        // This will make filteredPitch catchup current pitch value on next heading calculation
        self.catchupPitch = true
        self.headingStartDate = nil
    }
    
    //==========================================================================================================================================================
    // MARK:                                                        CLLocationManagerDelegate
    //==========================================================================================================================================================
    
    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading)
    {
        if newHeading.headingAccuracy < 0 || newHeading.headingAccuracy > self.minimumHeadingAccuracy
        {
            return
        }
        let previousHeading = self.heading
        
        // filteredHeading is not updated here bcs this is not called too often. filterHeading method should be called manually
        // with display timer.
        if newHeading.trueHeading < 0
        {
            self.heading = fmod(newHeading.magneticHeading, 360.0)
        }
        else
        {
            self.heading = fmod(newHeading.trueHeading, 360.0)
        }
        
        /** 
         Handling unprecise readings, this whole section should prevent annotations from spinning because of
         unprecise readings & filtering. e.g. if first reading is 10° and second is 80°, due to filtering, annotations
         would move slowly from 10°-80°. So when we detect such situtation, we set _headingFilterFactor to 1, meaning that
         filtering is temporarily disabled and annotatoions will immediately jump to new heading.
         
         This is done only first 5 seconds after first heading.
        */
        
        // First heading after tracking started. Catching up filteredHeading.
        if self.headingStartDate == nil
        {
            self.headingStartDate = Date()
            self.filteredHeading = self.heading
        }
        
        if let headingStartDate = self.headingStartDate // Always true
        {
            var recommendedHeadingFilterFactor = self.headingFilterFactor
            let headingFilteringStartTime: TimeInterval = 5
            
            // First 5 seconds after first heading?
            if headingStartDate.timeIntervalSinceNow > -headingFilteringStartTime
            {
                // Disabling filtering if heading difference(current and previous) is > 10
                if fabs(deltaAngle(self.heading, previousHeading)) > 10
                {
                    recommendedHeadingFilterFactor = 1  // We could also just set self.filteredHeading = self.heading
                }
            }
            
            _headingFilterFactor = recommendedHeadingFilterFactor
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation])
    {
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
        
        if debugLocation != nil { self.userLocation = debugLocation }
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
    
    internal func reportLocationToDelegate()
    {
        self.stopReportLocationTimer()
        self.reportLocationDate = Date().timeIntervalSince1970
        
        guard let userLocation = self.userLocation, let reloadLocationPrevious = self.reloadLocationPrevious else { return }
        guard let reloadDistanceFilter = self.reloadDistanceFilter else { return }
        
        if reloadLocationPrevious.distance(from: userLocation) > reloadDistanceFilter
        {
            self.reloadLocationPrevious = userLocation
            self.delegate?.arTrackingManager?(self, didUpdateReloadLocation: userLocation)
        }
        else
        {
            self.delegate?.arTrackingManager?(self, didUpdateUserLocation: userLocation)
        }
    }
    
    //==========================================================================================================================================================
    // MARK:                                                        Calculations
    //==========================================================================================================================================================
    
    /// Returns filtered(low-pass) pitch in degrees. -90(looking down), 0(looking straight), 90(looking up)
    internal func filterPitch()
    {
        guard self.debugPitch == nil else { return }
        guard let accelerometerData = self.motionManager.accelerometerData else { return }
        let acceleration: CMAcceleration = accelerometerData.acceleration
        
        // First real reading after startTracking? Making filter catch up
        if self.catchupPitch && (acceleration.x != 0 || acceleration.y != 0 || acceleration.z != 0)
        {
            self.previousAcceleration = acceleration
            self.catchupPitch = false
        }
        
        // Low-pass filter - filtering data so it is not jumping around
        let pitchFilterFactor: Double = self.pitchFilterFactor
        self.previousAcceleration.x = (acceleration.x * pitchFilterFactor) + (self.previousAcceleration.x  * (1.0 - pitchFilterFactor));
        self.previousAcceleration.y = (acceleration.y * pitchFilterFactor) + (self.previousAcceleration.y  * (1.0 - pitchFilterFactor));
        self.previousAcceleration.z = (acceleration.z * pitchFilterFactor) + (self.previousAcceleration.z  * (1.0 - pitchFilterFactor));
        
        let deviceOrientation = self.orientation
        var angle: Double = 0
        
        if deviceOrientation == CLDeviceOrientation.portrait
        {
            angle = atan2(self.previousAcceleration.y, self.previousAcceleration.z)
        }
        else if deviceOrientation == CLDeviceOrientation.portraitUpsideDown
        {
            angle = atan2(-self.previousAcceleration.y, self.previousAcceleration.z)
        }
        else if deviceOrientation == CLDeviceOrientation.landscapeLeft
        {
            angle = atan2(self.previousAcceleration.x, self.previousAcceleration.z)
        }
        else if deviceOrientation == CLDeviceOrientation.landscapeRight
        {
            angle = atan2(-self.previousAcceleration.x, self.previousAcceleration.z)
        }
                
        angle = radiansToDegrees(angle)
        angle += 90
        // Not really needed but, if pointing device down it will return 0...-30...-60...270...240 but like this it returns 0...-30...-60...-90...-120
        if(angle > 180) { angle -= 360 }

        // Even more filtering, not sure if really needed //@TODO
        self.filteredPitch = (self.filteredPitch + angle) / 2.0
    }

    
    internal func filterHeading()
    {
        let headingFilterFactor = _headingFilterFactor
        let previousFilteredHeading = self.filteredHeading
        let newHeading = self.debugHeading ?? self.heading

        /*
         Low pass filter on heading cannot be done by using regular formula because our input(heading)
         is circular so we would have problems on heading passing North(0). Example:
         newHeading = 350
         previousHeading = 10
         headingFilterFactor = 0.5
         filteredHeading = 10 * 0.5 + 350 * 0.5 = 180 NOT OK - IT SHOULD BE 0
         
         First solution is to instead of passing 350 to the formula, we pass -10.
         Second solution is to not use 0-360 degrees but to express values with sine and cosine.
         */
        
        /*
         Second solution
         let newHeadingRad = degreesToRadians(newHeading)
         self.filteredHeadingSin = sin(newHeadingRad) * headingFilterFactor + self.filteredHeadingSin * (1 - headingFilterFactor)
         self.filteredHeadingCos = cos(newHeadingRad) * headingFilterFactor + self.filteredHeadingCos * (1 - headingFilterFactor)
         self.filteredHeading = radiansToDegrees(atan2(self.filteredHeadingSin, self.filteredHeadingCos))
         self.filteredHeading = normalizeDegree(self.filteredHeading)
         */
        
        var newHeadingTransformed = newHeading
        if fabs(newHeading - previousFilteredHeading) > 180
        {
            if previousFilteredHeading < 180 && newHeading > 180
            {
                newHeadingTransformed -= 360
            }
            else if previousFilteredHeading > 180 && newHeading < 180
            {
                newHeadingTransformed += 360
            }
        }
        self.filteredHeading = (newHeadingTransformed * headingFilterFactor) + (previousFilteredHeading  * (1.0 - headingFilterFactor))
        self.filteredHeading = normalizeDegree(self.filteredHeading)
    }

    //@TODO rename to heading
    internal func azimuthFromUserToLocation(userLocation: CLLocation, location: CLLocation, approximate: Bool = false) -> Double
    {
        var azimuth: Double = 0
        
        if approximate
        {
            azimuth = self.approximateBearingBetween(startLocation: userLocation, endLocation: location)
        }
        else
        {
            azimuth = self.bearingBetween(startLocation: userLocation, endLocation: location)
        }
        
        return azimuth;
    }
    
    /**
     Precise bearing between two points.
    */
    internal func bearingBetween(startLocation : CLLocation, endLocation : CLLocation) -> Double
    {
        var azimuth: Double = 0
        
        let lat1 = degreesToRadians(startLocation.coordinate.latitude)
        let lon1 = degreesToRadians(startLocation.coordinate.longitude)
        
        let lat2 = degreesToRadians(endLocation.coordinate.latitude)
        let lon2 = degreesToRadians(endLocation.coordinate.longitude)
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)
        azimuth = radiansToDegrees(radiansBearing)
        if(azimuth < 0) { azimuth += 360 }
        
        return azimuth
    }
    
    /**
     Approximate bearing between two points, good for small distances(<10km). 
     This is 30% faster than bearingBetween but it is not as precise. Error is about 1 degree on 10km, 5 degrees on 300km, depends on location...
     
     It uses formula for flat surface and multiplies it with LAT_LON_FACTOR which "simulates" earth curvature.
    */
    internal func approximateBearingBetween(startLocation: CLLocation, endLocation: CLLocation) -> Double
    {
        var azimuth: Double = 0
        
        let startCoordinate: CLLocationCoordinate2D = startLocation.coordinate
        let endCoordinate: CLLocationCoordinate2D = endLocation.coordinate
        
        let latitudeDistance: Double = startCoordinate.latitude - endCoordinate.latitude;
        let longitudeDistance: Double = startCoordinate.longitude - endCoordinate.longitude;
        
        azimuth = radiansToDegrees(atan2(longitudeDistance, (latitudeDistance * Double(LAT_LON_FACTOR))))
        azimuth += 180.0
        
        return azimuth
    }
    
    internal func startDebugMode(location: CLLocation? = nil, heading: Double? = nil, pitch: Double? = nil)
    {
        if let location = location
        {
            self.debugLocation = location
            self.userLocation = location
        }
        
        if let heading = heading
        {
            self.debugHeading = heading
            //self.filteredHeading = heading    // Don't, it is different for heading bcs we are also simulating low pass filter
        }
        
        if let pitch = pitch
        {
            self.debugPitch = pitch
            self.filteredPitch = pitch
        }
    }
    
    internal func stopDebugMode()
    {
        self.debugLocation = nil
        self.userLocation = nil
        self.debugHeading = nil
        self.debugPitch = nil
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
    
    internal func locationSearchTimerTick()
    {
        guard let locationSearchStartTime = self.locationSearchStartTime else { return }
        let elapsedSeconds = Date().timeIntervalSince1970 - locationSearchStartTime
        
        self.startLocationSearchTimer(resetStartTime: false)
        self.delegate?.arTrackingManager?(self, didFailToFindLocationAfter: elapsedSeconds)
    }
}
