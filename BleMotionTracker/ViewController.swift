// ----------------------------------------------------------------------------
//  ViewController
// ----------------------------------------------------------------------------

import UIKit

// ----------------------------------------------------------------------------
class ViewController: UIViewController, BleMotionTrackerDelegate
{
    enum AppFunction
    {
        case sensor, recorder
    }
    
    // ------------------------------------------------------------------------
    @IBOutlet weak var functionControl: UISegmentedControl!
    @IBOutlet weak var bleStatusLabel : UILabel!
    @IBOutlet weak var recordingLabel : UILabel!
    @IBOutlet weak var recordingSwitch: UISwitch!
    @IBOutlet weak var shareButton    : UIButton!
    @IBOutlet weak var clearButton    : UIButton!
    
    // ------------------------------------------------------------------------
    var state : AppFunction = .sensor
    
    // ------------------------------------------------------------------------
    var bleMotionTracker : BleMotionTracker?
    
    // ------------------------------------------------------------------------
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        functionChanged( self )
    }
    
    // ------------------------------------------------------------------------
    func setGui( state: AppFunction )
    {
        bleStatusLabel.isHidden  = ( state == .recorder )
        recordingLabel.isHidden  = ( state == .sensor   )
        recordingSwitch.isHidden = ( state == .sensor   )
        shareButton.isHidden     = ( state == .sensor   )
        clearButton.isHidden     = ( state == .sensor   )
    }
    
    // ------------------------------------------------------------------------
    // BleMotionTracker delegate
    // ------------------------------------------------------------------------
    func statusUpdate(status: String)
    {
        bleStatusLabel.text = "Bluetooth status: \(status)"
    }
    
    // ------------------------------------------------------------------------
    @IBAction func buttonPressed(_ sender: Any)
    {
        let button : UIButton = sender as! UIButton
        bleMotionTracker!.buttonPressed(buttonId: UInt8(button.tag) )
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
            setGui(state: .sensor)
            return
        }
        
        bleMotionTracker!.disable()
        bleMotionTracker = nil
        setGui(state: .recorder)
    }
}

