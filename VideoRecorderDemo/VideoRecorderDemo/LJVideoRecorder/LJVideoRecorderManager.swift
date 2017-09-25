//
//  LJVideoRecorderManager.swift
//  VideoRecorderDemo
//
//  Created by 一球 on 2017/9/24.
//  Copyright © 2017年 厉进虎. All rights reserved.
//

import UIKit
import AVFoundation
class LJVideoRecorderManager: NSObject {
    
    open var preview: UIView? {
        didSet {
            guard let preview = preview else {
                return
            }
            
            let layer = preview.layer
            previewLayer?.frame = layer.bounds
            layer.masksToBounds = true
            previewLayer!.videoGravity = AVLayerVideoGravityResizeAspectFill
            layer.addSublayer(previewLayer!)
        }
    }
    
    fileprivate var captureSession: AVCaptureSession
    fileprivate var videoDeviceInput: AVCaptureDeviceInput?
    fileprivate var backCameraDevice: AVCaptureDevice?
    fileprivate var frontCameraDevice: AVCaptureDevice?
    fileprivate var audioDeviceInput: AVCaptureDeviceInput?
    fileprivate var audioDevice: AVCaptureDevice?
    
    fileprivate var movieFileOutput: AVCaptureMovieFileOutput
    fileprivate var previewLayer: AVCaptureVideoPreviewLayer?
    fileprivate var isCameraPositonBack = true
    
    fileprivate var captureQueue: DispatchQueue = DispatchQueue(label: "com.lijinhu.video.recorder")
    
    override init() {
        captureSession = AVCaptureSession()
        movieFileOutput = AVCaptureMovieFileOutput()
        super.init()
        configureCaptureSession()
    }
    
    deinit {
        //释放资源
        releaseCaptureSession()
    }
}


// MARK: - private methods
extension LJVideoRecorderManager {
    ///释放资源
    fileprivate func releaseCaptureSession() {
        captureSession.stopRunning()
    }
    
    /// 配置资源
    fileprivate func configureCaptureSession() {
        addBackCameraDeviceInput()
        addAudioDeviceInput()
        addMovieFileOutput()
        captureSession.sessionPreset = AVCaptureSessionPreset640x480
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    }
    
    /// 获取后置摄像头输入
    fileprivate func addBackCameraDeviceInput() {
        if backCameraDevice == nil {
            backCameraDevice = cameraDevice(.back)
        }
        
        if let backCameraDevice = backCameraDevice {
            do {
                videoDeviceInput = try AVCaptureDeviceInput(device: backCameraDevice)
                if captureSession.canAddInput(videoDeviceInput!) {
                    captureSession.addInput(videoDeviceInput!)
                }
            } catch {
                print("获取后置摄像头输入失败！")
            }
        }
    }
    
    ///获取前置摄像头输入
    fileprivate func addFrontCameraDeviceInput() {
        if frontCameraDevice == nil {
            frontCameraDevice = cameraDevice(.front)
        }
        
        if let frontCameraDevice = frontCameraDevice {
            do {
                videoDeviceInput = try AVCaptureDeviceInput(device: frontCameraDevice)
                if captureSession.canAddInput(videoDeviceInput!) {
                    captureSession.addInput(videoDeviceInput!)
                }
            } catch {
                print("获取前置摄像头输入失败！")
            }
        }
    }
    
    /// 获取麦克风输入
    fileprivate func addAudioDeviceInput() {
         audioDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
        if let audioDevice = audioDevice {
            do {
                audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
                if captureSession.canAddInput(audioDeviceInput!) {
                    captureSession.addInput(audioDeviceInput!)
                }
            } catch  {
                print("获取麦克风输入失败！")
            }
        }
    }
    
    /// 添加视频输出
    fileprivate func addMovieFileOutput() {
        if let captureConnection = movieFileOutput.connection(withMediaType: AVMediaTypeAudio) {
            if captureConnection.isVideoStabilizationSupported {
                captureConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationMode.auto
            }
        }
        if captureSession.canAddOutput(movieFileOutput) {
            captureSession.addOutput(movieFileOutput)
        }

    }
    
    
    /// 获取指定位置的摄像头
    fileprivate func cameraDevice(_ position: AVCaptureDevicePosition) ->AVCaptureDevice? {
        guard let cameraDeviceArray = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as? [AVCaptureDevice], cameraDeviceArray.count > 0 else {
            return nil
        }
        for camera in cameraDeviceArray {
            if camera.position == position {
                return camera
            }
        }
        return nil
    }
}


// MARK: - open methods
extension LJVideoRecorderManager {
    
    /// 开始预览
    open func startPreview() {
        objc_sync_enter(self)
        print("startPreview")
        captureSession.startRunning()
        objc_sync_exit(self)
    }
    
    ///停止预览
    open func stopPreview() {
        print("stopPreview")
        captureSession.stopRunning()
    }
    
    ///开始录制
    open func startRecording() {
        print("startRecording")
       
    }
    
    ///定制录制
    open func stopRecording() {
        print("stopRecording")
    }
    
    ///完成录制
    open func finishRecording() {
        print("finishRecording")
    }
    
    /// 切换前后摄像头
    open func switchCameraPostion() {
        print("switchCameraPostion")
//        objc_sync_enter(self)
        DispatchQueue.global().async { [weak self] in
            self?.switchCamera()
        }
        
        let animation = CABasicAnimation(keyPath: "transform.rotation.y")
        animation.toValue = Double.pi
        animation.duration = 0.9
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        animation.isRemovedOnCompletion = false
        animation.fillMode = kCAFillModeForwards
        previewLayer?.add(animation, forKey: nil)
    }
    
    fileprivate func switchCamera() {
        objc_sync_enter(self)
        captureSession.stopRunning()
        captureSession.removeInput(videoDeviceInput!)
        isCameraPositonBack = !isCameraPositonBack
        if isCameraPositonBack {
            addBackCameraDeviceInput()
        } else {
            addFrontCameraDeviceInput()
        }
        captureSession.startRunning()
        objc_sync_exit(self)
    }
    
    /// 切换相机手电筒状态
    open func switchTorchState() {
        print("switchTorchState")
    }
    
    
    
}
