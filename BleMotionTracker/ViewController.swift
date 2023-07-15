// ----------------------------------------------------------------------------
//  ViewController
// ----------------------------------------------------------------------------

import UIKit

// ----------------------------------------------------------------------------
let updateRates : [UInt8] = [10,20,30,60,120]

// ----------------------------------------------------------------------------
class ViewController: UIViewController, BleMotionTrackerDelegate, MotionRecorderDelegate
{
    // ------------------------------------------------------------------------
    @IBOutlet weak var functionControl  : UISegmentedControl!
    @IBOutlet weak var bleStatusLabel   : UILabel!
    @IBOutlet weak var recordingLabel   : UILabel!
    @IBOutlet weak var recordingSwitch  : UISwitch!
    @IBOutlet weak var shareButton      : UIButton!
    @IBOutlet weak var clearButton      : UIButton!
    @IBOutlet weak var updateRateControl: UISegmentedControl!
    @IBOutlet weak var numSamplesLabel  : UILabel!
    @IBOutlet weak var buttonButton     : UIButton!
    
    @IBOutlet weak var recordingControlsStack: UIStackView!

    // ------------------------------------------------------------------------
    enum AppFunction
    {
        case Sensor, Recorder
    }
        
    // ------------------------------------------------------------------------
    var bleMotionTracker : BleMotionTracker?
    var motionRecorder   : MotionRecorder?
    var updateRate       : UInt8 = 60
    
    // ------------------------------------------------------------------------
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        functionChanged( self )
    }
    
    // ------------------------------------------------------------------------
    func setGui( currentFunction: AppFunction )
    {
        bleStatusLabel.isHidden     = ( currentFunction == .Recorder )
        recordingLabel.isHidden     = ( currentFunction == .Sensor   )
        recordingSwitch.isHidden    = ( currentFunction == .Sensor   )
        
        recordingControlsStack.isHidden = ( currentFunction == .Sensor )
        
        updateRateControl.isUserInteractionEnabled = ( currentFunction == .Recorder &&
                                                       !recordingSwitch.isOn )
        
        shareButton.isEnabled = ( !recordingSwitch.isOn )
        clearButton.isEnabled = ( recordingSwitch.isOn )
        
        buttonButton.isEnabled = ( ( currentFunction == .Recorder && recordingSwitch.isOn ) ||
                                   ( currentFunction == .Sensor && bleMotionTracker?.state == .Connected ) )
    }
    
    // ------------------------------------------------------------------------
    // BleMotionTracker delegate
    // ------------------------------------------------------------------------
    
    // ------------------------------------------------------------------------
    func statusUpdate(status: String)
    {
        bleStatusLabel.text = "Bluetooth status: \(status)"
        setGui(currentFunction: .Sensor)
    }
    
    // ------------------------------------------------------------------------
    func updateRateSet( updateRate: UInt8  )
    {
        var segmentIndex : Int = 0
        
        switch updateRate
        {
        case 10 :
            segmentIndex = 0
            break
        case 20 :
            segmentIndex = 1
            break
        case 30 :
            segmentIndex = 2
            break
        case 60 :
            segmentIndex = 3
            break
        case 120 :
            segmentIndex = 4
            break
        default :
            segmentIndex = 0
        }
        
        updateRateControl.selectedSegmentIndex = segmentIndex
    }

    // ------------------------------------------------------------------------
    // Action handlers
    // ------------------------------------------------------------------------

    // ------------------------------------------------------------------------
    @IBAction func buttonPressed(_ sender: Any)
    {
        let button : UIButton = sender as! UIButton
        
        bleMotionTracker?.buttonPressed( buttonId: UInt8(button.tag) )
        motionRecorder?.buttonPressed  ( buttonId: UInt8(button.tag) )
    }
    
    // ------------------------------------------------------------------------
    @IBAction func functionChanged(_ sender: Any)
    {
        let functionString = functionControl.titleForSegment(
            at: functionControl.selectedSegmentIndex )!
        
        if functionString == "Sensor"
        {
            bleMotionTracker = BleMotionTracker()
            bleMotionTracker?.delegate = self
            setGui(currentFunction: .Sensor)
            return
        }
        
        bleMotionTracker!.disable()
        bleMotionTracker = nil
        
        motionRecorder = MotionRecorder()
        motionRecorder?.delegate = self
        updateRateSelected(self)
        
        setGui(currentFunction: .Recorder)
    }
    
    // -------------------------------------------------------------------------------------------------
    @IBAction func recordingControlChanged(_ sender: Any)
    {
        if recordingSwitch.isOn
        {
            motionRecorder?.startRecording()
        }
        else
        {
            motionRecorder?.stopRecording()
        }
        
        setGui(currentFunction: .Recorder )
    }
    
    
    // -------------------------------------------------------------------------------------------------
    @IBAction func updateRateSelected(_ sender: Any)
    {
        let index = updateRateControl.selectedSegmentIndex
        motionRecorder?.setUpdateRate(updateRate: updateRates[index])
    }
    
    // -------------------------------------------------------------------------------------------------
    @IBAction func shareButtonPressed(_ sender: Any)
    {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = dir.appendingPathComponent(datalogFilename)
        
        // Create the Array which includes the files you want to share
        var filesToShare = [Any]()

        // Add the path of the file to the Array
        filesToShare.append(fileURL)

        // Make the activityViewContoller which shows the share-view
        let activityViewController = UIActivityViewController(activityItems: filesToShare, applicationActivities: nil)
        
        if activityViewController.popoverPresentationController != nil
        {
            activityViewController.popoverPresentationController!.sourceView = shareButton
        }
        
        // Show the share-view
        present(activityViewController, animated: true, completion: nil)
    }
    
    // -------------------------------------------------------------------------------------------------
    @IBAction func clearButtonPressed(_ sender: Any)
    {
        motionRecorder?.clearRecording()
    }
    
    // -------------------------------------------------------------------------------------------------
    // Motion Recorder Delegate protocol methods
    // -------------------------------------------------------------------------------------------------

    // -------------------------------------------------------------------------------------------------
    func samplesUpdate(numSamples: Int)
    {
        numSamplesLabel.text = "\(numSamples)"
    }
    
    // -------------------------------------------------------------------------------------------------
    func recordingStopped()
    {
        print( "INFO: recording stopped!")
    }
    
}

