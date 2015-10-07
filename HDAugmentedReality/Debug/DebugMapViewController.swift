//
//  MapViewController.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 20/06/15.
//  Copyright (c) 2015 Danijel Huis. All rights reserved.
//

import UIKit
import MapKit

/// Called from ARViewController for debugging purposes
public class DebugMapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate
{
    @IBOutlet weak var mapView: MKMapView!
    private var annotations: [ARAnnotation]?
    private var locationManager = CLLocationManager()
    private var heading: Double = 0
    private var interactionInProgress = false
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?)
    {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required public init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
    }
    
    public override func viewDidLoad()
    {
        super.viewDidLoad()
        self.mapView.rotateEnabled = false
        
        if let annotations = self.annotations
        {
            addAnnotationsOnMap(annotations)
        }
        locationManager.delegate = self
    }
    
    public override func viewDidAppear(animated: Bool)
    {
        super.viewDidAppear(animated)
        locationManager.startUpdatingHeading()
    }
    
    public override func viewDidDisappear(animated: Bool)
    {
        super.viewDidDisappear(animated)
        locationManager.stopUpdatingHeading()
    }

    
    public func addAnnotations(annotations: [ARAnnotation])
    {
        self.annotations = annotations
        
        if self.isViewLoaded()
        {
            addAnnotationsOnMap(annotations)
        }
    }
    
    private func addAnnotationsOnMap(annotations: [ARAnnotation])
    {
        var mapAnnotations: [MKPointAnnotation] = []
        for annotation in annotations
        {
            if let coordinate = annotation.location?.coordinate
            {
                let mapAnnotation = MKPointAnnotation()
                mapAnnotation.coordinate = coordinate
                let text = String(format: "%@, AZ: %.0f, VL: %i, %.0fm", annotation.title != nil ? annotation.title! : "", annotation.azimuth, annotation.verticalLevel, annotation.distanceFromUser)
                mapAnnotation.title = text
                mapAnnotations.append(mapAnnotation)
            }
        }
        mapView.addAnnotations(mapAnnotations)
        mapView.showAnnotations(mapAnnotations, animated: false)
    }
    
    
    @IBAction func longTap(sender: UILongPressGestureRecognizer)
    {
        if sender.state == UIGestureRecognizerState.Began
        {
            let point = sender.locationInView(self.mapView)
            let coordinate = self.mapView.convertPoint(point, toCoordinateFromView: self.mapView)
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let userInfo: [NSObject : AnyObject] = ["location" : location]
            NSNotificationCenter.defaultCenter().postNotificationName("kNotificationLocationSet", object: nil, userInfo: userInfo)
        }
    }
    
    @IBAction func closeButtonTap(sender: AnyObject)
    {
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    
    public func locationManager(manager: CLLocationManager, didUpdateHeading newHeading: CLHeading)
    {
        heading = newHeading.trueHeading
        
        // Rotate map
        if(!self.interactionInProgress && CLLocationCoordinate2DIsValid(mapView.centerCoordinate))
        {
            let camera = mapView.camera.copy() as! MKMapCamera
            camera.heading = CLLocationDirection(heading);
            self.mapView.setCamera(camera, animated: false)
        }
    }
    
    public func mapView(mapView: MKMapView, regionWillChangeAnimated animated: Bool)
    {
        self.interactionInProgress = true
    }
    
    public func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool)
    {
        self.interactionInProgress = false
    }
}
