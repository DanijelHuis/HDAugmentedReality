//
//  ViewController.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 21/04/15.
//  Copyright (c) 2015 Danijel Huis. All rights reserved.
//

import UIKit
import CoreLocation
import HDAugmentedReality
import MapKit

class ViewController: UIViewController
{
    /// Creates random annotations around predefined center point and presents ARViewController modally
    func showARViewController()
    {
        //===== Create random annotations around center point
        //FIXME: set your initial position here, this is used to generate random POIs
        let lat = 45.554864
        let lon = 18.695441
        //let lat = 45.681177
        //let lon = 18.401508
        let deltaLat = 0.2 // Area in which to generate annotations
        let deltaLon = 0.2 // Area in which to generate annotations
        let altitudeDelta: Double = 0
        let annotationCount = 200
        let dummyAnnotations = ViewController.getDummyAnnotations(centerLatitude: lat, centerLongitude: lon, deltaLat: deltaLat, deltaLon: deltaLon, altitudeDelta: altitudeDelta, count: annotationCount)

        //===== ARViewController
        // Creating ARViewController. You can use ARViewController(nibName:bundle:) if you have custom xib.
        let arViewController = ARViewController()

        //===== Presenter - handles visual presentation of annotations
        let presenter = arViewController.presenter!
        // Vertical offset by distance
        presenter.distanceOffsetMode = .manual
        presenter.distanceOffsetMultiplier = 0.05   // Pixels per meter
        presenter.distanceOffsetMinThreshold = 1000 // Tell it to not raise annotations that are nearer than this
        // Limiting number of annotations shown for performance
        presenter.maxDistance = 5000               // Don't show annotations if they are farther than this
        presenter.maxVisibleAnnotations = 100      // Max number of annotations on the screen
        // Telling it to stack vertically.
        presenter.presenterTransform = ARPresenterStackTransform()

        //===== Tracking manager - handles location tracking, heading, pitch, calculations etc.
        // Location precision
        let trackingManager = arViewController.trackingManager
        trackingManager.userDistanceFilter = 15
        trackingManager.reloadDistanceFilter = 50
        //trackingManager.filterFactor = 0.05
        //trackingManager.headingSource = .deviceMotion   // Read headingSource property description before changing.
        
        //===== ARViewController
        // Ui
        arViewController.dataSource = self
        // Debugging
        arViewController.uiOptions.debugLabel = false
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
        arViewController.modalPresentationStyle = .fullScreen

        //===== Radar
        var safeArea = UIEdgeInsets.zero
        if #available(iOS 11.0, *) { safeArea = UIApplication.shared.delegate?.window??.safeAreaInsets ?? UIEdgeInsets.zero }
        
        let radar = RadarMapView()
        radar.startMode = .centerUser(span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        radar.trackingMode = .none
        //radar.configuration... Use it to customize
        radar.indicatorRingType = .segmented(segmentColor: nil, userSegmentColor: nil)
        //radar.indicatorRingType = .precise(indicatorColor: nil, userIndicatorColor: .white)
        //radar.maxDistance = 5000    // Limit bcs it drains battery if lots of annotations (>200), especially if indicatorRingType is .precise
        arViewController.addAccessory(radar, leading: 15, trailing: nil, top: nil, bottom: 15 + safeArea.bottom / 4, width: nil, height: 150)
        
        //===== Presenting controller
        self.present(arViewController, animated: true, completion: nil)
    }
        
    @IBAction func buttonTap(_ sender: AnyObject)
    {
        self.showARViewController()
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
//==========================================================================================================================================================
// MARK:                                                    ARDataSource
//==========================================================================================================================================================
extension ViewController: ARDataSource
{
    /// This method is called by ARViewController, make sure to set dataSource property.
    func ar(_ arViewController: ARViewController, viewForAnnotation annotation: ARAnnotation) -> ARAnnotationView
    {
        // Annotation views should be lightweight views, try to avoid xibs and autolayout all together.
        let annotationView = TestAnnotationView()
        annotationView.frame = CGRect(x: 0,y: 0,width: 150,height: 50)
        return annotationView;
    }
    
    /// This can currently only be called because of camera error.
    func ar(_ arViewController: ARViewController, didFailWithError error: Error)
    {
        if let _ = error as? CameraViewError
        {
            let alert = UIAlertController(title: "Error", message: "Failed to initialize camera.", preferredStyle: .alert)
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

//==========================================================================================================================================================
// MARK:                                                    Dummy data
//==========================================================================================================================================================
extension ViewController
{
    public class func getDummyAnnotations(centerLatitude: Double, centerLongitude: Double, deltaLat: Double, deltaLon: Double, altitudeDelta: Double, count: Int) -> Array<ARAnnotation>
    {
        var annotations: [ARAnnotation] = []
        
        srand48(2)
        for i in stride(from: 0, to: count, by: 1)
        {
            let location = self.getRandomLocation(centerLatitude: centerLatitude, centerLongitude: centerLongitude, deltaLat: deltaLat, deltaLon: deltaLon, altitudeDelta: altitudeDelta)

            if let annotation = TestAnnotation(identifier: nil, title: "POI \(i)", location: location, type: TestAnnotationType.allCases.randomElement()!)
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
}
