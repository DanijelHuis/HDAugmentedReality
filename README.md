[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/HDAugmentedReality.svg)](https://cocoapods.org/pods/HDAugmentedReality)

# HDAugmentedReality

Augmented Reality component for iOS.

## Description

HDAugmentedReality is designed to be used in areas with large concentration of static POIs where
primary goal is the visibility of all POIs. This is achieved by stacking POIs vertically, meaning
that farther POIs, ones that would normally be obscured by nearer POIs, are put higher. 
Altitudes of POIs are disregarded.

## Features

- Automatic vertical stacking of annotations views
- Tracks user movement and updates visible annotations
- Fully customisable annotation views
- Smooth POI movement
- Works on all iOS devices(with GPS) and supports all rotations
- Works with large amount of annotations and on-screen annotation views
- Simulator debugging and debugging with map controller
- Radar with map and out-of-bounds indicators
- Configurable vertical offset by distance

## What is next?
- Notify ARAnnotationView when device is targeting it (Focus mode). This could be used as alternative to stacking or used with it. Similar feature can be seen in Flightradar app.


## Plist
- Add NSLocationWhenInUseUsageDescription. This is needed for location authorization.
- Add NSCameraUsageDescription. This is needed for camera authorization.
- Optional: Add UIRequiredDeviceCapabilities (array) and add "gyroscope", "accelerometer", "gps" and "location-services" values.

## CocoaPods
- Setup your podfile: 
```bash
platform :ios, '10.0'
use_frameworks!
 
target "TargetName" do
pod 'HDAugmentedReality', '~> 3.0'
end
 ```

## Basic usage
Look at the demo project for a complete example.
  
Import
```swift
import HDAugmentedReality
```
  
Create annotations.
```swift
let annotation1 = ARAnnotation(identifier: "bakery", title: "Bakery", location: CLLocation(latitude: 45.13432, longitude: 18.62095))
let annotation2 = ARAnnotation(identifier: "supermarket", title: "Supermarket", location: CLLocation(latitude: 45.84638, longitude: 18.84610))
let annotation3 = ARAnnotation(identifier: "home", title: "Home", location: CLLocation(latitude: 45.23432, longitude: 18.65436))
let dummyAnnotations = [annotation1, annotation2, annotation3].compactMap{ $0 }
```
  
Create ARViewController and configure ARPresenter.
```swift
// Creating ARViewController. You can use ARViewController(nibName:bundle:) if you have custom xib.
let arViewController = ARViewController()

// Presenter - handles visual presentation of annotations
let presenter = arViewController.presenter!
presenter.presenterTransform = ARPresenterStackTransform()

arViewController.dataSource = self
arViewController.setAnnotations(dummyAnnotations)
self.present(arViewController, animated: true, completion: nil)
```
  
Implement ARDataSource and provide annotation view. This will be called for each annotation.  
```swift
func ar(_ arViewController: ARViewController, viewForAnnotation: ARAnnotation) -> ARAnnotationView
{
// Annotation views should be lightweight views, try to avoid xibs and autolayout all together.
let annotationView = TestAnnotationView()
annotationView.frame = CGRect(x: 0,y: 0,width: 150,height: 50)
return annotationView;
}
```
## Customization

### Annotation customization
You can subclass ARAnnotation and add your properties if you have the need (Look at TestAnnotation in the demo project).

### AnnotationView customization/subclass
ARAnnotationView is just an empty view, you should subclass it and add your UI (labels, background etc.). Try to avoid xibs and constraints
since they impact performance (keep in mind that you can have hundreds of these on screen). For example take a look at TestAnnotationView in
the demo project.

ARAnnotationView has annotation property that holds annotation that you created. So if you subclassed ARAnnotation then this subclass instances
would be passed to ARAnnotationView.

Subclassing:
- override initialize method to create your UI and init other stuff.
- bindUi method is called when distance to the user or bearing changes. Override it to refresh your UI if you want that info.

### ARViewController customization
Custom XIB  
You can copy ARViewController.xib to your project, rename and edit it however you like and provide xib name to ARViewController(nibName:"MyARViewController", bundle: nil).

Adjust vertical offset by distance.
```swift
let presenter = arViewController.presenter!
presenter.distanceOffsetMode = .manual
presenter.distanceOffsetMultiplier = 0.1   // Pixels per meter
presenter.distanceOffsetMinThreshold = 500 // Tell it to not raise annotations that are nearer than this
```
  
Limit number of annotations shown by count and distance.
```swift
presenter.maxDistance = 5000               // Don't show annotations if they are farther than this
presenter.maxVisibleAnnotations = 100      // Max number of annotations on the screen
```
  
Adjust location tracking precision and heading/pitch movement.
```swift
let trackingManager = arViewController.trackingManager
trackingManager.userDistanceFilter = 15     // How often are distances and azimuths recalculated (in meters)
trackingManager.reloadDistanceFilter = 50   // How often are new annotations fetched (in meters)
trackingManager.filterFactor = 0.4          // Smoothing out the movement of annotation views
trackingManager.minimumTimeBetweenLocationUpdates = 2   // Minimum time between location updates
```

## Radar
You can add radar with MKMapView and indicator ring. Please note that adding radar, and especially if radar.indicatorRingType is .precise, will significantly increase battery consumption.
```swift
let radar = RadarMapView()
radar.startMode = .centerUser(span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
radar.trackingMode = .centerUserWhenNearBorder(span: nil)
radar.indicatorRingType = .segmented(segmentColor: nil, userSegmentColor: nil)
radar.maxDistance = 5000    // Limit bcs it drains battery if lots of annotations (>200), especially if indicatorRingType is .precise
arViewController.addAccessory(radar, leading: 15, trailing: nil, top: nil, bottom: 15 + safeArea.bottom / 4, width: nil, height: 150)
```

## Custom accessories
You can make your accessories and use it with ARViewController. RadarMapView is an example of such accessory.
In order to make accessory you must implement ARAccessory protocol  (single method) and call ARViewController.addAccessory(...) or attach it from xib using accessoriesOutlet.

## Custom presenter
If you don't like how annotation view are shown or positioned on screen, you can make your ARPresenter subclass and set it to ARViewController.presenter property.

## Known issues
- ARTrackingManager has property headingSource which is by default set to .coreLocation. That means that heading will be taken from CLLocationManager and it is not as smooth as when taken from CMDeviceMotion. If you set headingSource to .deviceMotion, it will use heading from CMDeviceMotion and it will be smoother but, for some reason, this value is inaccurate when travelling fast e.g. driving in a car or bus.
- Heading is reversed/not compensated when pitch > 135°. This can be observed in native Compass app: Start with iphone lying on the ground with screen pointing toward the sky (pitch = 0), now rotate iphone around its x axis (axes link below). Once you rotate more than 135 degrees, heading will jump, this jump is different depending where your device is heading. I fixed this but you need to set ARTrackingManager.headingSource = .deviceMotion which has its problems (read above).

Axes: https://developer.apple.com/documentation/coremotion/getting_processed_device-motion_data/understanding_reference_frames_and_device_attitude
## Components
**ARTrackingManager**: Class used internally by ARViewController for tracking and filtering location/heading/pitch etc. ARViewController takes all these informations and stores them in ARViewController.arStatus object, which is then passed to ARPresenter. This class is not intended for subclassing.

**ARPresenter**: Handles creation of annotation views and layouts them on the screen. Before anything is done, it first filters annotations by distance and count for improved performance. This class is also responsible for vertical stacking of the annotation views. It can be subclassed if custom positioning is needed, e.g. if you wan't to position annotations relative to its altitudes you would subclass ARPresenter and override xPositionForAnnotationView and yPositionForAnnotationView.

**ARViewController**: Glues everything together. Presents camera with ARPresenter above it. Takes all needed input from ARTrackingManager and passes it to ARPresenter.

**ARAnnotation**: Serves as the source of information(location, title etc.) about a single annotation. Annotation objects do not provide the visual representation of the annotation. It is analogue to MKAnnotation. It can be subclassed if additional information for some annotation is needed. 

**ARAnnotationView**: Responsible for presenting annotations visually. Analogue to MKAnnotationView. It is usually subclassed to provide custom look.

**ARStatus**: Structure that holds all information about screen(FOV),  device(location/heading/pitch) and all other informations important for layout of annotation views on the screen.

## Version history:
- 3.0.0: written in swift 5, iOS 10+
- 2.4.0: written in swift 4.2, iOS 8+
- 2.3.0: written in swift 4.0, iOS 8+
- 2.0.0: written in swift 3.0, iOS 8+
- 1.1.x: written in Swift 3.0, iOS 8+
- 1.0.x: written in Swift 2.0, iOS 7+
- 0.1.0: written in Swift 1.2, iOS 7+

## License 

HDAugmentedReality is released under the MIT license. See LICENSE for details.
