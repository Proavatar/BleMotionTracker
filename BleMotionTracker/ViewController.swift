//
//  ViewController.swift
//  BleMotionTracker
//
//  Created by Fred Dijkstra on 03/10/2022.
//

import UIKit

class ViewController: UIViewController
{
    var bleMotionTracker : BleMotionTracker?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        bleMotionTracker = BleMotionTracker.shared
    }
    
    @IBAction func buttonPressed(_ sender: Any)
    {
        let button : UIButton = sender as! UIButton
        bleMotionTracker!.buttonPressed(buttonId: UInt8(button.tag) )
    }
    
}

