//
//  ViewController.swift
//  VideoRecorderDemo
//
//  Created by 一球 on 2017/9/23.
//  Copyright © 2017年 厉进虎. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
class ViewController: UIViewController {
    @IBOutlet weak var videoPreview: UIView!

    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var completionButton: UIButton!
    fileprivate var recordManager: LJVideoRecorderManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        view.backgroundColor = UIColor.white
        recordManager = LJVideoRecorderManager()
        recordManager?.preview = videoPreview
        videoPreview.backgroundColor = UIColor.black
        completionButton.isEnabled = false
        recordManager?.delegate = self
        progressView.progress = 0
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
    
    @IBAction func recordButtonClicked(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        if sender.isSelected {
            completionButton.isEnabled = false
            self.recordManager?.startRecording()
        } else {
            self.recordManager?.stopRecording()
            if self.recordManager!.videoCount > 0 {
                completionButton.isEnabled = true
            }
        }
    }
    
    @IBAction func completionButtonClicked(_ sender: UIButton) {
        recordManager?.finishRecording({ 
            let playerVC = AVPlayerViewController()
            playerVC.player = AVPlayer(url: URL(fileURLWithPath: self.recordManager!.filePath))
            self.present(playerVC, animated: true, completion: nil)
        })
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


extension ViewController: LJVideoRecorderMangerDelegate {
    
    func videoRecorderManagerDidStoppedRecording(_ recorderManger: LJVideoRecorderManager) {
        
    }
    
    func videoRecorderManagerRecordingDidUpdate(_ recorderManger: LJVideoRecorderManager, _ duration: Float) {
        self.progressView.progress = duration / recorderManger.maximumDuration
    }
    
    func videoRecorderManagerDidFinishedRecordingWithMoreThanMaximumDuration(_ recorderManger: LJVideoRecorderManager, fileURL: URL) {
        let playerVC = AVPlayerViewController()
        playerVC.player = AVPlayer(url: URL(fileURLWithPath: self.recordManager!.filePath))
        self.present(playerVC, animated: true, completion: nil)
    }
}
