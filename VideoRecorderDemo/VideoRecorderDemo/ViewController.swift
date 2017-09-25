//
//  ViewController.swift
//  VideoRecorderDemo
//
//  Created by 一球 on 2017/9/23.
//  Copyright © 2017年 厉进虎. All rights reserved.
//

import UIKit
import AVFoundation
class ViewController: UIViewController {
    @IBOutlet weak var videoPreview: UIView!

    fileprivate var recordManager: LJVideoRecorderManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        view.backgroundColor = UIColor.white
        recordManager = LJVideoRecorderManager()
        recordManager?.preview = videoPreview
        videoPreview.backgroundColor = UIColor.black
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    @IBAction func torchButtonClicked(_ sender: UIButton) {
        recordManager?.switchTorchState()
    }
    
    @IBAction func cameraButtonClicked(_ sender: UIButton) {
        recordManager?.switchCameraPostion()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        recordManager?.startPreview()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        recordManager?.stopPreview()
    }

}


extension ViewController {
}
