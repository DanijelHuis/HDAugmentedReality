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
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?)
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
        self.mapView.isRotateEnabled = false
        
        if let annotations = self.annotations
        {
            addAnnotationsOnMap(annotations)
        }
        locationManager.delegate = self
    }
    
    public override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        locationManager.startUpdatingHeading()
    }
    
    public override func viewDidDisappear(_ animated: Bool)
    {
        super.viewDidDisappear(animated)
        locationManager.stopUpdatingHeading()
    }

    
    public func addAnnotations(_ annotations: [ARAnnotation])
    {
        self.annotations = annotations
        
        if self.isViewLoaded()
        {
            addAnnotationsOnMap(annotations)
        }
    }
    
    private func addAnnotationsOnMap(_ annotations: [ARAnnotation])
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
    
    
    @IBAction func longTap(_ sender: UILongPressGestureRecognizer)
    {
        if sender.state == UIGestureRecognizerState.began
        {
            let point = sender.location(in: self.mapView)
            let coordinate = self.mapView.convert(point, toCoordinateFrom: self.mapView)
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let userInfo: [NSObject : AnyObject] = ["location" : location]
            NotificationCenter.default.post(name: Notification.Name(rawValue: "kNotificationLocationSet"), object: nil, userInfo: userInfo)
        }
    }
    
    @IBAction func closeButtonTap(_ sender: AnyObject)
    {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    
    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading)
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
    
    public func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool)
    {
        self.interactionInProgress = true
    }
    
    public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool)
    {
        self.interactionInProgress = false
    }
}
