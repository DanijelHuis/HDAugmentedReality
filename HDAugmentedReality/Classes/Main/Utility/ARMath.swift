import CoreLocation
import UIKit
import Foundation
import CoreMotion
import simd


public class ARMath
{
    /**
     Normalizes degree to 0-360
     */
    public static func normalizeDegree(_ degree: Double) -> Double
    {
        var degreeNormalized = fmod(degree, 360)
        if degreeNormalized < 0
        {
            degreeNormalized = 360 + degreeNormalized
        }
        return degreeNormalized
    }
    
    /**
     Normalizes degree to 0...180, 0...-180
     */
    public static func normalizeDegree2(_ degree: Double) -> Double
    {
        var degreeNormalized = fmod(degree, 360)
        if degreeNormalized > 180
        {
            degreeNormalized -= 360
        }
        else if degreeNormalized < -180
        {
            degreeNormalized += 360
        }
        
        return degreeNormalized
    }
    
    /**
     Finds shortes angle distance between two angles. Angles must be normalized(0-360)
    */
    public static func deltaAngle(_ angle1: Double, _ angle2: Double) -> Double
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
    
    /**
     Simple exponential smoothing (https://en.wikipedia.org/wiki/Exponential_smoothing).
     Formula: filteredValue = newValue * filterFactor + previousValue * (1.0 -  filterFactor)
     
     - Parameter isCircular           Set to true if working with circular values, e.g. 0-360 degrees. See explanation.
     
     == Explanation
     Filtering on circular values (e.g. 0-360) cannot be done by using regular formula because there would be issues near border (0/360). Best explained with example:
     previousValue = 350
     newValue = 10
     filterFactor = 0.5
     filteredValue = 10 * 0.5 + 350 * (1 - 0.5) = 180     NOT OK - IT SHOULD BE 0
     
     First solution is to modify values so that instead of passing 10 to the formula, we pass 370.
     Second solution is to not use 0-360 degrees but to express values with sine and cosine.
     
     == Second solution
     let newHeadingRad = degreesToRadians(newHeading)
     self.filteredHeadingSin = sin(newHeadingRad) * headingFilterFactor + self.filteredHeadingSin * (1 - headingFilterFactor)
     self.filteredHeadingCos = cos(newHeadingRad) * headingFilterFactor + self.filteredHeadingCos * (1 - headingFilterFactor)
     self.filteredHeading = radiansToDegrees(atan2(self.filteredHeadingSin, self.filteredHeadingCos))
     self.filteredHeading = ARMath.normalizeDegree(self.filteredHeading)
     */
    public static func exponentialFilter(_ newValue: Double, previousValue: Double, filterFactor: Double, isCircular: Bool) -> Double
    {
        guard filterFactor < 1.0 else { return newValue }
        
        var newValue = newValue
        if isCircular
        {
            if fabs(newValue - previousValue) > 180
            {
                if previousValue < 180 && newValue > 180
                {
                    newValue -= 360
                }
                else if previousValue > 180 && newValue < 180
                {
                    newValue += 360
                }
            }
        }
        
        let filteredValue = (newValue * filterFactor) + (previousValue  * (1.0 - filterFactor))
        return filteredValue
    }
    
    /**
     Calculates bearing between userLocation and location.
     */
    public static func bearingFromUserToLocation(userLocation: CLLocation, location: CLLocation, approximate: Bool = false) -> Double
    {
        var bearing: Double = 0
        
        if approximate
        {
            bearing = self.approximateBearingBetween(startLocation: userLocation, endLocation: location)
        }
        else
        {
            bearing = self.bearingBetween(startLocation: userLocation, endLocation: location)
        }
        
        return bearing;
    }
    
    /**
     Precise bearing between two points.
     */
    public static func bearingBetween(startLocation : CLLocation, endLocation : CLLocation) -> Double
    {
        var bearing: Double = 0
        
        let lat1 = startLocation.coordinate.latitude.toRadians
        let lon1 = startLocation.coordinate.longitude.toRadians
        
        let lat2 = endLocation.coordinate.latitude.toRadians
        let lon2 = endLocation.coordinate.longitude.toRadians
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)
        bearing = radiansBearing.toDegrees
        if(bearing < 0) { bearing += 360 }
        
