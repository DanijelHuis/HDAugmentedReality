# HDAugmentedReality

Augmented Reality component for iOS, written in Swift 3.0.

Version history:
- 1.1.x: written in Swift 3.0, iOS 8+
- 1.0.x: written in Swift 2.0, iOS 7+
- 0.1.0: written in Swift 1.2, iOS 7+

## Description

HDAugmentedReality is designed to be used in areas with large concentration of POIs where
primary goal is the visibility of all POIs. This is achieved by stacking POIs vertically, meaning
that farther POIs that are obscured by nearer POIs are put higher, above the POIs that obscures them. 
Altitudes of POIs are disregarded.

## Features

- Automatic vertical stacking of annotations views
- Tracks user movement and updates visible annotations
- Fully customisable annotation views
- Smooth POI movement
- Works on all iOS devices(with GPS) and supports all rotations
- Works with large amount of annotations and on-screen annotation views
- Easy debugging with map controller
- Simple and easy to use

## Dependencies & Requirements

- CoreLocation.Framework
- CoreMotion.Framework
- MapKit.Framework (For debugging only, can be set ‘Optional’)

Xcode 8 is needed for Swift 3.

## Manual installation

- Drag & drop HDAugmentedReality folder from demo project into your project.
- Add native frameworks listed in “Dependencies & Requirements”
- Add NSLocationWhenInUseUsageDescription to Info.plist. This is needed for location authorization.
- Add NSCameraUsageDescription to Info.plist. This is needed for camera authorization.

## CocoaPods

- Add NSLocationWhenInUseUsageDescription to Info.plist. This is needed for location authorization.
- Add NSCameraUsageDescription to Info.plist. This is needed for camera authorization.
- Add this two lines to your podfile: 
```bash
use_frameworks!
pod 'HDAugmentedReality', :git => 'https://github.com/DanijelHuis/HDAugmentedReality.git'
```

## How to use
Setup controller and provide annotations:
```swift
let arViewController = ARViewController()
arViewController.dataSource = self
arViewController.maxDistance = 0
arViewController.maxVisibleAnnotations = 100
arViewController.maxVerticalLevel = 5
arViewController.headingSmoothingFactor = 0.05
arViewController.trackingManager.userDistanceFilter = 25
arViewController.trackingManager.reloadDistanceFilter = 75
arViewController.setAnnotations(dummyAnnotations)
arViewController.uiOptions.debugEnabled = true
arViewController.uiOptions.closeButtonEnabled = true
//arViewController.interfaceOrientationMask = .landscape
arViewController.onDidFailToFindLocation =
{
    [weak self, weak arViewController] elapsedSeconds, acquiredLocationBefore in
    // Show alert and dismiss
}
self.present(arViewController, animated: true, completion: nil)
```
Implement ARDataSource and provide annotation views:
```swift
func ar(arViewController: ARViewController, viewForAnnotation: ARAnnotation) -> ARAnnotationView
{
    // Annotation views should be lightweight views, try to avoid xibs and autolayout all together.
    var annotationView = TestAnnotationView()
    annotationView.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.5)
    annotationView.frame = CGRect(x: 0,y: 0,width: 150,height: 50)
    return annotationView;
}
```
Annotation views must subclass ARAnnotationView. Override bindUi method inside your custom annotation view to set your UI.

Make sure NSLocationWhenInUseUsageDescription and NSCameraUsageDescription are added to your Info.plist file.

# License 

HDAugmentedReality is released under the MIT license. See LICENSE for details.
