import CoreLocation
import UIKit

let LAT_LON_FACTOR: CGFloat = 1.33975031663                      // Used in azimuzh calculation, don't change
let VERTICAL_SENS: CGFloat = 960
let H_PIXELS_PER_DEGREE: CGFloat = 14                            // How many pixels per degree
let OVERLAY_VIEW_WIDTH: CGFloat = 360 * H_PIXELS_PER_DEGREE      // 360 degrees x sensitivity

let MAX_VISIBLE_ANNOTATIONS: Int = 500                           // Do not change, can affect performance
let MAX_VERTICAL_LEVELS: Int = 10                                // Do not change, can affect performance

internal func radiansToDegrees(_ radians: Double) -> Double
{
    return (radians) * (180.0 / M_PI)
}

internal func degreesToRadians(_ degrees: Double) -> Double
{
    return (degrees) * (M_PI / 180.0)
}

/// Normalizes degree to 360
internal func normalizeDegree(_ degree: Double) -> Double
{
    var degreeNormalized = fmod(degree, 360)
    if degreeNormalized < 0
    {
        degreeNormalized = 360 + degreeNormalized
    }
    return degreeNormalized
}

/// Finds shortes angle distance between two angles. Angles must be normalized(0-360)
internal func deltaAngle(_ angle1: Double, angle2: Double) -> Double
{
    var deltaAngle = angle1 - angle2
    
    if deltaAngle > 180
    {
        deltaAngle -= 360
    }
    else if deltaAngle < -180
    {
        deltaAngle += 360
    }
    return deltaAngle
}

/// DataSource provides the ARViewController with the information needed to display annotations.
@objc public protocol ARDataSource : NSObjectProtocol
{
    /// Asks the data source to provide annotation view for annotation. Annotation view must be subclass of ARAnnotationView.
    func ar(_ arViewController: ARViewController, viewForAnnotation: ARAnnotation) -> ARAnnotationView
   
   /**
    *       READ BEFORE IMPLEMENTING
    *       ARViewController tracks user movement and shows/hides annotations accordingly. But if there is huge amount
    *       of annotations or for some other reason annotations cannot be set all at once, this method can be used to
    *       set annotations part by part.
    *
    *       Use ARViewController.trackingManager.reloadDistanceFilter to change how often this is called.
    *
    *       - parameter arViewController:        ARViewController instance
    *       - parameter location:                Current location of the user
    *       - returns:                       Annotations to load, previous annotations are removed
    */
    @objc optional func ar(_ arViewController: ARViewController, shouldReloadWithLocation location: CLLocation) -> [ARAnnotation]

}


