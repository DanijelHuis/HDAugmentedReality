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
        let delta = 0.075
        let altitudeDelta: Double = 0
        let count = 100
        let dummyAnnotations = self.getDummyAnnotations(centerLatitude: lat, centerLongitude: lon, delta: delta, altitudeDelta: altitudeDelta, count: count)
   
        // Present ARViewController
        let arViewController = ARViewController()
        arViewController.dataSource = self

        arViewController.presenter.distanceOffsetMode = .manual
        arViewController.presenter.distanceOffsetMultiplier = 0.02
        arViewController.presenter.distanceOffsetMinThreshold = 500

        arViewController.presenter.maxDistance = 0
        arViewController.presenter.maxVisibleAnnotations = 100
        
        arViewController.presenter.verticalStackingEnabled = true
        arViewController.trackingManager.userDistanceFilter = 15
        arViewController.trackingManager.reloadDistanceFilter = 50
        //arViewController.interfaceOrientationMask = .landscape

        // Debugging
        arViewController.uiOptions.debugLabel = true
        arViewController.uiOptions.debugMap = true
        arViewController.uiOptions.simulatorDebugging = Platform.isSimulator
        arViewController.uiOptions.setUserLocationToCenterOfAnnotations =  Platform.isSimulator
        arViewController.uiOptions.closeButtonEnabled = true
        
        arViewController.setAnnotations(dummyAnnotations)
        arViewController.onDidFailToFindLocation =
        {
            [weak self, weak arViewController] elapsedSeconds, acquiredLocationBefore in
                
            self?.handleLocationFailure(elapsedSeconds: elapsedSeconds, acquiredLocationBefore: acquiredLocationBefore, arViewController: arViewController)
        }
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
    
    fileprivate func getDummyAnnotations(centerLatitude: Double, centerLongitude: Double, delta: Double, altitudeDelta: Double, count: Int) -> Array<ARAnnotation>
    {
        var annotations: [ARAnnotation] = []
        
        srand48(2)
        for i in stride(from: 0, to: count, by: 1)
        {
            let location = self.getRandomLocation(centerLatitude: centerLatitude, centerLongitude: centerLongitude, delta: delta, altitudeDelta: altitudeDelta)

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
    
    fileprivate func getRandomLocation(centerLatitude: Double, centerLongitude: Double, delta: Double, altitudeDelta: Double) -> CLLocation
    {
        var lat = centerLatitude
        var lon = centerLongitude
        
        let latDelta = -(delta / 2) + drand48() * delta
        let lonDelta = -(delta / 2) + drand48() * delta
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
