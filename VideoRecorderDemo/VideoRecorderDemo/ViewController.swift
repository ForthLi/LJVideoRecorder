//
//  ViewController.swift
//  VideoRecorderDemo
//
//  Created by 一球 on 2017/9/23.
//  Copyright © 2017年 厉进虎. All rights reserved.
//

import UIKit
class ViewController: UIViewController {
    @IBOutlet weak var videoPreview: UIView!

    fileprivate var recorder: LJVideoRecorder?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        view.backgroundColor = UIColor.white
        recorder = LJVideoRecorder()
//        recorder?.preView = videoPreview
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

