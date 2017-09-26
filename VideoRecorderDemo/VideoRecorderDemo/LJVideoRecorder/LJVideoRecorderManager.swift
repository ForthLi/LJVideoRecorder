//
//  LJVideoRecorderManager.swift
//  VideoRecorderDemo
//
//  Created by 一球 on 2017/9/24.
//  Copyright © 2017年 厉进虎. All rights reserved.
//

import UIKit
import CoreFoundation
import AVFoundation

enum LJVideoRecordingState {
    case unStarted
    case recording
    case puased
    case completed
}


@objc protocol LJVideoRecorderMangerDelegate: NSObjectProtocol {
    
    /// 实时更新录制进度
    @objc optional func videoRecorderManagerRecordingDidUpdate(_ recorderManger: LJVideoRecorderManager, _ duration: Float) ->Void
    ///录制已经暂停
    @objc optional func videoRecorderManagerDidStoppedRecording(_ recorderManger: LJVideoRecorderManager) ->Void
    
    ///视频录制时长超过最大值时，自动结束录制方法
    @objc optional func videoRecorderManagerDidFinishedRecordingWithMoreThanMaximumDuration(_ recorderManger: LJVideoRecorderManager, fileURL:URL) ->Void
}

class LJVideoRecorderManager: NSObject {
    
    //MARK: - open properties
    open var minimumDuration: Float = 3.0
    open var maximumDuration: Float = 30.0
    open weak var delegate: LJVideoRecorderMangerDelegate?
    open var duration: Float{
        var duration: Float64 = 0
        for time in videoTimesArray {
            duration += CMTimeGetSeconds(time)
        }
        duration += CMTimeGetSeconds(currentFragDuration)
        return Float(duration)
    }
    
    
    open var videoCount: Int {
        set {
            if newValue <= 0, newValue >= videoArray.count {
                return
            }
            
            let count = videoArray.count - newValue
            for _ in 0..<count {
                deleteLastSubVideo()
            }
        }
        get {
            return videoArray.count
        }
    }
    
    open var filePath: String {
        didSet {
            if filePath == oldValue {
                return
            }
            
            let fm = FileManager.default
            if (oldValue as NSString).length > 0,
                fm.fileExists(atPath: oldValue) { //删除上一个文件
                try? fm.removeItem(atPath: oldValue)
            }
            if fm.fileExists(atPath: filePath) { //删除同路径文件
                do {
                    try fm.removeItem(atPath: filePath)
                } catch  {
                    print("删除失败")
                }
            }
        }
    }
    open var taskPath: String {
        didSet {
            if taskPath == oldValue {
                return
            }
            
            let fm = FileManager.default
            if (oldValue as NSString).length > 0,
                fm.fileExists(atPath: oldValue) { //删除上一个文件
                try? fm.removeItem(atPath: oldValue)
            }
            
            if fm.fileExists(atPath: taskPath) { //删除同路径文件
                try? fm.removeItem(atPath: taskPath)
            }
            
            do {
                try fm.createDirectory(atPath: taskPath, withIntermediateDirectories: true, attributes: nil)
            } catch  {
                print("创建任务目录失败")
            }
        }
    }
    open var isRecording: Bool {
        return videoRecordState == .recording
    }
    
    open var isPuased: Bool {
        return videoRecordState == .puased
    }
    
    open var isCompletion: Bool {
        return videoRecordState == .completed
    }
    
    open var isPreviewing: Bool {
        return isVideoPreviewing
    }
    
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
    
    //MARK: - private properties
    fileprivate var captureQueue: DispatchQueue = DispatchQueue(label: "com.lijinhu.video.recorder")
    
    fileprivate var captureSession: AVCaptureSession
    
    fileprivate var videoDeviceInput: AVCaptureDeviceInput?
    fileprivate var backCameraDevice: AVCaptureDevice?
    fileprivate var frontCameraDevice: AVCaptureDevice?
    
    fileprivate var audioDeviceInput: AVCaptureDeviceInput?
    fileprivate var audioDevice: AVCaptureDevice?
    
    fileprivate var videoDataOutput: AVCaptureVideoDataOutput
    fileprivate var videoConnection: AVCaptureConnection?
    
