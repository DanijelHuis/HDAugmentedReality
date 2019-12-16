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
     Structure that holds all information related to AR. All device/location properties gathered by ARTrackingManager and
     camera properties gathered by ARViewController. It is intended to be used by ARPresenters and external objects.
    */
    open var arStatus: ARStatus = ARStatus()
    
    /**
     You can use this property to add accessory from Interface builder, do not use it for anything else.
     If you want to add accessory via code, use "accessories" property.
     */
    @IBOutlet open var accessoriesOutlet: [AnyObject] = []
    
    /**
     Close button, it is set in xib.
     */
    @IBOutlet open weak var closeButton: UIButton!


    /**
     Presenter instance. It is responsible for creation and layout of annotation views. Subclass and provide your own implementation if needed. Always set it before anything else is set on this controller.
     */
    @IBOutlet open var presenter: ARPresenter!
    {
        willSet
        {
            // Removing old instance
            self.presenter?.removeFromSuperview()
        }
        didSet
        {
            // If no superview, that means this is set from outside and not from xib so we need to add it.
            if self.presenter.superview == nil
            {
                self.presenter.translatesAutoresizingMaskIntoConstraints = false
                self.view.insertSubview(self.presenter, aboveSubview: self.cameraView)
                self.presenter.pinToSuperview(leading: 0, trailing: 0, top: 0, bottom: 0, width: nil, height: nil)
            }
        }
    }


    //===== Private
    fileprivate var annotations: [ARAnnotation] = []
    @IBOutlet private weak var cameraView: CameraView!
    
    /// Used as container for all controls and accessories.
    @IBOutlet private weak var controlContainerView: UIView!
    
    /**
     Accessories. You can add accessory from Interface builder by connecting it to "accessoriesOutlet" or by using addAccessory method.
     */
    private var accessories: [ARAccessory] = []
    
    fileprivate var initialized: Bool = false
    fileprivate var displayTimer: CADisplayLink?
    fileprivate var lastLocation: CLLocation?
    fileprivate var didLayoutSubviews: Bool = false
    fileprivate var pendingHighestRankingReload: ReloadType?

    fileprivate var debugTextView: UITextView?
    fileprivate var debugMapButton: UIButton?
    fileprivate var debugHeadingSlider: UISlider?
    fileprivate var debugPitchSlider: UISlider?

    private var shouldRecalculateDebugLocation = true
    private var fixedDebugLocation: CLLocation?
    private var debugDateFormatter = DateFormatter()
    //==========================================================================================================================================================
    // MARK:                                                        Init
    //==========================================================================================================================================================
    public init()
    {
        super.init(nibName: "ARViewController", bundle: Bundle(for: ARViewController.self))
        self.initializeInternal()
        
        // Needed because we want IBOutlets to be available immediately after init, so they can be configured from outside.
        self.loadViewIfNeeded()
    }
    
    required public init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        self.initializeInternal()
    }
    
    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?)
    {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.initializeInternal()
        
        // Needed because we want IBOutlets to be available immediately after init, so they can be configured from outside.
        self.loadViewIfNeeded()
    }
    
    internal func initializeInternal()
    {
        if self.initialized { return }
        self.initialized = true
        
        // Default values
        self.trackingManager.delegate = self
        if #available(iOS 13.0, *)
        {
            self.overrideUserInterfaceStyle = .dark
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(ARViewController.locationNotification(_:)), name: NSNotification.Name(rawValue: "kNotificationLocationSet"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ARViewController.appWillEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ARViewController.appDidEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        self.initialize()
    }
    
    /// Intended for use in subclasses, no need to call super
    open func initialize()
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
    override open func viewDidLoad() {
        super.viewDidLoad()
    }
    
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

    }
    
    fileprivate func onViewDidAppear()
    {
        // Set orientation and start camera
        self.setOrientation(UIApplication.shared.statusBarOrientation)
        
        // Try to init camera
        if !self.cameraView.isSessionCreated
        {
            let result = self.cameraView.createSessionAndVideoPreviewLayer()
            if let error = result.error, !Platform.isSimulator
            {
                self.dataSource?.ar?(self, didFailWithError: error)
                return
            }
        }
        
        // TrackingManager will reset all its values except last reload location so it will
        // call reload if user location changed significantly since disappear.
        self.startCameraAndTracking(notifyLocationFailure: true)
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
    
    @objc internal func appDidEnterBackground(_ notification: Notification)
    {
        if self.view.window != nil
        {
            // Stopping tracking and clearing presenter, it will restart and reload on appWillEnterForeground
            self.stopCameraAndTracking()
            self.presenter.clear()
        }
    }
    
    @objc internal func appWillEnterForeground(_ notification: Notification)
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
        // Accessories: Adding accessoriesOutlet to accessories. accessoriesOutlet is used only as shortcut to add accessory via Interface Builder.
        self.accessories.append(contentsOf: self.accessoriesOutlet.compactMap({ $0 as? ARAccessory }))
                                       
        // Debug
        self.addDebugUi()
    }
    
    fileprivate func layoutUi()
    {
        self.calculateFOV()
    }
    
    //==========================================================================================================================================================
    // MARK:                                                        Annotations, reload
    //==========================================================================================================================================================
    /// Sets annotations and calls reload on presenter
    open func setAnnotations(_ annotations: [ARAnnotation])
    {
        self.shouldRecalculateDebugLocation = true
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
        self.accessories.forEach({ $0.reload(reloadType: highestRankingReload, status: arStatus, presenter: self.presenter) })
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
            let azimuth = ARMath.bearingFromUserToLocation(userLocation: userLocation, location: annotation.location)
            annotation.azimuth = azimuth
        }
    }

    //==========================================================================================================================================================
    // MARK:                                    Events: ARLocationManagerDelegate/Display timer
    //==========================================================================================================================================================
    @objc internal func displayTimerTick()
    {
        //@TODO fix map long tap
        if self.uiOptions.simulatorDebugging
        {
            //===== Heading and pitch
            self.arStatus.heading = ARMath.normalizeDegree(Double(self.debugHeadingSlider?.value ?? 0))
            self.arStatus.pitch =  Double(self.debugPitchSlider?.value ?? 0)
            
            //===== Location
            var location: CLLocation? = self.fixedDebugLocation
  
            if location == nil, self.uiOptions.setUserLocationToCenterOfAnnotations, self.shouldRecalculateDebugLocation, self.annotations.count > 0
            {
                location = self.centerLocationFromAnnotations(annotations: self.annotations)
                self.shouldRecalculateDebugLocation = false
            }
            
            if let location = location { self.arStatus.userLocation = location }
        }
        else
        {
            self.trackingManager.calculateAndFilterPitchAndHeading()
            if let heading = self.trackingManager.heading, let pitch = self.trackingManager.pitch
            {
                self.arStatus.pitch = pitch
                self.arStatus.heading = heading
            }
            self.arStatus.userLocation = self.fixedDebugLocation ?? self.trackingManager.userLocation
        }
        
        self.reload(reloadType: .headingChanged)
        self.debug()
    }
    
    internal func arTrackingManager(_ trackingManager: ARTrackingManager, didUpdateUserLocation location: CLLocation)
    {
        self.arStatus.userLocation = self.fixedDebugLocation ?? location
        self.lastLocation = self.arStatus.userLocation
        self.reload(reloadType: .userLocationChanged)
        
        // Debug view, indicating that update was done
        if(self.uiOptions.debugLabel) { self.showDebugViewWithColor(color: UIColor.red) }
    }
    
    internal func arTrackingManager(_ trackingManager: ARTrackingManager, didUpdateReloadLocation location: CLLocation)
    {
        self.arStatus.userLocation = self.fixedDebugLocation ?? location
        self.lastLocation = self.arStatus.userLocation
        
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
        self.displayTimer?.add(to: RunLoop.current, forMode: RunLoop.Mode.default)
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
        self.presenter.isHidden = true
        coordinator.animate(alongsideTransition:
        {
            (coordinatorContext) in
            
            self.setOrientation(UIApplication.shared.statusBarOrientation)
        })
        {
            [unowned self] (coordinatorContext) in
            self.presenter.isHidden = false
            self.layoutAndReloadOnOrientationChange()
            self.trackingManager.catchUpFilteredHeadingAndPitch()
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
            
            if UIApplication.shared.statusBarOrientation.isLandscape
            {
                hFov = Double(retrieviedDevice.activeFormat.videoFieldOfView)   // This is horizontal FOV - FOV of the wider side of the screen
                vFov = (2 * atan( tan((hFov / 2).toRadians) * Double(frame.size.height / frame.size.width))).toDegrees
            }
            else
            {
                vFov = Double(retrieviedDevice.activeFormat.videoFieldOfView)   // This is horizontal FOV - FOV of the wider side of the screen
                hFov = (2 * atan( tan((vFov / 2).toRadians) * Double(frame.size.width / frame.size.height))).toDegrees
            }
        }
        // Used in simulator
        else
        {
            if UIApplication.shared.statusBarOrientation.isLandscape
            {
                hFov = Double(58)   // This is horizontal FOV - FOV of the wider side of the screen
                vFov = (2 * atan( tan((hFov / 2).toRadians) * Double(self.view.bounds.size.height / self.view.bounds.size.width))).toDegrees
            }
            else
            {
                vFov = Double(58)   // This is horizontal FOV - FOV of the wider side of the screen
                hFov = (2 * atan( tan((vFov / 2).toRadians) * Double(self.view.bounds.size.width / self.view.bounds.size.height))).toDegrees
            }
        }
        self.arStatus.hFov = hFov
        self.arStatus.vFov = vFov
        self.arStatus.hPixelsPerDegree = hFov > 0 ? Double(frame.size.width / CGFloat(hFov)) : 0
        self.arStatus.vPixelsPerDegree = vFov > 0 ? Double(frame.size.height / CGFloat(vFov)) : 0
    }
    //==========================================================================================================================================================
    // MARK:                                                    Accessories
    //==========================================================================================================================================================
    open func addAccessory(_ accessory: ARAccessory, leading: CGFloat?, trailing: CGFloat?, top: CGFloat?, bottom: CGFloat?, width: CGFloat?, height: CGFloat?)
    {
        if let accessoryView = accessory as? UIView
        {
            self.controlContainerView.addSubview(accessoryView)
            accessoryView.translatesAutoresizingMaskIntoConstraints = false
            accessoryView.pinToSuperview(leading: leading, trailing: trailing, top: top, bottom: bottom, width: width, height: height)
        }
        
        self.accessories.append(accessory)
    }


    //==========================================================================================================================================================
    //MARK:                                                        UI
    //==========================================================================================================================================================

    @IBAction func closeButtonTap()
    {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    open override var prefersStatusBarHidden : Bool
    {
        return true
    }
    
    /// Checks if camera can be initialized. You can use it if you really need to but this tries to create whole session so it is heavy operation.
    /// It is better to implement ARDataSource.ar(arViewController:didFailWithError:) and wait for error there.
    public static func isAllHardwareAvailable() -> CameraViewError?
    {
        return CameraView.createCaptureSession(withMediaType: AVMediaType.video, position: AVCaptureDevice.Position.back).error
    }
    
    //==========================================================================================================================================================
    //MARK:                                                        Debug
    //==========================================================================================================================================================
    /// Called from DebugMapViewController when user fakes location.
    @objc internal func locationNotification(_ sender: Notification)
    {
        if let location = sender.userInfo?["location"] as? CLLocation
        {
            self.fixedDebugLocation = location
            self.displayTimerTick()
            self.reload(reloadType: .reloadLocationChanged)
        }
    }
    
    /// Opening DebugMapViewController
    @objc internal func debugButtonTap()
    {        
        // DEBUG
        let bundle = Bundle(for: DebugMapViewController.self)
        let mapViewController = DebugMapViewController(nibName: "DebugMapViewController", bundle: bundle)
        self.present(mapViewController, animated: true, completion: nil)
        mapViewController.addAnnotations(self.annotations)
    }
    
    func addDebugUi()
    {
        guard let controlsView = self.controlContainerView else { return }
        
        if self.uiOptions.debugMap
        {
            self.debugMapButton?.removeFromSuperview()
            
            let debugMapButton: UIButton = UIButton(type: UIButton.ButtonType.custom)
            debugMapButton.translatesAutoresizingMaskIntoConstraints = false
            debugMapButton.addTarget(self, action: #selector(ARViewController.debugButtonTap), for: UIControl.Event.touchUpInside)
            debugMapButton.setTitle("map", for: UIControl.State())
            debugMapButton.backgroundColor = UIColor.white.withAlphaComponent(0.5)
            debugMapButton.setTitleColor(UIColor.black, for: UIControl.State())
            controlsView.addSubview(debugMapButton)
            debugMapButton.pinToSuperview(leading: 5, trailing: nil, top: 5, bottom: nil, width: 40, height: 40)
            self.debugMapButton = debugMapButton
        }
        
        if self.uiOptions.debugLabel
        {
            self.debugTextView?.removeFromSuperview()
            
            let debugLabel = UITextView()
            debugLabel.translatesAutoresizingMaskIntoConstraints = false
            debugLabel.backgroundColor = UIColor.white
            debugLabel.textColor = UIColor.black
            debugLabel.font = UIFont.boldSystemFont(ofSize: 10)
            debugLabel.autoresizingMask = [UIView.AutoresizingMask.flexibleWidth, UIView.AutoresizingMask.flexibleTopMargin]
            debugLabel.textAlignment = NSTextAlignment.left
            debugLabel.isScrollEnabled = false
            debugLabel.isEditable = false
            controlsView.addSubview(debugLabel)
            debugLabel.pinToSuperview(leading: 10, trailing: 10, top: nil, bottom: 5, width: nil, height: 100)
            self.debugTextView = debugLabel
            
            // Debug
            self.debugDateFormatter.dateFormat = "dd.MM.yyyy HH:mm:ss"
            let debugTap = UITapGestureRecognizer(target: self, action: #selector(self.debugTextViewTapped))
            self.debugTextView?.addGestureRecognizer(debugTap)
            
            let debugHorizontalLine = UIView()
            debugHorizontalLine.translatesAutoresizingMaskIntoConstraints = false
            debugHorizontalLine.backgroundColor = UIColor.green.withAlphaComponent(0.5)
            debugHorizontalLine.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleWidth]
            controlsView.addSubview(debugHorizontalLine)
            debugHorizontalLine.pinToSuperview(leading: 0, trailing: 0, top: nil, bottom: nil, width: nil, height: 1)
            debugHorizontalLine.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
            
            let debugVerticalLine = UIView()
            debugVerticalLine.translatesAutoresizingMaskIntoConstraints = false
            debugVerticalLine.backgroundColor = UIColor.green.withAlphaComponent(0.5)
            debugVerticalLine.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleHeight]
            controlsView.addSubview(debugVerticalLine)
            debugVerticalLine.pinToSuperview(leading: nil, trailing: nil, top: 0, bottom: 0, width: 1, height: nil)
            debugVerticalLine.centerXAnchor.constraint(equalTo: controlsView.centerXAnchor).isActive = true

        }
        
        if self.uiOptions.simulatorDebugging
        {
            let headingSlider: UISlider = UISlider()
            headingSlider.translatesAutoresizingMaskIntoConstraints = false
            headingSlider.autoresizingMask = []
            headingSlider.minimumValue = -180
            headingSlider.maximumValue = 180
            headingSlider.value = 1
            controlsView.addSubview(headingSlider)
            headingSlider.pinToSuperview(leading: 20, trailing: 60, top: 40, bottom: nil, width: nil, height: 20)
            self.debugHeadingSlider = headingSlider
            
            let pitchSlider: UISlider = UISlider()
            pitchSlider.translatesAutoresizingMaskIntoConstraints = false
            pitchSlider.autoresizingMask = []
            pitchSlider.minimumValue = -90
            pitchSlider.maximumValue = 90
            pitchSlider.value = 1
            controlsView.addSubview(pitchSlider)
            pitchSlider.heightAnchor.constraint(equalToConstant: 20).isActive = true
            pitchSlider.centerYAnchor.constraint(equalTo: controlsView.centerYAnchor, constant: 20).isActive = true
            pitchSlider.centerXAnchor.constraint(equalTo: controlsView.trailingAnchor, constant: -20).isActive = true
            pitchSlider.widthAnchor.constraint(equalTo: controlsView.heightAnchor, multiplier: 1.0, constant: -80).isActive = true
            pitchSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi * 0.5))
            self.debugPitchSlider = pitchSlider
        }
        
        self.closeButton.superview?.bringSubviewToFront(self.closeButton)
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
        self.debugTextView?.text = text
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
    
    func debug(printToConsole: Bool = false)
    {
        if self.uiOptions.debugLabel, let deviceMotion = self.trackingManager.motionManager.deviceMotion, let userLocation = arStatus.userLocation
        {
            let q = deviceMotion.attitude.quaternion
            let simd_q = simd_quatd(q)
            
            let heading: String
            if #available(iOS 11.0, *)
            {
                heading = String(format: "%.0f(%.0f,%.0f)", self.trackingManager.heading ?? 0, self.trackingManager.motionManager.deviceMotion?.heading ?? 0, self.trackingManager.clHeading ?? 0)
            }
            else
            {
                heading = String(format: "%.0f(%.0f)", self.trackingManager.heading ?? 0, self.trackingManager.clHeading ?? 0)
            }
            
            
            let pitch = String(format: "%.3f", self.trackingManager.pitch ?? 0)
            let attitude = String(format: "%.1f,%.1f,%.1f,%.1f", q.w, q.x, q.y, q.z)
            let axisAngle = String(format: "%.1f,%.1f,%.1f,%.1f", simd_q.angle.toDegrees, simd_q.axis.x, simd_q.axis.y, simd_q.axis.z)
            
            let location = String(format: "%.7f,%.7f", userLocation.coordinate.latitude, userLocation.coordinate.longitude)
            let gravity = String(format: "%.1f,%.1f,%.1f", deviceMotion.gravity.x, deviceMotion.gravity.y, deviceMotion.gravity.z)
            let userAcceleration = String(format: "%.1f,%.1f,%.1f", deviceMotion.userAcceleration.x, deviceMotion.userAcceleration.y, deviceMotion.userAcceleration.z)
            let rotationRate = String(format: "%.1f,%.1f,%.1f", deviceMotion.rotationRate.x, deviceMotion.rotationRate.y, deviceMotion.rotationRate.z)
            let magneticField = String(format: "%.1f,%.1f,%.1f [%i]", deviceMotion.magneticField.field.x, deviceMotion.magneticField.field.y, deviceMotion.magneticField.field.z, deviceMotion.magneticField.accuracy.rawValue)
            
            var text = "Heading: \(heading) --- Pitch: \(pitch)"
            text += "\nAttitude: \(attitude) (\(axisAngle)) --- Location: \(location)"
            text += "\nGravity: \(gravity) --- User acceleration: \(userAcceleration)"
            text += "\nRotation rate: \(rotationRate)\nMagnetic field: \(magneticField)"
            
            logText(text)
            if printToConsole
            {
                let dateString = self.debugDateFormatter.string(from: Date())
                text = "==================== \(dateString)\n\(text)"
                print(text)
            }
        }
    }
    
    @objc func debugTextViewTapped()
    {
        self.debug(printToConsole: true)
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
    }
}









