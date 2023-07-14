// ----------------------------------------------------------------------------
//  MotionTracking
// ----------------------------------------------------------------------------

import Foundation
import CoreMotion
import simd

// ----------------------------------------------------------------------------
let z_axis : simd_double3 = simd_double3(x:0, y:0, z:1)

// ----------------------------------------------------------------------------
protocol MotionTrackingDelegate : AnyObject
{
    func measurementUpdate( timestamp: UInt32, orientation: simd_quatd, acceleration: simd_double3 )
}

// ----------------------------------------------------------------------------
class MotionTracking : NSObject
{
    var motionManager        : CMMotionManager?

    var sampleTimer          : Timer?
    
    var orientation          : simd_quatd         = simd_quatd( ix: 0, iy: 0, iz: 0, r: 1)
    var acceleration         : simd_double3       = simd_double3()
    var startTimestamp       : TimeInterval       = CFAbsoluteTimeGetCurrent()
    var currentTimestamp     : TimeInterval       = CFAbsoluteTimeGetCurrent()
    var timestamp            : UInt32             = 0
    var updateRate           : UInt8              = 60
    var headingOffset        : simd_quatd         = simd_quatd( ix: 0, iy: 0, iz: 0, r: 1)
    
    var delegate             : MotionTrackingDelegate?

    // -------------------------------------------------------------------------------------------------
    override init()
    {
        super.init()
        initMotionManager()
    }
    
    // -------------------------------------------------------------------------------------------------
    func disable()
    {
        sampleTimer?.invalidate()
        motionManager = nil
    }
    
    // -------------------------------------------------------------------------------------------------
    func initMotionManager()
    {
        motionManager = CMMotionManager()
    }
    
    // -------------------------------------------------------------------------------------------------
    func startMeasuring()
    {
        motionManager!.startDeviceMotionUpdates( using: .xArbitraryCorrectedZVertical )
        sampleTimer = Timer.scheduledTimer( timeInterval: 1.0/Double(updateRate),
                                            target: self,
                                            selector: #selector(sampleTimerExpired),
                                            userInfo: nil, repeats: true )
    }
    
    // -------------------------------------------------------------------------------------------------
    @objc func sampleTimerExpired()
    {
        let data : CMDeviceMotion? = motionManager!.deviceMotion
        
        if data == nil { return }
        
        currentTimestamp = CFAbsoluteTimeGetCurrent() - startTimestamp
        
        timestamp = UInt32((UInt64(currentTimestamp*1000000)) % UInt64(UInt32.max))

        let q : CMQuaternion = data!.attitude.quaternion
        let a : CMAcceleration = data!.userAcceleration

        orientation = simd_mul( headingOffset, simd_quatd( ix: q.x, iy: q.y, iz: q.z, r: q.w ) )
        acceleration = simd_double3( x:a.x, y:a.y, z:a.z)
        
        delegate?.measurementUpdate( timestamp: timestamp,
                                     orientation: orientation,
                                     acceleration: acceleration )
    }
    
    // -------------------------------------------------------------------------------------------------
    func stopMeasuring()
    {
        if sampleTimer == nil { return }
        sampleTimer!.invalidate()
        motionManager!.stopDeviceMotionUpdates()
    }
    
    // -------------------------------------------------------------------------------------------------
    func calculateHeadingOffset()
    {
        let yaw = motionManager!.deviceMotion!.attitude.yaw
        headingOffset = simd_quaternion( -yaw, z_axis )
    }
    
}
