# HDAugmentedReality

Augmented Reality component for iOS, written in Swift 2.0.
Note: Version 0.1.0 was written in Swift 1.2 so use that for older Xcodes.

## Features

- Fully customisable annotation views
- Automatic vertical stacking of annotations views
- Tracks user movement and updates visible annotations
- Works on all iOS devices(with GPS) and supports all rotations
- Works with large amount of annotations and on-screen annotation views
- iOS 7+
- Easy debugging with map controller
- Simple and easy to use

## Dependencies & Requirements

- CoreLocation.Framework
- CoreMotion.Framework
- MapKit.Framework (For debugging only, can be set ‘Optional’)

Xcode 6.3 is needed for Swift 1.2.

## Manual installation (iOS7+)

- Drag & drop HDAugmentedReality folder from demo project into your project.
- Add native frameworks listed in “Dependencies & Requirements”
- iOS 8: Add NSLocationWhenInUseUsageDescription to Info.plist. This is needed for location authorization.

## CocoaPods (iOS8+)

- Works only on iOS8+ because swift pod is built as dynamic framework and dynamic frameworks don't work on iOS7
- iOS 8: Add NSLocationWhenInUseUsageDescription to Info.plist. This is needed for location authorization.
- Add this two lines to your podfile: 
```bash
use_frameworks!
pod 'HDAugmentedReality', :git => 'https://github.com/DanijelHuis/HDAugmentedReality.git'
```

## How to use
Setup controller and provide annotations:
```swift
var arViewController = ARViewController()
arViewController.debugEnabled = true
arViewController.dataSource = self
arViewController.maxDistance = 0
arViewController.maxVisibleAnnotations = 100
arViewController.maxVerticalLevel = 5
arViewController.trackingManager.userDistanceFilter = 25
arViewController.trackingManager.reloadDistanceFilter = 75

arViewController.setAnnotations(dummyAnnotations)
self.presentViewController(arViewController, animated: true, completion: nil)
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

Make sure NSLocationWhenInUseUsageDescription is added to your Info.plist file.

# License 

HDAugmentedReality is released under the MIT license. See LICENSE for details.