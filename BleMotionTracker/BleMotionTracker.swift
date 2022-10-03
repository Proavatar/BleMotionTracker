//
//  BleMotionTracker.swift
//

import Foundation
import CoreBluetooth
import CoreMotion
import simd

// ----------------------------------------------------------------------------
// Extensions
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
extension Float
{
    var bytes: [UInt8]
    {
       withUnsafeBytes(of: self, Array.init)
    }
}

// ----------------------------------------------------------------------------
extension UInt32
{
    var bytes: [UInt8]
    {
       withUnsafeBytes(of: self, Array.init)
    }
}

// ----------------------------------------------------------------------------

// ---- Connection Service ----
let bleUuidConnectionService           = CBUUID( string: "135D1000-6298-DA99-F42B-8323F9632AEB" )
let bleUuidDisconnectionCharacteristic = CBUUID( string: "135D1001-6298-DA99-F42B-8323F9632AEB" )

// ---- Configuration Service ----
let bleUuidConfigurationService        = CBUUID( string: "135D2000-6298-DA99-F42B-8323F9632AEB" )
let bleUuidUpdateRateCharacteristic    = CBUUID( string: "135D2001-6298-DA99-F42B-8323F9632AEB" )
let bleUuidResetHeadingCharacteristic  = CBUUID( string: "135D2002-6298-DA99-F42B-8323F9632AEB" )

// ---- Measurement Service ----
let bleUuidMeasurementService          = CBUUID( string: "135D3000-6298-DA99-F42B-8323F9632AEB" )
let bleUuidOrientationCharacteristic   = CBUUID( string: "135D3001-6298-DA99-F42B-8323F9632AEB" )


// ----------------------------------------------------------------------------
// Constants
// ----------------------------------------------------------------------------
let LocalName         : String = "BLE-MT"
let ConnectionTimeout : TimeInterval = 2
let z_axis            : simd_double3 = simd_double3(x:0, y:0, z:1)
let MonitorConnection : Bool = false

// ----------------------------------------------------------------------------
enum Event : Int
{
    case didUpdateState,
         didAdd,
         didConnect,
         didDisconnect,
         didSubscribeTo,
         didUnsubscribeFrom,
         didReceiveRead,
         didReceiveWrite
}

// ----------------------------------------------------------------------------
enum State : Int
{
    case Idle,
         Initializing,
         Advertising,
         Connected,
         Measuring
}

// ----------------------------------------------------------------------------
enum ChoicePoint : Int
{
    case CP_poweredOn,
         CP_initialized,
         CP_configure,
         CP_heading
}

// ----------------------------------------------------------------------------
class BleMotionTracker: NSObject, CBPeripheralManagerDelegate
{
    public static let shared = BleMotionTracker()

    // -------------------------------------------------------------------------------------------------
    var state : State = State.Idle
    
    // -------------------------------------------------------------------------------------------------
    var servicesToAdd        : [CBMutableService] = []
    var orientation          : simd_quatd         = simd_quatd( ix: 0, iy: 0, iz: 0, r: 1)
    var startTimestamp       : TimeInterval       = CFAbsoluteTimeGetCurrent()
    var currentTimestamp     : TimeInterval       = CFAbsoluteTimeGetCurrent()
    var timestamp            : UInt32             = 0
    var updateRate           : UInt8              = 60
    var headingOffset        : simd_quatd         = simd_quatd( ix: 0, iy: 0, iz: 0, r: 1)
    
    var sampleTimer          : Timer?
    
    var characteristic       : CBCharacteristic?
    var readRequest          : CBATTRequest?

    // -------------------------------------------------------------------------------------------------
    var disconnectionCharacteristic : CBMutableCharacteristic?
    var updateRateCharacteristic    : CBMutableCharacteristic?
    var resetHeadingCharacteristic  : CBMutableCharacteristic?
    var orientationCharacteristic   : CBMutableCharacteristic?
    
    // -------------------------------------------------------------------------------------------------
    var blePeripheralManager : CBPeripheralManager?
    var motionManager        : CMMotionManager?
    
    // -------------------------------------------------------------------------------------------------
    override init()
    {
        super.init()
        initBlePeripheralManager()
        initMotionManager()
    }
    
    // -------------------------------------------------------------------------------------------------
    func initBlePeripheralManager()
    {
        let dispatchQueue : DispatchQueue = DispatchQueue( label: "bleConcurrentQueue", attributes: .concurrent )
        blePeripheralManager = CBPeripheralManager(delegate: self, queue: dispatchQueue)
    }
    
    // -------------------------------------------------------------------------------------------------
    func initMotionManager()
    {
        motionManager = CMMotionManager()
    }
    
