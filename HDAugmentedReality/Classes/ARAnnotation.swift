//
//  ARAnnotation.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 23/04/15.
//  Copyright (c) 2015 Danijel Huis. All rights reserved.
//

import UIKit
import CoreLocation

/// Defines POI with title and location.
open class ARAnnotation: NSObject
{
    /// Identifier of annotation, not used by HDAugmentedReality internally.
    open var identifier: String?
    
    /// Title of annotation, can be used in ARAnnotationView
    open var title: String?
    
    /// Location of the annotation, it is guaranteed to be valid location(coordinate). It is set in init or by validateAndSetLocation.
    private(set) open var location: CLLocation
    
    /// View for annotation. It is set inside ARPresenter after fetching view from dataSource.
    internal(set) open var annotationView: ARAnnotationView?
    
    // Internal use only, do not set this properties
    internal(set) open var distanceFromUser: Double = 0
    internal(set) open var azimuth: Double = 0
    internal(set) open var active: Bool = false
    
    /**
     Returns annotation if location(coordinate) is valid.
    */
    init?(identifier: String?, title: String?, location: CLLocation)
    {
        guard CLLocationCoordinate2DIsValid(location.coordinate) else { return nil }
        
        self.identifier = identifier
        self.title = title
        self.location = location
    }
    
    /// Validates location.coordinate and sets it.
    func validateAndSetLocation(location: CLLocation) -> Bool
    {
        guard CLLocationCoordinate2DIsValid(location.coordinate) else { return false }
        
        self.location = location
        return true
    }
}
