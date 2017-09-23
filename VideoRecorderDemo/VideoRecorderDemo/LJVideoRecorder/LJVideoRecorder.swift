//
//  LJVideoRecorder.swift
//  VideoRecorderDemo
//
//  Created by 一球 on 2017/9/23.
//  Copyright © 2017年 厉进虎. All rights reserved.
//

import Foundation
import AVFoundation

@objc protocol LJVideoRecorderDelegate {
    
    
    
}


class LJVideoRecorder: NSObject {
    
    //MARK: - open pros
    
    open weak var delegate: LJVideoRecorderDelegate?
    
    open var isRecording: Bool {
        return isVideoRecording
    }
    
    open var isPaused: Bool {
        return isVideoPaused
    }
    
    open var currentRecordTime: CGFloat {
        return currentVideoRecordTime
    }
    
    open var maximumDuration: CGFloat = 30
    open var minimumDuration: CGFloat = 3
    open var videoPath: String?
    
    //MARK: - private pros
    fileprivate var isVideoRecording: Bool = false
    fileprivate var isVideoPaused: Bool = false
    fileprivate var currentVideoRecordTime: CGFloat = 0
    
    lazy fileprivate var recorderSession: AVCaptureSession = {
        let rs = AVCaptureSession()
        
        return rs
    }()
    
    lazy fileprivate var previewLayer: AVCaptureVideoPreviewLayer? = {
        let layer = AVCaptureVideoPreviewLayer(session: self.recorderSession)
        layer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        return layer
    }()
    
    
    override init() {
        super.init()
    }
    
    deinit {
        recorderSession.stopRunning()
    }
    
    
    
    
    
    
    
    
    
    
    
    
//MARK: - ###################################################
    
//    open var preView:UIView? {
//        didSet {
//            preView?.layer.masksToBounds = true
//            if videoPreviewLayer?.superlayer != nil {
//                videoPreviewLayer?.removeFromSuperlayer()
//            }
//            videoPreviewLayer?.frame = (preView?.layer.bounds)!
//            videoPreviewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
//            preView?.layer.insertSublayer(videoPreviewLayer!, above: nil)
//            addNotificationToCaptureDevice(videoDevice!)
//        }
//    }
//    
//    
//    //MARK: - private pros
//    fileprivate var session: AVCaptureSession
//    fileprivate var videoDevice: AVCaptureDevice?
//    fileprivate var isVideoDeviceAble: Bool = false
//    fileprivate var cameraDeviceInput: AVCaptureDeviceInput?
//    fileprivate var audioDeviceInput: AVCaptureDeviceInput?
//    fileprivate var captureMovieFileOutput: AVCaptureMovieFileOutput
//    fileprivate var videoPreviewLayer: AVCaptureVideoPreviewLayer?
//    
//    
//    override init() {
//        session = AVCaptureSession()
//        captureMovieFileOutput = AVCaptureMovieFileOutput()
//        super.init()
//        configureVideoRecorder()
//    }
}


extension LJVideoRecorder {
    
}


//// MARK: - private methods
//extension LJVideoRecorder {
//    
//    /// 初始化recorder
//    fileprivate func configureVideoRecorder() {
//        //设置视频预设（720p）
//        if session.canSetSessionPreset(AVCaptureSessionPreset1280x720) {
//            session.sessionPreset = AVCaptureSessionPreset1280x720
//        }
//        addDeviceInputs()
//        addDeviceOutputs()
//        
//        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
//    }
//    
//    /// 添加输入设备
//    fileprivate func addDeviceInputs() {
//        if let cameraDevice = getCameraDevice(.back)  {
//            do {
//                cameraDeviceInput = try AVCaptureDeviceInput(device: cameraDevice)
//                if session.canAddInput(cameraDeviceInput!) {
//                    session.addInput(cameraDeviceInput!)
//                }
//            } catch  { print("获取视频输出设备失败") }
//        } else {
//            print("设备没有后置摄像头")
//        }
//        
//        if let audioDevice = getAudioDevice()  {
//            do {
//                audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
//                if session.canAddInput(audioDeviceInput!) {
//                    session.addInput(audioDeviceInput!)
//                }
//            } catch  { print("获取音频输出设备失败") }
//        } else {
//            print("设备没有麦克风")
//        }
//    }
//    
//    /// 添加输出对象，用户获取输出数据
//    fileprivate func addDeviceOutputs() {
//        if let captureConnection = captureMovieFileOutput.connection(withMediaType: AVMediaTypeAudio), captureConnection.isVideoStabilizationSupported {
//            captureConnection.preferredVideoStabilizationMode = .auto
//        }
//        
//        if session.canAddOutput(captureMovieFileOutput) {
//            session.addOutput(captureMovieFileOutput)
//        }
//    }
//    
//}
//
//// MARK: - AVFoundation
//extension LJVideoRecorder {
//    
//    fileprivate func getAudioDevice() -> AVCaptureDevice? {
//        let audioDevicesArray = getCaptureDevices(AVMediaTypeAudio)
//        if audioDevicesArray.count > 0 {
//            return audioDevicesArray.first
//        }
//        return nil
//    }
//    
//    fileprivate func getCameraDevice(_ position: AVCaptureDevicePosition) -> AVCaptureDevice? {
//        let cameraDevicesArray = getCaptureDevices(AVMediaTypeVideo)
//        for camera in cameraDevicesArray {
//            if camera.position == position {
//                return camera
//            }
//        }
//        return nil
//    }
//    
//    fileprivate func getCaptureDevices(_ mediaType: String!) -> [AVCaptureDevice]{
//        let captureDevicesArray = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as! [AVCaptureDevice]
//        return captureDevicesArray
//    }
//    
//    fileprivate func getCaptureConnetion(movieFileOutput:AVCaptureMovieFileOutput, _ mediaType: String) -> AVCaptureConnection? {
//        let connection = movieFileOutput.connection(withMediaType: mediaType)
//        return connection
//    }
//}
//
//// MARK: - open methods
//extension LJVideoRecorder {
//    func addNotificationToCaptureDevice(_ captureDevice: AVCaptureDevice) {
//        changeDeviceProperty { (captureDevice) in
//            captureDevice.isSubjectAreaChangeMonitoringEnabled = true
//        }
//    }
//    
//    func changeDeviceProperty(_ handler: ((_ capture: AVCaptureDevice)->())) {
//        guard let cDevice = cameraDeviceInput?.device else {
//            return
//        }
//        
//        do {
//            try cDevice.lockForConfiguration()
//            handler(cDevice)
//            cDevice.unlockForConfiguration()
//        } catch {
//            print("设置设备属性的过程中发生错误")
//        }
//    }
//}
