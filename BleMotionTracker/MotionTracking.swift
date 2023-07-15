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
    // -------------------------------------------------------------------------------------------------
    var motionManager        : CMMotionManager?
    
    var updateCounter        : UInt32     = 0
    var updateRate           : UInt8      = 60
    var headingOffset        : simd_quatd = simd_quatd( ix: 0, iy: 0, iz: 0, r: 1)
    
    // -------------------------------------------------------------------------------------------------
    var delegate : MotionTrackingDelegate?

    // -------------------------------------------------------------------------------------------------
    override init()
    {
        super.init()
        motionManager = CMMotionManager()
    }
    
    // -------------------------------------------------------------------------------------------------
    func disable()
    {
        motionManager?.stopDeviceMotionUpdates()
        motionManager = nil
        delegate = nil
    }
    
    // -------------------------------------------------------------------------------------------------
    func startMeasuring()
    {
        motionManager?.startDeviceMotionUpdates( using: .xArbitraryCorrectedZVertical )
        
        motionManager?.deviceMotionUpdateInterval = 1.0/Double(updateRate)
        updateCounter = 0

        motionManager!.startDeviceMotionUpdates(
            to: OperationQueue.current!, withHandler:
            {
                (deviceMotion, error) -> Void in

                if( error == nil )
                {
                    self.deviceMotionUpdate()
                }
                else
                {
                    print("ERROR: motion update error: \(error!.localizedDescription)")
                }
            })
    }
    
    // -------------------------------------------------------------------------------------------------
    @objc func deviceMotionUpdate()
    {
        guard let data : CMDeviceMotion = motionManager?.deviceMotion
        else
        {
            return
        }

        let currentTimestamp = Double(updateCounter) / Double(updateRate)
        updateCounter += 1
                        
        let timestamp = UInt32((UInt64(currentTimestamp*1000000)) % UInt64(UInt32.max))

        let q : CMQuaternion = data.attitude.quaternion
        let orientation  = simd_mul( headingOffset, simd_quatd( ix: q.x, iy: q.y, iz: q.z, r: q.w ) )
        
        let a : CMAcceleration = data.userAcceleration
        let acceleration = simd_double3( x:a.x, y:a.y, z:a.z)
        
        delegate?.measurementUpdate( timestamp: timestamp,
                                     orientation: orientation,
                                     acceleration: acceleration )
    }
    
    // -------------------------------------------------------------------------------------------------
    func stopMeasuring()
    {
        motionManager?.stopDeviceMotionUpdates()
    }
    
    // -------------------------------------------------------------------------------------------------
    func calculateHeadingOffset()
    {
        if let yaw = motionManager?.deviceMotion!.attitude.yaw
        {
            headingOffset = simd_quaternion( -yaw, z_axis )
        }
    }
    
}
