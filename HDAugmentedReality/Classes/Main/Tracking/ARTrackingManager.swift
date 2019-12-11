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
    public var reloadDistanceFilter: CLLocationDistance = 50
    
    /**
     Specifies how often are distances and azimuths recalculated for visible annotations. Stacking is also done on this which is heavy operation.
     Default value is 10m.
     */
    public var userDistanceFilter: CLLocationDistance = 10 { didSet { self.locationManager.distanceFilter = self.userDistanceFilter } }
    
    /// Headings with greater headingAccuracy than this will be disregarded. Used only when headingSource = .coreLocation. In Degrees.
    public var minimumHeadingAccuracy: Double = 120
    /// Return value for locationManagerShouldDisplayHeadingCalibration. Doesn't seem to be used anymore.
    public var allowCompassCalibration: Bool = true
    /// Locations with greater horizontalAccuracy than this will be disregarded. In meters.
    public var minimumLocationHorizontalAccuracy: Double = 500
    /// Locations older than this will be disregarded. In seconds.
    public var minimumLocationAge: Double = 30
    /**
     Source of heading. Read carefully HeadingSource comments. .deviceMotion is smoother but it has problems when device is moving fast. coreLocation works well in all situations.
     */
    public var headingSource: HeadingSource = .coreLocation
    /**
     Filter(Smoothing) factor for heading and pitch in range 0-1. It affects horizontal and vertical movement of annotaion views. The lower the value the bigger the smoothing.
     */
    public var filterFactor: Double? = 0.4
    
    /// Minimum time between location updates, don't go lower than 1 sec. Default is 2 sec.
    public var minimumTimeBetweenLocationUpdates: TimeInterval = 2

    //===== Internal variables
    /// Delegate
    internal weak var delegate: ARTrackingManagerDelegate?
    fileprivate(set) internal var locationManager: CLLocationManager = CLLocationManager()
    /// Tracking state.
    fileprivate(set) internal var tracking = false
    /// Last detected user location
    fileprivate(set) internal var userLocation: CLLocation?
    /// Heading. This is set when calculateHeading is called.
    fileprivate(set) internal var heading: Double?
    /// Pitch. This is set when calculatePitch is called.
    fileprivate(set) internal var pitch: Double?
    
    //===== Private variables
    internal var motionManager: CMMotionManager = CMMotionManager()
    fileprivate var reloadLocationPrevious: CLLocation?
    fileprivate var reportLocationTimer: Timer?
    fileprivate var reportLocationDate: TimeInterval?
    fileprivate var locationSearchTimer: Timer? = nil
    fileprivate var locationSearchStartTime: TimeInterval? = nil
    internal var clHeading: Double?
    fileprivate var headingStartDate: Date?
    fileprivate var orientation: CLDeviceOrientation = CLDeviceOrientation.portrait { didSet { self.locationManager.headingOrientation = self.orientation } }

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
        // Setup location manager
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.distanceFilter = CLLocationDistance(self.userDistanceFilter)
        self.locationManager.headingFilter = 0.1
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

        // Request authorization if state is not determined, no need to wait for result.
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
        self.motionManager.showsDeviceMovementDisplay = self.allowCompassCalibration
        self.motionManager.startDeviceMotionUpdates(using: CMAttitudeReferenceFrame.xMagneticNorthZVertical)
        self.locationManager.startUpdatingLocation()
        if self.headingSource == .coreLocation { self.locationManager.startUpdatingHeading() }
        self.tracking = true
    }
    
    /// Stops location and motion manager
    public func stopTracking()
    {
        self.resetAllTrackingData()
        
        // Stop motion and location managers
        self.motionManager.stopDeviceMotionUpdates()
        self.locationManager.stopUpdatingLocation()
        self.locationManager.stopUpdatingHeading()
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
        self.heading = nil
        self.pitch = nil
        self.clHeading = nil
        self.headingStartDate = nil
        self.previousRawPitch = nil
        self.previousRawHeading = nil
    }
    
    //==========================================================================================================================================================
    // MARK:                                                        CLLocationManagerDelegate
    //==========================================================================================================================================================
    
    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading)
    {
        self.setClHeading(newHeading: newHeading)
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
        if self.reloadLocationPrevious == nil { self.reloadLocationPrevious = self.userLocation }
        
        //@DEBUG
        /*if let location = self.userLocation
        {
            print("== \(location.horizontalAccuracy), \(age) \(location.coordinate.latitude), \(location.coordinate.longitude), \(location.altitude)" )
        }*/
        
        //===== Reporting location some time after we get location, this will filter multiple locations calls and make only one delegate call
        let reportIsScheduled = self.reportLocationTimer != nil
        
        // First time, reporting immediately
        if self.reportLocationDate == nil
        {
            self.reportLocationToDelegate()
        }
        // Report is already scheduled, doing nothing, it will report last location delivered in max minimumTimeBetweenLocationUpdates.
        else if reportIsScheduled
        {
            
        }
        // Scheduling report
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
        self.reportLocationTimer = Timer.scheduledTimer(timeInterval: self.minimumTimeBetweenLocationUpdates, target: self, selector: #selector(ARTrackingManager.reportLocationToDelegate), userInfo: nil, repeats: false)
    }
    
    @objc internal func reportLocationToDelegate()
    {
        self.stopReportLocationTimer()
        self.reportLocationDate = Date().timeIntervalSince1970
        
        guard let userLocation = self.userLocation, let reloadLocationPrevious = self.reloadLocationPrevious else { return }
        
        if reloadLocationPrevious.distance(from: userLocation) > self.reloadDistanceFilter
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
    // MARK:                                                    Pitch & Heading
    //==========================================================================================================================================================
    private var previousRawPitch: Double?
    private var previousRawHeading: Double?
    internal func calculateAndFilterPitchAndHeading()
    {
        guard let newPitch = self.calculatePitch(), let newHeading = self.calculateHeading(pitch: newPitch) else { return }
        
        //== Filter
        if var filterFactor = self.filterFactor
        {
            let previousRawPitch = self.previousRawPitch ?? newPitch
            let previousRawHeading = self.previousRawHeading ?? newHeading

            // Don't filter if first time.
            guard let previousPitch = self.pitch, let previousHeading = self.heading else
            {
                self.pitch = newPitch
                self.heading = newHeading
                self.previousRawPitch = newPitch
                self.previousRawHeading = newHeading
                return
            }
            
            /*
             There is a high chance that first few headings/pitch will be inacurate, so if filterFactor is very low (e.g. 0.05), you will see
             annotations spinning at the start because they are filtering from 0 to current heading/pitch.
             
             We are trying to fix that in first 10 sec by setting filterFactor to 1.0 if delta heading or pitch (raw) is greater than some value.
            */
            let headingStartDate = self.headingStartDate ?? Date()
            if self.headingStartDate == nil { self.headingStartDate = headingStartDate }
            if headingStartDate.timeIntervalSinceNow > -10 && (fabs(ARMath.deltaAngle(previousRawPitch, newPitch)) > 20 || fabs(ARMath.deltaAngle(previousRawHeading, newHeading)) > 20) { filterFactor = 1.0 }
        
            // Filter pitch and heading
            self.pitch = ARMath.normalizeDegree2(ARMath.exponentialFilter(newPitch, previousValue: previousPitch, filterFactor: filterFactor, isCircular: true))
            self.heading = ARMath.normalizeDegree(ARMath.exponentialFilter(newHeading, previousValue: previousHeading, filterFactor: filterFactor, isCircular: true))
        }
        //== No filter, use newest values
        else
        {
            self.pitch = newPitch
            self.heading = newHeading
        }
        
        self.previousRawPitch = newPitch
        self.previousRawHeading = newHeading
    }
    
    /**
     Solves problem with delayed filtering, e.g. if values change quickly for some reason then filtered values would need a lot of time to catch up.
     */
    internal func catchUpFilteredHeadingAndPitch()
    {
        guard let previousRawPitch = self.previousRawPitch, let previousRawHeading = self.previousRawHeading else { return }
        self.pitch = previousRawPitch
        self.heading = previousRawHeading
    }

    //==========================================================================================================================================================
    // MARK:                                                        Pitch
    //==========================================================================================================================================================
    internal func calculatePitch() -> Double?
    {
        guard let gravity = self.motionManager.deviceMotion?.gravity else { return nil}
        let deviceOrientation = self.orientation
        
        let pitch = ARMath.calculatePitch(gravity: simd_double3(gravity), deviceOrientation: deviceOrientation)
        return pitch
    }
    
    //==========================================================================================================================================================
    // MARK:                                                    Heading
    //==========================================================================================================================================================
    internal func setClHeading(newHeading: CLHeading)
    {
        guard newHeading.headingAccuracy >= 0 && newHeading.headingAccuracy <= self.minimumHeadingAccuracy else { return }

        if newHeading.trueHeading < 0 { self.clHeading = fmod(newHeading.magneticHeading, 360.0) }
        else { self.clHeading = fmod(newHeading.trueHeading, 360.0) }
    }
    
    internal func calculateHeading(pitch: Double) -> Double?
    {
        let heading: Double?
        if self.headingSource == .deviceMotion
        {
            guard let attitude = self.motionManager.deviceMotion?.attitude.quaternion else { return nil }
            let deviceOrientation = self.orientation
            
            heading = ARMath.calculateHeading(attitude: simd_quatd(attitude), pitch: pitch, deviceOrientation: deviceOrientation)
        }
        else
        {
            heading = self.clHeading
        }
        
        return heading
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
    
    //==========================================================================================================================================================
    // MARK:                                                    Nested
    //==========================================================================================================================================================
    /**
     Defines source of heading value that ARTrackingManager will use for its calculations.
     */
    public enum HeadingSource
    {
        /// Uses CoreLocation's LocationManager to fetch heading.
        case coreLocation
        /// iOS 11+. This means that ARTrackingManager will use CMMotionManager.deviceMotion.heading for its heading. Do not use this if you expect device to move fast (e.g. in car, bus etc) because CMMotionManager.deviceMotion.heading returns false readings.
        case deviceMotion
    }
}