    fileprivate var audioDataOutput: AVCaptureAudioDataOutput
    fileprivate var audioConnection: AVCaptureConnection?
    
    fileprivate var previewLayer: AVCaptureVideoPreviewLayer?
    
    
    lazy fileprivate var videoArray = [String]()
    lazy fileprivate var videoTimesArray: [CMTime] = [CMTime]()
    
    fileprivate var videoRecordEncoder: LJVideoRecordEncoder?
    
    
    fileprivate var videoRecordState: LJVideoRecordingState = .unStarted
    fileprivate var isVideoPreviewing = false // 是否开始预览
    
    fileprivate var isCameraPositonBack = true
    fileprivate var isTorchOpen = false
    
    fileprivate var currentFragDuration: CMTime = kCMTimeZero
    fileprivate var startTime: CMTime = kCMTimeZero
    
    fileprivate var audioSampleRate: Float64 = 0 //音频采样率
    fileprivate var audioChannels: UInt32 = 0 // 音频轨道
    
    fileprivate var videoReWidth: Int = 720 //视频分辨率 - width
    fileprivate var videoReHeight: Int = 1280 //视频分辨率 - height
    
    //MARK: - override methods
    override init() {
        captureSession = AVCaptureSession()
        videoDataOutput = AVCaptureVideoDataOutput()
        audioDataOutput = AVCaptureAudioDataOutput()
        let libraryPath = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.libraryDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0]
        
        let directoryPath = (libraryPath as NSString).appendingPathComponent("LJVideoRecording")
        let fm = FileManager.default
        if fm.fileExists(atPath: directoryPath) {
            try? fm.removeItem(atPath: directoryPath)
        }
        
        filePath = (directoryPath as NSString).appendingPathComponent("video.mp4")
        taskPath = (directoryPath as NSString).appendingPathComponent("videoArray")
        
        try? fm.createDirectory(atPath: taskPath, withIntermediateDirectories: true, attributes: nil)
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
    
    fileprivate func addSyncLock(_ handler: (()->())?) {
        objc_sync_enter(self)
        handler?()
        objc_sync_exit(self)
    }
    
    fileprivate func configureVideoRecordEncoder() {
        let videoName = String(format: "video_%04d.mp4", (videoArray.count + 1))
        let filePath = (taskPath as NSString).appendingPathComponent(videoName)
        videoRecordEncoder = LJVideoRecordEncoder(filePath: filePath, videoResolutionHeight: videoReHeight, videoResolutionWeight: videoReWidth, audioChannels: audioChannels, audioSampleRate: audioSampleRate)
        videoArray.append(videoName)
    }
    
    ///释放资源
    fileprivate func releaseCaptureSession() {
        captureSession.stopRunning()
    }
    