    // ------------------------------------------------------------------------
    func handleEvent( event : Event )
    {
        DispatchQueue.main.async
        {
            var error = false
            
            switch self.state
            {
                // ----------------------------------------------------------------
                case .Idle :
                    switch event
                    {
                        case .didUpdateState :
                            self.handleChoicePoint( choicePoint: .CP_poweredOn )
                            
                        default :
                            error = true
                    }
                
                // ----------------------------------------------------------------
                case .Initializing :
                    switch event
                    {
                        case .didAdd :
                            self.servicesToAdd.removeFirst()
                            self.handleChoicePoint( choicePoint: .CP_initialized )
                            
                        default :
                            error = true
                    }
                
                // ----------------------------------------------------------------
                case .Advertising :
                    switch event
                    {
                        case .didConnect :
                            self.stopAdvertising()
                            self.state = .Connected
                        
                        case .didUnsubscribeFrom :
                            self.state = .Advertising
                        
                        default :
                            error = true
                    }
                
                // ----------------------------------------------------------------
                case .Connected :
                    switch event
                    {
                            
                        case .didSubscribeTo :
                            self.startMeasuring()
                            self.state = .Measuring
                            
                        case .didReceiveWrite :
                            self.handleChoicePoint( choicePoint: .CP_configure )
                            
                        case .didDisconnect :
                            self.startAdvertising()
                            self.state = .Advertising
                            
                        default :
                            error = true
                    }
                    
                // ----------------------------------------------------------------
                case .Measuring :
                    switch event
                    {
                        
                    case .didReceiveWrite :
                        self.handleChoicePoint( choicePoint: .CP_heading )

                    case .didDisconnect :
                        self.stopMeasuring()
                        self.startAdvertising()
                        self.state = .Advertising
                        
                    case .didUnsubscribeFrom :
                        self.stopMeasuring()
                        self.state = .Connected
                        
                    default :
                        error = true
                    }
            }

            // ----------------------------------------------------------------
            if error
            {
                print( "ERROR: unhandled event \(event) in state \(self.state)!" )
            }
        }
    }
    
    // -------------------------------------------------------------------------------------------------
    func handleChoicePoint( choicePoint: ChoicePoint )
    {
        switch choicePoint
        {
            case .CP_poweredOn:
            if blePeripheralManager!.state == .poweredOn
            {
                createServices()
                addNextService()
                state = .Initializing
            }
            else
            {
                state = .Idle
            }
            
            case .CP_heading :
            if characteristic!.uuid == bleUuidResetHeadingCharacteristic
            {
                calculateHeadingOffset()
                state = .Measuring
            }
            else
            {
                state = .Measuring
            }
            
            case .CP_configure :
                if characteristic!.uuid == bleUuidUpdateRateCharacteristic
                {
                    readUpdateRate()
                    state = .Connected
                }
                else
                {
                    state = .Connected
                }
            
            case .CP_initialized :
                if servicesToAdd.isEmpty
                {
                    startAdvertising()
                    state = .Advertising
                }
                else
                {
                    addNextService()
                    state = .Initializing
                }
        }
    }
    
    // -------------------------------------------------------------------------------------------------
    // Local functions
    // -------------------------------------------------------------------------------------------------
    
    // -------------------------------------------------------------------------------------------------
    func startAdvertising()
    {
        blePeripheralManager!.startAdvertising(
            [ CBAdvertisementDataLocalNameKey:LocalName,
              CBAdvertisementDataServiceUUIDsKey:[ bleUuidConnectionService,
                                                   bleUuidConfigurationService,
                                                   bleUuidMeasurementService ] ] )
    }
    
