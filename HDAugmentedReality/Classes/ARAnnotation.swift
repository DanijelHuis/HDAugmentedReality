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
public class ARAnnotation: NSObject
{
    /// Title of annotation
    public var title: String?
    /// Location of annotation
    public var location: CLLocation?
    /// View for annotation. It is set inside ARViewController after fetching view from dataSource.
    internal(set) public var annotationView: ARAnnotationView?
    
    // Internal use only, do not set this properties
    internal var distanceFromUser: Double = 0
    internal var azimuth: Double = 0
    internal var verticalLevel: Int = 0
    internal var active: Bool = false

}
