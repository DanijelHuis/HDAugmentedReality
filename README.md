[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/HDAugmentedReality.svg)](https://cocoapods.org/pods/HDAugmentedReality)

# HDAugmentedReality

Augmented Reality component for iOS, written in Swift 3.0.

Version history:
- 2.0.0: written in swift 3.0, iOS 8+
- 1.1.x: written in Swift 3.0, iOS 8+
- 1.0.x: written in Swift 2.0, iOS 7+
- 0.1.0: written in Swift 1.2, iOS 7+

## Description

HDAugmentedReality is designed to be used in areas with large concentration of static POIs where
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
- Simulator debugging and debugging with map controller
- Configurable vertical offset by distance

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
platform :ios, '8.0'
use_frameworks!
 
target "TargetName" do
pod 'HDAugmentedReality', '~> 2.0'
end
 ```

## How to use
Import
```swift
import HDAugmentedReality
```
Setup controller and provide annotations:
```swift
let arViewController = ARViewController()
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
// Show alert and dismiss
}

// Setting annotations
arViewController.setAnnotations(dummyAnnotations)
// Presenting controller
self.present(arViewController, animated: true, completion: nil)
```
Implement ARDataSource and provide annotation views:
```swift
func ar(_ arViewController: ARViewController, viewForAnnotation: ARAnnotation) -> ARAnnotationView
{
// Annotation views should be lightweight views, try to avoid xibs and autolayout all together.
let annotationView = TestAnnotationView()
annotationView.frame = CGRect(x: 0,y: 0,width: 150,height: 50)
return annotationView;
}

```
Annotation views must subclass ARAnnotationView. Override bindUi method inside your custom annotation view to set your UI.

Make sure NSLocationWhenInUseUsageDescription and NSCameraUsageDescription are added to your Info.plist file.

## Components
**ARTrackingManager**: Class used internally by ARViewController for tracking and filtering location/heading/pitch etc. ARViewController takes all these informations and stores them in ARViewController.arStatus object, which is then passed to ARPresenter. This class is not intended for subclassing.

**ARPresenter**: Handles creation of annotation views and layouts them on the screen. Before anything is done, it first filters annotations by distance and count for improved performance. This class is also responsible for vertical stacking of the annotation views. It can be subclassed if custom positioning is needed, e.g. if you wan't to position annotations relative to its altitudes you would subclass ARPresenter and override xPositionForAnnotationView and yPositionForAnnotationView.

**ARViewController**: Glues everything together. Presents camera with ARPresenter above it. Takes all needed input from ARTrackingManager and passes it to ARPresenter.

**ARAnnotation**: Serves as the source of information(location, title etc.) about a single annotation. Annotation objects do not provide the visual representation of the annotation. It is analogue to MKAnnotation. It can be subclassed if additional information for some annotation is needed. 

**ARAnnotationView**: Responsible for presenting annotations visually. Analogue to MKAnnotationView. It is usually subclassed to provide custom look.

**ARStatus**: Structure that holds all information about screen(FOV),  device(location/heading/pitch) and all other informations important for layout of annotation views on the screen.

## License 

HDAugmentedReality is released under the MIT license. See LICENSE for details.