    // -------------------------------------------------------------------------------------------------
    func stopAdvertising()
    {
        blePeripheralManager!.stopAdvertising()
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

        orientation = simd_mul( headingOffset, simd_quatd( ix: q.x, iy: q.y, iz: q.z, r: q.w ) )
        
        updateOrientation()
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
    
    // -------------------------------------------------------------------------------------------------
    func readUpdateRate()
    {
        updateRate = updateRateCharacteristic!.value![0]
    }
    
    // -------------------------------------------------------------------------------------------------
    func updateOrientation()
    {
        var data : Data = Data(capacity: 20)
        
        data.append( Data( timestamp.bytes ) )
        
        data.append( Data( Float(orientation.imag.x).bytes) )
        data.append( Data( Float(orientation.imag.y).bytes) )
        data.append( Data( Float(orientation.imag.z).bytes) )
        data.append( Data( Float(orientation.real  ).bytes) )
        
        blePeripheralManager!.updateValue(data,
                                          for: orientationCharacteristic!,
                                          onSubscribedCentrals: nil)
    }
    
    // -------------------------------------------------------------------------------------------------
    func addNextService()
    {
        blePeripheralManager!.add(servicesToAdd.first!)
    }
    
    // -------------------------------------------------------------------------------------------------
    // Services and characteristics
    // -------------------------------------------------------------------------------------------------
    
    // -------------------------------------------------------------------------------------------------
    func createServices()
    {
        createConnectionService()
        createConfigurationService()
        createMeasurementService()
    }
    
    // -------------------------------------------------------------------------------------------------
    func createConnectionService()
    {
        let service = CBMutableService( type: bleUuidConnectionService, primary: true)
        service.characteristics = []
        servicesToAdd.append(service)

        disconnectionCharacteristic =
            CBMutableCharacteristic(
                type: bleUuidDisconnectionCharacteristic,
                properties: [.notify],
                value: nil,
                permissions: [.writeable, .readable])
                
        service.characteristics!.append(disconnectionCharacteristic!)
    }
    
    // -------------------------------------------------------------------------------------------------
    func createConfigurationService()
    {
        let service = CBMutableService( type: bleUuidConfigurationService, primary: true)
        service.characteristics = []
        servicesToAdd.append(service)

        updateRateCharacteristic =
            CBMutableCharacteristic(
                type: bleUuidUpdateRateCharacteristic,
                properties: [.read, .write],
                value: nil,
                permissions: [.readable, .writeable])
                
        service.characteristics!.append(updateRateCharacteristic!)
        
        resetHeadingCharacteristic =
            CBMutableCharacteristic(
                type: bleUuidResetHeadingCharacteristic,
                properties: [.write],
                value: nil,
                permissions: [.readable, .writeable])
                
        service.characteristics!.append(resetHeadingCharacteristic!)
    }
    
    // -------------------------------------------------------------------------------------------------
    func createMeasurementService()
    {
        let service = CBMutableService( type: bleUuidMeasurementService, primary: true)
        service.characteristics = []
        servicesToAdd.append(service)

        orientationCharacteristic =
            CBMutableCharacteristic(
                type: bleUuidOrientationCharacteristic,
                properties: [.notify],
                value: nil,
                permissions: [.writeable])
                
        service.characteristics!.append(orientationCharacteristic!)
    }
    
    // -------------------------------------------------------------------------------------------------
    // CBPeripheralManagerDelegate methods to generate events:
    // - didUpdateState
    // - didAdd
    // - didConnect
    // - didSubscribeTo
    // - didDisconnect
    // - didUnsubscribeFrom
    // - didReceiveRead
    // - didReceiveWrite
    // -------------------------------------------------------------------------------------------------
    
    // -------------------------------------------------------------------------------------------------
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager)
    {
        handleEvent(event: .didUpdateState)
    }
    
    // -------------------------------------------------------------------------------------------------
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?)
    {
        if error != nil
        {
            print( "ERROR: failed to add service \(service.uuid.uuidString)" )
        }
        
        handleEvent(event: .didAdd)
    }
    
    // -------------------------------------------------------------------------------------------------
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral, didSubscribeTo characteristic: CBCharacteristic)
    {
        if characteristic == orientationCharacteristic
        {
            handleEvent(event: .didSubscribeTo)
        }
        else if characteristic == disconnectionCharacteristic
        {
            handleEvent(event: .didConnect)
        }
    }
    
    // -------------------------------------------------------------------------------------------------
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic)
    {
        if characteristic == orientationCharacteristic
        {
            handleEvent(event: .didUnsubscribeFrom)
        }
        else if characteristic == disconnectionCharacteristic
        {
            handleEvent(event: .didDisconnect)
        }
    }

    // -------------------------------------------------------------------------------------------------
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest)
    {
        if request.characteristic == updateRateCharacteristic
        {
            request.value = Data( [updateRate] )
            
            peripheral.respond(to: request, withResult: .success)
            
            characteristic = request.characteristic
            handleEvent(event: .didReceiveRead)
        }
    }
    
    // -------------------------------------------------------------------------------------------------
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest])
    {
        for request in requests
        {
            if request.characteristic == updateRateCharacteristic
            {
                updateRateCharacteristic!.value = request.value
            }
            else if request.characteristic == resetHeadingCharacteristic
            {
                resetHeadingCharacteristic!.value = request.value
            }
            
            peripheral.respond(to: request, withResult: .success)
            
            characteristic = request.characteristic
            handleEvent(event: .didReceiveWrite)
        }
    }
    
    // -------------------------------------------------------------------------------------------------
}
