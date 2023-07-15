// ----------------------------------------------------------------------------
//  MotionRecorder
// ----------------------------------------------------------------------------

import Foundation
import simd

// ----------------------------------------------------------------------------
struct Measurement
{
    var timestamp    : TimeInterval
    var orientation  : simd_quatd
    var acceleration : simd_double3
    var buttonId     : UInt8
}

// ----------------------------------------------------------------------------
let datalogFilename = "data_log.csv"

// ----------------------------------------------------------------------------
protocol MotionRecorderDelegate : AnyObject
{
    func samplesUpdate( numSamples: Int )
    func recordingStopped()
}

// ----------------------------------------------------------------------------
class MotionRecorder : NSObject, MotionTrackingDelegate
{
    var measurements   : [Measurement] = []
    var motionTracking : MotionTracking?
    var delegate       : MotionRecorderDelegate?
    
    var buttonId       : UInt8 = 0
    
    // ----------------------------------------------------------------------------
    override init()
    {
        super.init()
        motionTracking = MotionTracking()
        motionTracking?.delegate = self
    }
    
    // ----------------------------------------------------------------------------
    func disable()
    {
        stopMotionTracking()
        motionTracking?.disable()
        motionTracking = nil
    }
    
    // -------------------------------------------------------------------------------------------------
    func startMotionTracking()
    {
        motionTracking?.startMeasuring()
    }
    
    // -------------------------------------------------------------------------------------------------
    func stopMotionTracking()
    {
        motionTracking?.stopMeasuring()
    }
    
    // ----------------------------------------------------------------------------
    func startRecording()
    {
        measurements = []
        startMotionTracking()
    }
    
    // ----------------------------------------------------------------------------
    func stopRecording()
    {
        stopMotionTracking()
        writeCsvToFile()
    }
    
    // ----------------------------------------------------------------------------
    func writeCsvToFile()
    {
        let csvString = getCsvString()
        
        let fileManager = FileManager.default
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            
        let fileURL = dir.appendingPathComponent(datalogFilename)
                
        do
        {
            try csvString.write(to: fileURL, atomically: false, encoding: .utf8)
            NotificationCenter.default.post( name: Notification.Name("Changed files csv"), object: nil)
        }
        catch
        {
            print( "ERROR: failed to write data-log file!" )
        }
    }
    
    // ----------------------------------------------------------------------------
    func setUpdateRate( updateRate: UInt8 )
    {
        motionTracking?.updateRate = updateRate
    }
    
    // ----------------------------------------------------------------------------
    func buttonPressed( buttonId: UInt8 )
    {
        self.buttonId = buttonId
    }
    
    // ----------------------------------------------------------------------------
    func clearRecording()
    {
        measurements = []
        motionTracking?.updateCounter = 0
    }
    
    // ----------------------------------------------------------------------------
    // File creation methods
    // -------------------------------------------------------------------------------------------------
    
    // -------------------------------------------------------------------------------------------------
    func getCsvString() -> String
    {
        var csvString : String = createCsvCaption()
        
        for measurement in measurements
        {
            csvString.append( "\n\(getCsvValueString(value: measurement.timestamp    ))" )
            csvString.append( ",\( getCsvValueString(value: measurement.orientation  ))" )
            csvString.append( ",\( getCsvValueString(value: measurement.acceleration ))" )
            csvString.append( ",\( getCsvValueString(value: measurement.buttonId     ))" )
        }
        
        return csvString
    }
    
    // -------------------------------------------------------------------------------------------------
    func createCsvCaption() -> String
    {
        var caption = "Timestamp"
        caption.append(",Orientation[q_x],Orientation[q_y],Orientation[q_z],Orientation[q_w]" )
        caption.append(",Acceleration[v_x],Acceleration[v_y],Acceleration[v_z]")
        caption.append(",ButtonId")
        return caption
    }
    
    // -------------------------------------------------------------------------------------------------
    func getCsvValueString( value: Any ) -> String
    {
        var csvString : String = ""
        
        if value is simd_double3
        {
            let v = value as! simd_double3
            csvString = "\(v.x),\(v.y),\(v.z)"
        }
        else if value is simd_quatd
        {
            let v = value as! simd_quatd
            csvString = "\(v.imag.x),\(v.imag.y),\(v.imag.z),\(v.real)"
        }
        else if value is Double
        {
            let v = value as! Double
            csvString = "\(v)"
        }
        else if value is UInt8
        {
            let v = value as! UInt8
            csvString = "\(v)"
        }
        
        return csvString
    }
    
    // ----------------------------------------------------------------------------
    // Motion Tracking Delegate protocol methods
    // ----------------------------------------------------------------------------

    // ----------------------------------------------------------------------------
    func measurementUpdate(timestamp: UInt32, orientation: simd_quatd, acceleration: simd_double3)
    {
        let timeInSeconds = Double( timestamp ) / 1000000
        
        let measurement = Measurement( timestamp: timeInSeconds,
                                       orientation: orientation,
                                       acceleration: acceleration,
                                       buttonId: buttonId )
        
        buttonId = 0
        
        measurements.append(measurement)
        
        delegate?.samplesUpdate(numSamples: measurements.count)
    }
    
}