    /// 配置资源
    fileprivate func configureCaptureSession() {
        addBackCameraDeviceInput()
        addAudioDeviceInput()
        addVideoDataOutput()
        addAudioDataOutput()
        videoConnection = videoDataOutput.connection(withMediaType: AVMediaTypeVideo)
        audioConnection = audioDataOutput.connection(withMediaType: AVMediaTypeAudio)
//        captureSession.sessionPreset = AVCaptureSessionPreset1280x720
        videoConnection?.videoOrientation = .portrait
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
    
    ///添加视频输出
    fileprivate func addVideoDataOutput() {
        videoDataOutput.setSampleBufferDelegate(self , queue: self.captureQueue)
        let settings = [(kCVPixelBufferPixelFormatTypeKey as String) : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
        videoDataOutput.videoSettings = settings
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
    }
    
    ///添加音频输出
    fileprivate func addAudioDataOutput() {
        audioDataOutput.setSampleBufferDelegate(self, queue: self.captureQueue)
        if captureSession.canAddOutput(audioDataOutput) {
            captureSession.addOutput(audioDataOutput)
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
    
    ///切换手电筒状态
    fileprivate func changeToruchState() {
        guard let backCameraDevice = backCameraDevice else {
            return
        }
        
        if isCameraPositonBack {
            isTorchOpen = !isTorchOpen
            if isTorchOpen {
                if backCameraDevice.torchMode != .on {
                    try? backCameraDevice.lockForConfiguration()
                    backCameraDevice.torchMode = .on
                    backCameraDevice.flashMode = .on
                    backCameraDevice.unlockForConfiguration()
                }
            } else {
                if backCameraDevice.torchMode != .off {
                    try? backCameraDevice.lockForConfiguration()
                    backCameraDevice.torchMode = .off
                    backCameraDevice.flashMode = .off
                    backCameraDevice.unlockForConfiguration()
                }
            }
        }
    }
    
    ///切换镜头
    fileprivate func switchCamera() {
        objc_sync_enter(self)
        if isCameraPositonBack {
            if isTorchOpen {
                changeToruchState()
            }
        }
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
    
    /// 添加动画 for：镜头切换
    fileprivate func addAnimationForCameraSwitch() {
        let animation = CABasicAnimation(keyPath: "transform.rotation.y")
        animation.toValue = Double.pi
        animation.delegate = self
        animation.duration = 0.95
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        animation.isRemovedOnCompletion = false
        animation.fillMode = kCAFillModeForwards
        previewLayer?.add(animation, forKey: nil)
    }
    
    /// 删除最后一个子视频（发生错误时）
    fileprivate func deleteLastSubVideo() {
        guard videoArray.count > 0 else {
            return
        }
        let lastVide0Path = (taskPath as NSString).appendingPathComponent(videoArray.last!)
        let fm = FileManager.default
        if fm.fileExists(atPath: lastVide0Path) {
            try? fm.removeItem(atPath: lastVide0Path)
        }
        videoArray.removeLast()
        videoTimesArray.removeLast()
        DispatchQueue.main.async {
            if self.delegate != nil, self.delegate!.responds(to: #selector(LJVideoRecorderMangerDelegate.videoRecorderManagerRecordingDidUpdate(_:_:))) {
                self.delegate!.videoRecorderManagerRecordingDidUpdate!(self, self.duration)
            }
        }
    }
}



// MARK: - open methods
extension LJVideoRecorderManager {
    
    /// 开始预览
    open func startPreview() {
        print("startPreview")
        addSyncLock {
            if self.isPreviewing {
                return
            }
            self.isVideoPreviewing = true
            self.videoRecordState = .unStarted
            self.captureSession.startRunning()
        }
    }
    
    ///停止预览
    open func stopPreview() {
        print("stopPreview")
        addSyncLock {
            if !self.isPreviewing {
                return
            }
            self.isVideoPreviewing = false
            if self.isRecording {
                self.stopRecording()
            }
            self.videoRecordState = .unStarted
            self.captureSession.stopRunning()
        }
    }
    
    ///开始录制
    open func startRecording() {
        print("startRecording")
        addSyncLock {
            if self.isRecording {
                return
            }
            self.videoRecordState = .recording
            self.startTime = kCMTimeZero
            self.configureVideoRecordEncoder()
        }
    }
    
    ///停止录制
    open func stopRecording() {
        print("stopRecording")
        addSyncLock {
            if self.isPuased {
                return
            }
            self.videoRecordState = .puased
            self.videoTimesArray.append(self.currentFragDuration)
            self.currentFragDuration = kCMTimeZero
            self.videoRecordEncoder?.finishedWithCompletionHanlder({ 
                DispatchQueue.main.async {
                    if self.delegate != nil,
                        self.delegate!.responds(to: #selector(LJVideoRecorderMangerDelegate.videoRecorderManagerDidStoppedRecording(_:))) {
                        self.delegate!.videoRecorderManagerDidStoppedRecording!(self)
                    }
                }
            })
            self.videoRecordEncoder = nil
        }
    }
    
    ///完成录制
    open func finishRecording(_ completion:(()->())?) {
        print("finishRecording")
        addSyncLock {
            if self.isCompletion {
                return
            }
            if self.isRecording {
                self.videoRecordState = .puased
                self.videoTimesArray.append(self.currentFragDuration)
                self.currentFragDuration = kCMTimeZero
                self.videoRecordEncoder?.finishedWithCompletionHanlder(nil)
                self.videoRecordEncoder = nil
                self.finishRecording(completion)
                return
            }
            self.videoRecordState = .completed
            self.mergedToDestinationVideo(completion)
        }
    }
    
    /// 切换前后摄像头
    open func switchCameraPostion() {
        addSyncLock { 
            self.captureQueue.async { [weak self] in
                self?.switchCamera()
            }
            self.addAnimationForCameraSwitch()
        }
    }
    
    /// 切换相机手电筒状态 - open
    open func switchTorchState() {
        addSyncLock { 
            self.captureQueue.async { [weak self] in
                self?.changeToruchState()
            }
        }
    }
}


// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate & AVCaptureAudioDataOutputSampleBufferDelegate
extension LJVideoRecorderManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ captureOutput: AVCaptureOutput!, didDrop sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        
        if captureOutput == videoDataOutput {
            print("didDrop - videoDataOutput")
            return
        }
        
        if captureOutput == audioDataOutput {
            print("didDrop - audioDataOutput")
            return
        }
    }
    /**
     CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
     CIImage *sourceImage = [CIImage imageWithCVPixelBuffer:(CVPixelBufferRef)imageBuffer options:nil];
     CGRect sourceExtent = sourceImage.extent;
     
     CIFilter * vignetteFilter = [CIFilter filterWithName:@"CIVignetteEffect"];
     [vignetteFilter setValue:sourceImage forKey:kCIInputImageKey];
     [vignetteFilter setValue:[CIVector vectorWithX:sourceExtent.size.width/2 Y:sourceExtent.size.height/2] forKey:kCIInputCenterKey];
     [vignetteFilter setValue:@(sourceExtent.size.width/2) forKey:kCIInputRadiusKey];
     CIImage *filteredImage = [vignetteFilter outputImage];
     
     CIFilter *effectFilter = [CIFilter filterWithName:@"CIPhotoEffectInstant"];
     [effectFilter setValue:filteredImage forKey:kCIInputImageKey];
     filteredImage = [effectFilter outputImage];
     */
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        addSyncLock { 
            if self.audioSampleRate == 0 || self.audioChannels == 0 { // 获取 音频采样率 和 轨道
                let sampleDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
                let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(sampleDescription!)?.pointee
                self.audioSampleRate = asbd?.mSampleRate ?? 0
                self.audioChannels = asbd?.mChannelsPerFrame ?? 0
            }
            
            //添加滤镜
            if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                let sourceImage = CIImage(cvPixelBuffer: imageBuffer, options: nil)
//                let sourceImage = CIImage(cvImageBuffer: imageBuffer, options: nil)
                let sourceExtent = sourceImage.extent
                let vignetteFilter = CIFilter(name: "CIVignetteEffect")
                vignetteFilter?.setValue(sourceImage, forKey: kCIInputImageKey)
                vignetteFilter?.setValue(CIVector(x: sourceExtent.width / 2, y: sourceExtent.height / 2), forKey: "kCIInputCenterKey")
                vignetteFilter?.setValue(sourceExtent.width / 2, forKey: kCIInputRadiusKey)
                var filteredImage = vignetteFilter?.outputImage
                let effectFilter = CIFilter(name: "CIPhotoEffectInstant")
                effectFilter?.setValue(filteredImage, forKey: kCIInputImageKey)
                filteredImage = effectFilter?.outputImage
            }
            
            
            guard self.isRecording,
                let videoRecordEncoder = self.videoRecordEncoder else {
                    return
            }
            
            
            var isVideoDataOutput = false
            if captureOutput == self.videoDataOutput {
                isVideoDataOutput = true
            }
            
            _ = videoRecordEncoder.encodeVideoAndAudio(sampleBuffer: sampleBuffer, isVideo: isVideoDataOutput)
            
            let duration = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            if self.startTime.value == 0 {
                self.startTime = duration
            }
            
            self.currentFragDuration = CMTimeSubtract(duration, self.startTime)
            if self.duration > self.maximumDuration {
                if self.duration - self.maximumDuration < 0.1 {
                    if self.delegate != nil , self.delegate!.responds(to: #selector(LJVideoRecorderMangerDelegate.videoRecorderManagerRecordingDidUpdate(_:_:))) {
                        DispatchQueue.main.async {
                            self.delegate!.videoRecorderManagerRecordingDidUpdate!(self, Float(self.maximumDuration))
                        }
                    }
                }
                
                if self.isRecording {
                    self.finishRecording({
                        DispatchQueue.main.async {
                            if self.delegate != nil , self.delegate!.responds(to: #selector(LJVideoRecorderMangerDelegate.videoRecorderManagerDidFinishedRecordingWithMoreThanMaximumDuration(_:fileURL:))) {
                                let url = URL(fileURLWithPath: self.filePath)
                                self.delegate!.videoRecorderManagerDidFinishedRecordingWithMoreThanMaximumDuration!(self, fileURL: url)
                            }
                        }
                    })
                }
                return
            }
            
            if self.delegate != nil , self.delegate!.responds(to: #selector(LJVideoRecorderMangerDelegate.videoRecorderManagerRecordingDidUpdate(_:_:))) {
                DispatchQueue.main.async {
                    self.delegate!.videoRecorderManagerRecordingDidUpdate!(self, Float(self.duration))
                }
            }
        }
    }
}

extension LJVideoRecorderManager: CAAnimationDelegate {
    func animationDidStart(_ anim: CAAnimation) {
        videoConnection?.videoOrientation = .portrait
    }
}

// MARK: - private methods - video and audio merge
extension LJVideoRecorderManager {
    fileprivate func mergedToDestinationVideo(_ completion:(()->())?) {
        DispatchQueue.global().async {
            self.addSyncLock({
                let fm = FileManager.default
                if fm.fileExists(atPath: self.filePath) {
                    try? fm.removeItem(atPath: self.filePath)
                }
                
                let composition = self.compostionVideosAndAudios(self.videoArray)
                self.storeCompositionToVideos(composition, filePath: self.filePath) {
                    self.removeAllSubVideos()
                    DispatchQueue.main.async {
                        print("保存成功")
                        completion?()
                    }
                }
            })
        }
    }
    
