//
//  ViewController.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 21/04/15.
//  Copyright (c) 2015 Danijel Huis. All rights reserved.
//

import UIKit
import CoreLocation

class ViewController: UIViewController, ARDataSource
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
    }
    
    /// Creates random annotations around predefined center point and presents ARViewController modally
    func showARViewController()
    {
        // Check if device has hardware needed for augmented reality
        if let error = ARViewController.isAllHardwareAvailable(), !Platform.isSimulator
        {
            let message = error.userInfo["description"] as? String
            let alertView = UIAlertView(title: "Error", message: message, delegate: nil, cancelButtonTitle: "Close")
            alertView.show()
            return
        }
        
        // Create random annotations around center point
        //FIXME: set your initial position here, this is used to generate random POIs
        let lat = 45.554864
        let lon = 18.695441
        let deltaLat = 0.04 // Area in which to generate annotations
        let deltaLon = 0.07 // Area in which to generate annotations
        let altitudeDelta: Double = 0
        let count = 100
        let dummyAnnotations = ViewController.getDummyAnnotations(centerLatitude: lat, centerLongitude: lon, deltaLat: deltaLat, deltaLon: deltaLon, altitudeDelta: altitudeDelta, count: count)
   
        // Present ARViewController
        let arViewController = ARViewController()
        //arViewController.presenter = TestARPresenter(arViewController: arViewController)  // Always set custom presenter first
        arViewController.dataSource = self
        // Vertical offset by distance
        arViewController.presenter.distanceOffsetMode = .manual
        arViewController.presenter.distanceOffsetMultiplier = 0.1   // Pixels per meter
        arViewController.presenter.distanceOffsetMinThreshold = 500 // Doesn't raise annotations that are nearer than this
        // Filtering for performance
        arViewController.presenter.maxDistance = 3000               // Don't show annotations if they are farther than this
        arViewController.presenter.maxVisibleAnnotations = 100      // Max number of annotations on the screen
        // Stacking
        arViewController.presenter.verticalStackingEnabled = true
        // Location precision
        arViewController.trackingManager.userDistanceFilter = 15
        arViewController.trackingManager.reloadDistanceFilter = 50
        // Ui
        arViewController.uiOptions.closeButtonEnabled = true
        // Debugging
        arViewController.uiOptions.debugLabel = true
        arViewController.uiOptions.debugMap = true
        arViewController.uiOptions.simulatorDebugging = Platform.isSimulator
        arViewController.uiOptions.setUserLocationToCenterOfAnnotations =  Platform.isSimulator
        // Interface orientation
        arViewController.interfaceOrientationMask = .all
        // Failure handling
        arViewController.onDidFailToFindLocation =
            {
                [weak self, weak arViewController] elapsedSeconds, acquiredLocationBefore in
                
                self?.handleLocationFailure(elapsedSeconds: elapsedSeconds, acquiredLocationBefore: acquiredLocationBefore, arViewController: arViewController)
        }
        // Setting annotations
        arViewController.setAnnotations(dummyAnnotations)
        // Presenting controller
        self.present(arViewController, animated: true, completion: nil)
    }
    
    /// This method is called by ARViewController, make sure to set dataSource property.
    func ar(_ arViewController: ARViewController, viewForAnnotation: ARAnnotation) -> ARAnnotationView
    {
        // Annotation views should be lightweight views, try to avoid xibs and autolayout all together.
        let annotationView = TestAnnotationView()
        annotationView.frame = CGRect(x: 0,y: 0,width: 150,height: 50)
        return annotationView;
    }
    
    public class func getDummyAnnotations(centerLatitude: Double, centerLongitude: Double, deltaLat: Double, deltaLon: Double, altitudeDelta: Double, count: Int) -> Array<ARAnnotation>
    {
        var annotations: [ARAnnotation] = []
        
        srand48(2)
        for i in stride(from: 0, to: count, by: 1)
        {
            let location = self.getRandomLocation(centerLatitude: centerLatitude, centerLongitude: centerLongitude, deltaLat: deltaLat, deltaLon: deltaLon, altitudeDelta: altitudeDelta)

            if let annotation = ARAnnotation(identifier: nil, title: "POI \(i)", location: location)
            {
                annotations.append(annotation)
            }
        }
        return annotations
    }
    
    func addDummyAnnotation(_ lat: Double,_ lon: Double, altitude: Double, title: String, annotations: inout [ARAnnotation])
    {
        let location = CLLocation(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), altitude: altitude, horizontalAccuracy: 0, verticalAccuracy: 0, course: 0, speed: 0, timestamp: Date())
        if let annotation = ARAnnotation(identifier: nil, title: title, location: location)
        {
            annotations.append(annotation)
        }
    }
    
    public class func getRandomLocation(centerLatitude: Double, centerLongitude: Double, deltaLat: Double, deltaLon: Double, altitudeDelta: Double) -> CLLocation
    {
        var lat = centerLatitude
        var lon = centerLongitude
        
        let latDelta = -(deltaLat / 2) + drand48() * deltaLat
        let lonDelta = -(deltaLon / 2) + drand48() * deltaLon
        lat = lat + latDelta
        lon = lon + lonDelta
        
        let altitude = drand48() * altitudeDelta
        return CLLocation(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), altitude: altitude, horizontalAccuracy: 1, verticalAccuracy: 1, course: 0, speed: 0, timestamp: Date())
    }
    
    @IBAction func buttonTap(_ sender: AnyObject)
    {
        showARViewController()
    }
    
    func handleLocationFailure(elapsedSeconds: TimeInterval, acquiredLocationBefore: Bool, arViewController: ARViewController?)
    {
        guard let arViewController = arViewController else { return }
        guard !Platform.isSimulator else { return }
        NSLog("Failed to find location after: \(elapsedSeconds) seconds, acquiredLocationBefore: \(acquiredLocationBefore)")
        
        // Example of handling location failure
        if elapsedSeconds >= 20 && !acquiredLocationBefore
        {
            // Stopped bcs we don't want multiple alerts
            arViewController.trackingManager.stopTracking()
            
            let alert = UIAlertController(title: "Problems", message: "Cannot find location, use Wi-Fi if possible!", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "Close", style: .cancel)
            {
                (action) in
                
                self.dismiss(animated: true, completion: nil)
            }
            alert.addAction(okAction)
            
            self.presentedViewController?.present(alert, animated: true, completion: nil)
        }
    }
}
