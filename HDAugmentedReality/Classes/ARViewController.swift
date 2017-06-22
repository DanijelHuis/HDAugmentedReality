//
//  ARViewController.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 23/04/15.
//  Copyright (c) 2015 Danijel Huis. All rights reserved.
//

import UIKit
import AVFoundation
import CoreLocation

/**
 *      Augmented reality view controller.
 *
 *      How to use:
 *      1. Initialize controller and set datasource
 *      2. Use setAnnotations method to set annotations
 *      3. Present controller modally
 *      4. Implement ARDataSource to provide annotation views in your data source
 *
 *      https://github.com/DanijelHuis/HDAugmentedReality.git
 *
 */
open class ARViewController: UIViewController, ARTrackingManagerDelegate
{
    /// Data source - source of annotation views for ARViewController/ARPresenter, implement it to provide annotation views.
    open weak var dataSource: ARDataSource?
    
    /// Orientation mask for view controller. Make sure orientations are enabled in project settings also.
    open var interfaceOrientationMask: UIInterfaceOrientationMask = UIInterfaceOrientationMask.all

    /// Class for tracking location/heading/pitch. Use it to set properties like reloadDistanceFilter, userDistanceFilter etc.
    fileprivate(set) open var trackingManager: ARTrackingManager = ARTrackingManager()
    
    /// Image for close button. If not set, default one is used.
    open var closeButtonImage: UIImage?
    {
        didSet
        {
            self.closeButton?.setImage(self.closeButtonImage, for: UIControlState())
        }
    }
    
    /**
     Called every 5 seconds after location tracking is started but failed to deliver location. It is also called when tracking has just started with timeElapsed = 0.
     The timer is restarted when app comes from background or on didAppear.
     */
    open var onDidFailToFindLocation: ((_ timeElapsed: TimeInterval, _ acquiredLocationBefore: Bool) -> Void)?
    
    /**
     Some ui options. Set it before controller is shown, changes made afterwards are disregarded.
     */
    open var uiOptions = UiOptions()
    
    /**
     Presenter instance. It is responsible for creation and layout of annotation views. Subclass and provide your own implementation if needed. Always set it before anything else is set on this controller.
     */
    open var presenter: ARPresenter!
    {
        willSet
        {
            self.presenter?.removeFromSuperview()
        }
        didSet
        {
            if self.didLayoutSubviews
            {
                self.view.insertSubview(self.presenter, aboveSubview: self.cameraView)
            }
        }
    }
    
    /**
     Structure that holds all information related to AR. All device/location properties gathered by ARTrackingManager and
     camera properties gathered by ARViewController. It is intended to be used by ARPresenters and external objects.
    */
    open var arStatus: ARStatus = ARStatus()
    
    //===== Private
    fileprivate var annotations: [ARAnnotation] = []
    fileprivate var cameraView: CameraView = CameraView()

    fileprivate var initialized: Bool = false
    fileprivate var displayTimer: CADisplayLink?
    fileprivate var closeButton: UIButton?
    fileprivate var lastLocation: CLLocation?
    fileprivate var didLayoutSubviews: Bool = false
    fileprivate var pendingHighestRankingReload: ReloadType?

    fileprivate var debugLabel: UILabel?
    fileprivate var debugMapButton: UIButton?
    fileprivate var debugHeadingSlider: UISlider?
    fileprivate var debugPitchSlider: UISlider?

    //==========================================================================================================================================================
    // MARK:                                                        Init
    //==========================================================================================================================================================
    init()
    {
        super.init(nibName: nil, bundle: nil)
        self.initializeInternal()
    }
    
