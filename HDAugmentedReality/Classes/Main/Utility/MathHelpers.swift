import CoreLocation
import UIKit
import Foundation
import CoreMotion
import simd

extension BinaryInteger
{
    var toRadians: CGFloat { return CGFloat(Int(self)) * .pi / 180 }
    var toDegrees: CGFloat { return CGFloat(Int(self)) * 180 / .pi }
}

extension FloatingPoint
{
    var toRadians: Self { return self * .pi / 180 }
    var toDegrees: Self { return self * 180 / .pi }
}

/// Normalizes degree to 0-360
internal func normalizeDegree(_ degree: Double) -> Double
{
    var degreeNormalized = fmod(degree, 360)
    if degreeNormalized < 0
    {
        degreeNormalized = 360 + degreeNormalized
    }
    return degreeNormalized
}

/// Normalizes degree to 0...180, 0...-180
internal func normalizeDegree2(_ degree: Double) -> Double
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

/// Finds shortes angle distance between two angles. Angles must be normalized(0-360)
internal func deltaAngle(_ angle1: Double, _ angle2: Double) -> Double
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
