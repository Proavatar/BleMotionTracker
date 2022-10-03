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
}

