import CoreLocation
import UIKit
import Foundation
import CoreMotion

let LAT_LON_FACTOR: CGFloat = 1.33975031663                      // Used in azimuzh calculation, don't change
let MAX_VISIBLE_ANNOTATIONS: Int = 500                           // Do not change, can affect performance

/// DataSource provides the ARViewController with the information needed to display annotations.
@objc public protocol ARDataSource : NSObjectProtocol
{
    /// Asks the data source to provide annotation view for annotation. Annotation view must be subclass of ARAnnotationView.
    func ar(_ arViewController: ARViewController, viewForAnnotation annotation: ARAnnotation) -> ARAnnotationView
    
    /// Called when some error occurs. Currently it is thrown only when camera fails to initialize.
    @objc optional func ar(_ arViewController: ARViewController, didFailWithError error: Error)
   
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

/**
 Holds all location and device related information
 */
public struct ARStatus
{
    /// Horizontal field of view od device. Changes when device rotates(hFov becomes vFov).
    public var hFov: Double = 0
    /// Vertical field of view od device. Changes when device rotates(vFov becomes hFov).
    public var vFov: Double = 0
    /// How much pixels(logical) on screen is 1 degree, horizontally.
    public var hPixelsPerDegree: Double = 0
    /// How much pixels(logical) on screen is 1 degree, vertically.
    public var vPixelsPerDegree: Double = 0
    /// Heading of the device, 0-360.
    public var heading: Double = 0
    /// Pitch of the device, device pointing straight = 0, up(upper edge tilted toward user) = 90, down = -90.
    public var pitch: Double = 0
    /// Last known location of the user.
    public var userLocation: CLLocation?
    
    /// True if all properties have been set.
    public var ready: Bool
    {
        get
        {
            let hFovOK = hFov > 0
            let vFovOK = vFov > 0
            let hPixelsPerDegreeOK = hPixelsPerDegree > 0
            let vPixelsPerDegreeOK = vPixelsPerDegree > 0
            let headingOK = heading != 0
            let pitchOK = pitch != 0
            let userLocationOK = self.userLocation != nil && CLLocationCoordinate2DIsValid(self.userLocation!.coordinate)

            return hFovOK && vFovOK && hPixelsPerDegreeOK && vPixelsPerDegreeOK && headingOK && pitchOK && userLocationOK
        }
    }
}

public struct Platform
{
    public static let isSimulator: Bool =
    {
        var isSim = false
        #if arch(i386) || arch(x86_64)
            isSim = true
        #endif
        return isSim
    }()
}