    required public init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        self.initializeInternal()
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?)
    {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.initializeInternal()
    }
    
    internal func initializeInternal()
    {
        if self.initialized { return }
        self.initialized = true
        
        // Default values
        self.presenter = ARPresenter(arViewController: self)

        self.trackingManager.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(ARViewController.locationNotification(_:)), name: NSNotification.Name(rawValue: "kNotificationLocationSet"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ARViewController.appWillEnterForeground(_:)), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ARViewController.appDidEnterBackground(_:)), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        self.initialize()
    }
    
    /// Intended for use in subclasses, no need to call super
    internal func initialize()
    {
        
    }
    
    deinit
    {
        NotificationCenter.default.removeObserver(self)
        self.stopCameraAndTracking()
    }
    
    //==========================================================================================================================================================
    // MARK:                                                        View's lifecycle
    //==========================================================================================================================================================
    open override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.onViewWillAppear()  // Doing like this to prevent subclassing problems
        
        self.view.setNeedsLayout()  // making sure viewDidLayoutSubviews is called so we can handle all in there
    }
    
    open override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        self.onViewDidAppear()   // Doing like this to prevent subclassing problems
    }
    
    open override func viewDidDisappear(_ animated: Bool)
    {
        super.viewDidDisappear(animated)
        self.onViewDidDisappear()    // Doing like this to prevent subclassing problems
    }
    
    open override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        self.onViewDidLayoutSubviews()
    }
    
    fileprivate func onViewWillAppear()
    {
        // Set orientation and start camera
        self.setOrientation(UIApplication.shared.statusBarOrientation)
        
        // TrackingManager will reset all its values except last reload location so it will
        // call reload if user location changed significantly since disappear.
        self.startCameraAndTracking(notifyLocationFailure: true)
    }
    
    fileprivate func onViewDidAppear()
    {
        
    }
    
    fileprivate func onViewDidDisappear()
    {
        self.stopCameraAndTracking()
    }
    
    fileprivate func onViewDidLayoutSubviews()
    {
        // Executed only first time when everything is layouted
        if !self.didLayoutSubviews
        {
            self.didLayoutSubviews = true
            self.loadUi()
        }
        
        // Layout
        self.layoutUi()
    }
    
    internal func appDidEnterBackground(_ notification: Notification)
    {
        if self.view.window != nil
        {
            // Stopping tracking and clearing presenter, it will restart and reload on appWillEnterForeground
            self.stopCameraAndTracking()
            self.presenter.clear()
        }
    }
    
    internal func appWillEnterForeground(_ notification: Notification)
    {
        if self.view.window != nil
        {
            // This will make presenter reload
            self.startCameraAndTracking(notifyLocationFailure: true)
        }
    }
    
    //==========================================================================================================================================================
    // MARK:                                                        UI
    //==========================================================================================================================================================
    
    /// This is called only once when view is fully layouted.
    fileprivate func loadUi()
    {
        // Presenter
        if self.presenter.superview == nil { self.view.insertSubview(self.presenter, at: 0) }
        
        // Camera
        if self.cameraView.superview == nil { self.view.insertSubview(self.cameraView, at: 0) }
        self.cameraView.startRunning()
        
        // Close button
        if self.uiOptions.closeButtonEnabled { self.addCloseButton() }
        
        // Debug
        self.addDebugUi()
        
        // Must be called bcs of camera view
        self.setOrientation(UIApplication.shared.statusBarOrientation)
        self.view.layoutIfNeeded()
    }
    
    fileprivate func layoutUi()
    {
        self.cameraView.frame = self.view.bounds
        self.presenter.frame = self.view.bounds
        self.layoutDebugUi()
        self.calculateFOV()
    }
    
    //==========================================================================================================================================================
    // MARK:                                                        Annotations, reload
    //==========================================================================================================================================================
    /// Sets annotations and calls reload on presenter
    open func setAnnotations(_ annotations: [ARAnnotation])
    {
        // If simulatorDebugging is true, getting center location from all annotations and setting it as current user location
        if self.uiOptions.setUserLocationToCenterOfAnnotations, let location = self.centerLocationFromAnnotations(annotations: annotations)
        {
            self.arStatus.userLocation = location
            self.trackingManager.startDebugMode(location: location)
        }
        
        self.annotations = annotations
        self.reload(reloadType: .annotationsChanged)
    }
    
    open func getAnnotations() -> [ARAnnotation]
    {
        return self.annotations
    }
    
    open func reload(reloadType currentReload: ARViewController.ReloadType)
    {
        // Explanation why pendingHighestRankingReload is used: if this method is called in this order:
        // 1. currentReload = annotationsChanged, arStatus.ready = false
        // 2. currentReload = headingChanged, arStatus.ready = false
        // 3. currentReload = headingChanged, arStatus.ready = true
        // We want to use annotationsChanged because that is most important reload even if currentReload is headingChanged.
        // Also, it is assumed that ARPresenter will on annotationsChanged do everything it does on headingChanged, and more probably.
        if self.pendingHighestRankingReload == nil || currentReload.rawValue > self.pendingHighestRankingReload!.rawValue
        {
            self.pendingHighestRankingReload = currentReload
        }
        guard self.arStatus.ready else { return }
        guard let highestRankingReload = self.pendingHighestRankingReload else { return }
        self.pendingHighestRankingReload = nil
        
        // Relative positions of user and annotations changed so we recalculate azimuths.
        // When azimuths are calculated, presenter should restack annotations to prevent overlapping.
        if highestRankingReload == .annotationsChanged || highestRankingReload == .reloadLocationChanged || highestRankingReload == .userLocationChanged
        {
            self.calculateDistancesForAnnotations()
            self.calculateAzimuthsForAnnotations()
        }
    
        self.presenter.reload(annotations: self.annotations, reloadType: highestRankingReload)
    }
    
    open func calculateDistancesForAnnotations()
    {
        guard let userLocation = self.arStatus.userLocation else { return }
        
        for annotation in self.annotations
        {
            annotation.distanceFromUser = annotation.location.distance(from: userLocation)
        }
        
        self.annotations = self.annotations.sorted { $0.distanceFromUser < $1.distanceFromUser }
    }
    
    open func calculateAzimuthsForAnnotations()
    {
        guard let userLocation = self.arStatus.userLocation else { return }
        
        for annotation in self.annotations
        {
            let azimuth = self.trackingManager.azimuthFromUserToLocation(userLocation: userLocation, location: annotation.location)
            annotation.azimuth = azimuth
        }
    }

    //==========================================================================================================================================================
    // MARK:                                    Events: ARLocationManagerDelegate/Display timer
    //==========================================================================================================================================================
    internal func displayTimerTick()
    {
        if self.uiOptions.simulatorDebugging
        {
            // Getting heading and pitch from sliders
            var heading: Double = Double(self.debugHeadingSlider?.value ?? 0)
            heading = normalizeDegree(heading)
            self.trackingManager.startDebugMode(location: nil, heading: Double(heading), pitch: Double(self.debugPitchSlider?.value ?? 0))
        }
        
        self.trackingManager.filterPitch()
        self.trackingManager.filterHeading()
        self.arStatus.pitch = self.trackingManager.filteredPitch
        self.arStatus.heading = self.trackingManager.filteredHeading
        self.reload(reloadType: .headingChanged)
        
        if self.uiOptions.debugLabel
        {
            let heading = String(format: "%.0f(%.0f)", self.trackingManager.debugHeading ?? self.trackingManager.heading, self.trackingManager.filteredHeading)
            let pitch = String(format: "%.3f", self.trackingManager.filteredPitch)
            logText("Heading: \(heading) -- Pitch: \(pitch)")
        }
    }
    
    internal func arTrackingManager(_ trackingManager: ARTrackingManager, didUpdateUserLocation location: CLLocation)
    {
        self.arStatus.userLocation = location
        self.lastLocation = location
        self.reload(reloadType: .userLocationChanged)
        
        // Debug view, indicating that update was done
        if(self.uiOptions.debugLabel) { self.showDebugViewWithColor(color: UIColor.red) }
    }
    
    internal func arTrackingManager(_ trackingManager: ARTrackingManager, didUpdateReloadLocation location: CLLocation)
    {
        self.arStatus.userLocation = location
        self.lastLocation = location
        
        // Manual reload?
        if let dataSource = self.dataSource, dataSource.responds(to: #selector(ARDataSource.ar(_:shouldReloadWithLocation:)))
        {
            if let annotations = dataSource.ar?(self, shouldReloadWithLocation: location)
            {
                self.setAnnotations(annotations)
            }
        }
        // If no manual reload, calling reload with .reloadLocationChanged, this will give the opportunity to the presenter
        // to filter existing annotations with distance, max count etc.
        else
        {
            self.reload(reloadType: .reloadLocationChanged)
        }
        
        // Debug view, indicating that update was done
        if(self.uiOptions.debugLabel) { self.showDebugViewWithColor(color: UIColor.blue) }
    }
    
    internal func arTrackingManager(_ trackingManager: ARTrackingManager, didFailToFindLocationAfter elapsedSeconds: TimeInterval)
    {
        self.onDidFailToFindLocation?(elapsedSeconds, self.lastLocation != nil)
    }
    
    //==========================================================================================================================================================
    // MARK:                                                        Camera
    //==========================================================================================================================================================
    fileprivate func startCameraAndTracking(notifyLocationFailure: Bool)
    {
        self.cameraView.startRunning()
        self.trackingManager.startTracking(notifyLocationFailure: notifyLocationFailure)
        self.displayTimer = CADisplayLink(target: self, selector: #selector(ARViewController.displayTimerTick))
        self.displayTimer?.add(to: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
    }
    
    fileprivate func stopCameraAndTracking()
    {
        self.cameraView.stopRunning()
        self.trackingManager.stopTracking()
        self.displayTimer?.invalidate()
        self.displayTimer = nil
    }
    
    //==========================================================================================================================================================
    //MARK:                                                        Rotation/Orientation
    //==========================================================================================================================================================
    open override var shouldAutorotate : Bool
    {
        return true
    }
    
    open override var supportedInterfaceOrientations : UIInterfaceOrientationMask
    {
        return self.interfaceOrientationMask
    }

    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
    {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition:
        {
            (coordinatorContext) in
            
            self.setOrientation(UIApplication.shared.statusBarOrientation)
        })
        {
            [unowned self] (coordinatorContext) in
            
            self.layoutAndReloadOnOrientationChange()
        }
    }
    
    internal func layoutAndReloadOnOrientationChange()
    {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        self.layoutUi()
        self.reload(reloadType: .annotationsChanged)
        CATransaction.commit()
    }
    
    fileprivate func setOrientation(_ orientation: UIInterfaceOrientation)
    {
        self.cameraView.setVideoOrientation(orientation)
    }
    
    internal func calculateFOV()
    {
        var hFov: Double = 0
        var vFov: Double = 0
        let frame = self.cameraView.frame.isEmpty ? self.view.frame : self.cameraView.frame
        
        if let retrieviedDevice = self.cameraView.inputDevice()
        {
            // Formula: hFOV = 2 * atan[ tan(vFOV/2) * (width/height) ]
            // width, height are camera width/height
            
            if UIInterfaceOrientationIsLandscape(UIApplication.shared.statusBarOrientation)
            {
                hFov = Double(retrieviedDevice.activeFormat.videoFieldOfView)   // This is horizontal FOV - FOV of the wider side of the screen
                vFov = radiansToDegrees(2 * atan( tan(degreesToRadians(hFov / 2)) * Double(frame.size.height / frame.size.width)))
            }
            else
            {
                vFov = Double(retrieviedDevice.activeFormat.videoFieldOfView)   // This is horizontal FOV - FOV of the wider side of the screen
                hFov = radiansToDegrees(2 * atan( tan(degreesToRadians(vFov / 2)) * Double(frame.size.width / frame.size.height)))
            }
        }
        // Used in simulator
        else
        {
            if UIInterfaceOrientationIsLandscape(UIApplication.shared.statusBarOrientation)
            {
                hFov = Double(58)   // This is horizontal FOV - FOV of the wider side of the screen
                vFov = radiansToDegrees(2 * atan( tan(degreesToRadians(hFov / 2)) * Double(self.view.bounds.size.height / self.view.bounds.size.width)))
            }
            else
            {
                vFov = Double(58)   // This is horizontal FOV - FOV of the wider side of the screen
                hFov = radiansToDegrees(2 * atan( tan(degreesToRadians(vFov / 2)) * Double(self.view.bounds.size.width / self.view.bounds.size.height)))
            }
        }
        
        self.arStatus.hFov = hFov
        self.arStatus.vFov = vFov
        self.arStatus.hPixelsPerDegree = hFov > 0 ? Double(frame.size.width / CGFloat(hFov)) : 0
        self.arStatus.vPixelsPerDegree = vFov > 0 ? Double(frame.size.height / CGFloat(vFov)) : 0
    }

    //==========================================================================================================================================================
    //MARK:                                                        UI
    //==========================================================================================================================================================
    func addCloseButton()
    {
        self.closeButton?.removeFromSuperview()
        
        if self.closeButtonImage == nil
        {
            let bundle = Bundle(for: ARViewController.self)
            let path = bundle.path(forResource: "hdar_close", ofType: "png")
            if let path = path
            {
                self.closeButtonImage = UIImage(contentsOfFile: path)
            }
        }
        
        // Close button - make it customizable
        let closeButton: UIButton = UIButton(type: UIButtonType.custom)
        closeButton.setImage(closeButtonImage, for: UIControlState());
        closeButton.frame = CGRect(x: self.view.bounds.size.width - 45, y: 5,width: 40,height: 40)
        closeButton.addTarget(self, action: #selector(ARViewController.closeButtonTap), for: UIControlEvents.touchUpInside)
        closeButton.autoresizingMask = [UIViewAutoresizing.flexibleLeftMargin, UIViewAutoresizing.flexibleBottomMargin]
        self.view.addSubview(closeButton)
        self.closeButton = closeButton
    }
    
    internal func closeButtonTap()
    {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    open override var prefersStatusBarHidden : Bool
    {
        return true
    }
    
    /// Checks if back video device is available.
    open static func isAllHardwareAvailable() -> NSError?
    {
        return CameraView.createCaptureSession(withMediaType: AVMediaTypeVideo, position: AVCaptureDevicePosition.back).error
    }
    
    //==========================================================================================================================================================
    //MARK:                                                        Debug
    //==========================================================================================================================================================
    /// Called from DebugMapViewController when user fakes location.
    internal func locationNotification(_ sender: Notification)
    {
        if let location = sender.userInfo?["location"] as? CLLocation
        {
            self.trackingManager.startDebugMode(location: location)
            self.reload(reloadType: .reloadLocationChanged)
        }
    }
    
    /// Opening DebugMapViewController
    internal func debugButtonTap()
    {
       // self.presenter.reload(annotations: self.annotations, reloadType: .userLocationChanged)
        //return

            // DEBUG
        let bundle = Bundle(for: DebugMapViewController.self)
        let mapViewController = DebugMapViewController(nibName: "DebugMapViewController", bundle: bundle)
        self.present(mapViewController, animated: true, completion: nil)
        mapViewController.addAnnotations(self.annotations)
    }
    
    func addDebugUi()
    {
        let width = self.view.bounds.size.width
        let height = self.view.bounds.size.height
        
        if self.uiOptions.debugMap
        {
            self.debugMapButton?.removeFromSuperview()
            
            let debugMapButton: UIButton = UIButton(type: UIButtonType.custom)
            debugMapButton.frame = CGRect(x: 5,y: 5,width: 40,height: 40);
            debugMapButton.addTarget(self, action: #selector(ARViewController.debugButtonTap), for: UIControlEvents.touchUpInside)
            debugMapButton.setTitle("map", for: UIControlState())
            debugMapButton.backgroundColor = UIColor.white.withAlphaComponent(0.5)
            debugMapButton.setTitleColor(UIColor.black, for: UIControlState())
            self.view.addSubview(debugMapButton)
            self.debugMapButton = debugMapButton
        }
        
        if self.uiOptions.debugLabel
        {
            self.debugLabel?.removeFromSuperview()
            
            let debugLabel = UILabel()
            debugLabel.backgroundColor = UIColor.white
            debugLabel.textColor = UIColor.black
            debugLabel.font = UIFont.boldSystemFont(ofSize: 10)
            debugLabel.frame = CGRect(x: 5, y: self.view.bounds.size.height - 55, width: self.view.bounds.size.width - 10, height: 40)
            debugLabel.numberOfLines = 0
            debugLabel.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleTopMargin]
            debugLabel.textAlignment = NSTextAlignment.left
            view.addSubview(debugLabel)
            self.debugLabel = debugLabel
            
            let debugHorizontalLine = UIView()
            debugHorizontalLine.frame = CGRect(x: 0, y: height/2, width: width, height: 1)
            debugHorizontalLine.backgroundColor = UIColor.green.withAlphaComponent(0.5)
            debugHorizontalLine.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleWidth]
            view.addSubview(debugHorizontalLine)
            
            let debugVerticalLine = UIView()
            debugVerticalLine.frame = CGRect(x: width / 2, y: 0, width: 1, height: height)
            debugVerticalLine.backgroundColor = UIColor.green.withAlphaComponent(0.5)
            debugVerticalLine.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleHeight]
            view.addSubview(debugVerticalLine)
        }
        
        if self.uiOptions.simulatorDebugging
        {
            let headingSlider: UISlider = UISlider()
            headingSlider.autoresizingMask = []
            headingSlider.minimumValue = -180
            headingSlider.maximumValue = 180
            headingSlider.value = 1
            self.view.addSubview(headingSlider)
            self.debugHeadingSlider = headingSlider
            
            let pitchSlider: UISlider = UISlider()
            pitchSlider.autoresizingMask = []
            pitchSlider.minimumValue = -90
            pitchSlider.maximumValue = 90
            pitchSlider.value = 1
            self.view.addSubview(pitchSlider)
            self.debugPitchSlider = pitchSlider
        }
    }
    
    func layoutDebugUi()
    {
        if self.uiOptions.simulatorDebugging
        {
            let width = self.view.bounds.size.width
            let height = self.view.bounds.size.height
            
            self.debugHeadingSlider?.frame = CGRect(x: 20,y: self.view.frame.size.height - 20, width: self.view.frame.size.width - 40,height: 20);
            
            self.debugPitchSlider?.transform = .identity
            self.debugPitchSlider?.frame = CGRect(x: width - (height - 40) / 2 - 20, y: height/2, width: height - 40, height: 20);
            self.debugPitchSlider?.transform = CGAffineTransform(rotationAngle: CGFloat(-M_PI * 0.5))
        }
    }
    
    func showDebugViewWithColor(color: UIColor)
    {
        let view = UIView()
        view.frame = CGRect(x: self.view.bounds.size.width - 80, y: 10, width: 30, height: 30)
        view.backgroundColor = color
        self.view.addSubview(view)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1.5 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC))
        {
            view.removeFromSuperview()
        }
    }
    
    internal func logText(_ text: String)
    {
        self.debugLabel?.text = text
    }
    
    func centerLocationFromAnnotations(annotations: [ARAnnotation]) -> CLLocation?
    {
        guard annotations.count > 0 else { return nil }
        
        var location: CLLocation? = nil
        var minLat: CLLocationDegrees = 1000
        var maxLat: CLLocationDegrees = -1000
        var minLon: CLLocationDegrees = 1000
        var maxLon: CLLocationDegrees = -1000

        for annotation in annotations
        {
            let latitude = annotation.location.coordinate.latitude
            let longitude = annotation.location.coordinate.longitude
            
            if latitude < minLat { minLat = latitude }
            if latitude > maxLat { maxLat = latitude }
            if longitude < minLon { minLon = longitude }
            if longitude > maxLon { maxLon = longitude }
        }
        
        let coordinate = CLLocationCoordinate2D(latitude: (minLat + maxLat) * 0.5, longitude: (minLon + maxLon) * 0.5)
        if CLLocationCoordinate2DIsValid(coordinate)
        {
            location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
        
        return location
    }
    
    //==========================================================================================================================================================
    //MARK:                                                        Inner classes/enums/structs
    //==========================================================================================================================================================
    
    /// Note that raw values are important because of pendingHighestRankingReload
    public enum ReloadType: Int
    {
        case headingChanged = 0
        case userLocationChanged = 1
        case reloadLocationChanged = 2
        case annotationsChanged = 3
    }
 
    public struct UiOptions
    {
        /// Enables/Disables debug map
        public var debugMap = false
        /// Enables/Disables debug sliders for heading/pitch and simulates userLocation to center of annotations
        public var simulatorDebugging = false
        /// Enables/Disables debug label at bottom and some indicator views when updating/reloading.
        public var debugLabel = false
        /// If true, it will set debugLocation to center of all annotations. Usefull for simulator debugging
        public var setUserLocationToCenterOfAnnotations = false;
        /// Enables/Disables close button.
        public var closeButtonEnabled = true
    }
}