    fileprivate func removeAllSubVideos() {
        guard videoArray.count > 0 else {
            return
        }
        
        let fm = FileManager.default
        for videoName in videoArray {
            let videoPath = (taskPath as NSString).appendingPathComponent(videoName)
            try? fm.removeItem(atPath: videoPath)
        }
        videoArray.removeAll()
        videoTimesArray.removeAll()
        if self.delegate != nil , self.delegate!.responds(to: #selector(LJVideoRecorderMangerDelegate.videoRecorderManagerRecordingDidUpdate(_:_:))) {
            DispatchQueue.main.async {
                self.delegate!.videoRecorderManagerRecordingDidUpdate!(self, Float(self.duration))
            }
        }
    }
    
    fileprivate func storeCompositionToVideos(_ compositon: AVComposition, filePath: String, completion:(()->())?) {
        guard let assetExport = AVAssetExportSession(asset: compositon, presetName: AVAssetExportPreset1280x720) else {
            return
        }
        assetExport.outputFileType = AVFileTypeMPEG4
        assetExport.outputURL = URL(fileURLWithPath: filePath)
        assetExport.exportAsynchronously {
            completion?()
        }
    }
    
    fileprivate func compostionVideosAndAudios(_ videos: [String]) -> AVMutableComposition {
        let composition = AVMutableComposition()
        guard videos.count > 0 else {
            return composition
        }
        let videoTrack = composition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
        let audioTrack = composition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        
        var tempDuration: Float64 = 0.0
        for index in 0..<videos.count {
            let videoName = videos[index]
            let videoURL = URL(fileURLWithPath: (taskPath as NSString).appendingPathComponent(videoName))
            let videoAsset = AVAsset(url: videoURL)
            let videoAssetTrack = videoAsset.tracks(withMediaType: AVMediaTypeVideo)[0]
            let audioAssetTrack = videoAsset.tracks(withMediaType: AVMediaTypeAudio)[0]
            let assetTime = CMTimeRangeMake(kCMTimeZero, videoAsset.duration)
            
            try? videoTrack.insertTimeRange(assetTime, of: videoAssetTrack, at: CMTimeMakeWithSeconds(tempDuration, 0))
            try? audioTrack.insertTimeRange(assetTime, of: audioAssetTrack, at: CMTimeMakeWithSeconds(tempDuration, 0))
            tempDuration += CMTimeGetSeconds(videoAsset.duration)
        }
        return composition
    }
}