        return bearing
    }
    
    /**
     Approximate bearing between two points, good for small distances(<10km).
     This is 30% faster than bearingBetween but it is not as precise. Error is about 1 degree on 10km, 5 degrees on 300km, depends on location...
     
     It uses formula for flat surface and multiplies it with LAT_LON_FACTOR which "simulates" earth curvature.
     */
    public static func approximateBearingBetween(startLocation: CLLocation, endLocation: CLLocation) -> Double
    {
        var bearing: Double = 0
        
        let startCoordinate: CLLocationCoordinate2D = startLocation.coordinate
        let endCoordinate: CLLocationCoordinate2D = endLocation.coordinate
        
        let latitudeDistance: Double = startCoordinate.latitude - endCoordinate.latitude;
        let longitudeDistance: Double = startCoordinate.longitude - endCoordinate.longitude;
        
        bearing = (atan2(longitudeDistance, (latitudeDistance * Double(LAT_LON_FACTOR)))).toDegrees
        bearing += 180.0
        
        return bearing
    }
    
    /// Pitch. -90(looking down), 0(looking straight), 90(looking up)
    public static func calculatePitch(gravity: simd_double3, deviceOrientation: CLDeviceOrientation) -> Double
    {
        // Calculate pitch
        var pitch: Double = 0
        if deviceOrientation == CLDeviceOrientation.portraitUpsideDown { pitch = atan2(-gravity.y, gravity.z) }
        else if deviceOrientation == CLDeviceOrientation.landscapeLeft { pitch = atan2(gravity.x, gravity.z) }
        else if deviceOrientation == CLDeviceOrientation.landscapeRight { pitch = atan2(-gravity.x, gravity.z) }
        else { pitch = atan2(gravity.y, gravity.z) }
        
        // Set pitch angle so that it suits us (0 = looking straight)
        pitch = pitch.toDegrees
        pitch += 90
        // Not really needed but, if pointing device down it will return 0...-30...-60...270...240 but like this it returns 0...-30...-60...-90...-120
        if(pitch > 180) { pitch -= 360 }
        
        return pitch
    }
    
    /**
     Calculates heading from attitude and pitch (pitch can be calculated from gravity).
     This is used because of two reasons:
     1) deviceMotion.heading doesn't work when pitch > 135.
        Same effect can be observerd in Compass app: Start with iphone lying on the ground with screen pointing toward the sky (pitch = 0), now rotate iphone around its x axis (axes link below). Once you
        rotate more than 135 degrees, heading will jump.
     2) deviceMotion.heading is very sensitivie to tilt (rotation around iphone's z value). To test it, set iphone to be perpendicular to the ground (screen to the face), now rotate it around its z axis, heading will change.
     
     iphone axes: https://developer.apple.com/documentation/coremotion/getting_processed_device-motion_data/understanding_reference_frames_and_device_attitude
     */
    public static func calculateHeading(attitude: simd_quatd, pitch: Double, deviceOrientation: CLDeviceOrientation) -> Double
    {
        /**
         1) Determine device's local up and right vector when in reference position (not rotated).
         */
        var upVector: simd_double3
        var rightVector: simd_double3
        if deviceOrientation == .portraitUpsideDown { upVector = simd_double3(0,-1,0); rightVector = simd_double3(-1,0,0); }
        else if deviceOrientation == .landscapeLeft{ upVector = simd_double3(1,0,0); rightVector = simd_double3(0,-1,0); }
        else if deviceOrientation == .landscapeRight { upVector = simd_double3(-1,0,0); rightVector = simd_double3(0,1,0); }
        else { upVector = simd_double3(0,1,0); rightVector = simd_double3(1,0,0); }
        
        /**
         2) Calculate device's local up vector when device is rotated. To calculate it, take device's local up vector in reference position and rotate it by device's attitude.
         Do the same with right vector.
         */
        let deviceUpVector = attitude.act(upVector)
        let deviceRightVector = attitude.act(rightVector)
        
        /**
         3) Now rotate device's local up vector by -pitch around devices's local right vector. In other words - rotate device's local up vector to reference xy plane.
         Note: Pitch has to be 0 when device is lying flat on the ground with screen towards the sky. Pitch changes 0...360 as you rotate it around x axis (right hand rule).
         */
        let pitch = pitch + 90
        let rotationToHorizontalPlane = simd_quatd(angle: -pitch.toRadians, axis: deviceRightVector)
        let deviceDirectionHorizontalVector = rotationToHorizontalPlane.act(deviceUpVector)
        
        /**
         4) Calculate heading from deviceDirectionHorizontalVector.
         */
        var heading = atan2(deviceDirectionHorizontalVector.y, deviceDirectionHorizontalVector.x).toDegrees
        heading = 360 - ARMath.normalizeDegree(heading)
        
        return heading
    }
}

extension BinaryInteger
{
    public var toRadians: CGFloat { return CGFloat(Int(self)) * .pi / 180 }
    public var toDegrees: CGFloat { return CGFloat(Int(self)) * 180 / .pi }
}

extension FloatingPoint
{
    public var toRadians: Self { return self * .pi / 180 }
    public var toDegrees: Self { return self * 180 / .pi }
}


//==========================================================================================================================================================
// MARK:                                                    simd + CoreMotion
//==========================================================================================================================================================
extension simd_double3x3
{
    public init(_ rotationMatrix: CMRotationMatrix)
    {
        let columns =
            [
                simd_double3([rotationMatrix.m11, rotationMatrix.m12, rotationMatrix.m13]),
                simd_double3([rotationMatrix.m21, rotationMatrix.m22, rotationMatrix.m23]),
                simd_double3([rotationMatrix.m31, rotationMatrix.m32, rotationMatrix.m33])
        ]
        
        self.init(columns)
    }
}

extension simd_quatd
{
    public init(_ quaternion: CMQuaternion)
    {
        let vector = simd_double4(quaternion.x, quaternion.y, quaternion.z, quaternion.w)
        self.init(vector: vector)
    }
}

extension simd_double3
{
    public init(_ acceleration: CMAcceleration)
    {
        self.init(acceleration.x, acceleration.y, acceleration.z)
    }
    
    public init(_ rotationRate: CMRotationRate)
    {
        self.init(rotationRate.x, rotationRate.y, rotationRate.z)
    }
    
    public init(_ magneticField: CMMagneticField)
    {
        self.init(magneticField.x, magneticField.y, magneticField.z)
    }
}
