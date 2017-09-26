//
//  LJVideoRecordEncoder
//  VideoRecorderDemo
//
//  Created by 一球 on 2017/9/26.
//  Copyright © 2017年 厉进虎. All rights reserved.
//

import UIKit
import CoreFoundation
import AVFoundation

class LJVideoRecordEncoder: NSObject {

    //MARK: - open properties
    open var filePath: String?
    
    //MARK: - private properties
    fileprivate var writer: AVAssetWriter? // 媒体写入对象
    fileprivate var videoInput: AVAssetWriterInput?// 视频写入
    fileprivate var audioInput: AVAssetWriterInput?// 音频写入
}

// MARK: - private methods - video and audio writer
extension LJVideoRecordEncoder {
    
    /// 初始化视频输入
    ///
    /// - Parameters:
    ///   - height: 视频分辨率height
    ///   - weight: 视频分辨率weight
    fileprivate func configureVideo(videoResolutionHeight height: Int, videoResolutionWeight weight: Int) {
        guard let writer = writer else {
            return
        }
        let settings: [String:Any] = [AVVideoCodecKey : AVVideoCodecH264,
                                      AVVideoWidthKey : weight,
                                      AVVideoHeightKey : height]
        videoInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: settings)
        videoInput?.expectsMediaDataInRealTime = true
        writer.add(videoInput!)
    }
    
    fileprivate func configureAudio(audioChannels channels: UInt32, audioSampleRate sampleRate: Float64) {
        guard let writer = writer else {
            return
        }
        let settings: [String:Any] = [AVFormatIDKey : kAudioFormatMPEG4AAC,
                                      AVNumberOfChannelsKey : channels,
                                      AVSampleRateKey : sampleRate,
                                      AVEncoderBitRateKey : 128000]
        audioInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: settings)
        audioInput?.expectsMediaDataInRealTime = true
        writer.add(audioInput!)
    }
}

extension LJVideoRecordEncoder {
    convenience init(filePath: String, videoResolutionHeight height: Int, videoResolutionWeight weight: Int, audioChannels channels: UInt32, audioSampleRate sampleRate: Float64) {
        self.init()
        self.filePath = filePath
        let fm = FileManager.default
        if fm.fileExists(atPath: filePath) {
            try? fm.removeItem(atPath: filePath)
        }
        do {
            writer = try AVAssetWriter(url: URL(fileURLWithPath: filePath), fileType: AVFileTypeMPEG4)
            writer!.shouldOptimizeForNetworkUse = true
            configureVideo(videoResolutionHeight: height, videoResolutionWeight: weight)
            if sampleRate != 0 && channels != 0 {
                configureAudio(audioChannels: channels, audioSampleRate: sampleRate)
            }
        } catch {
            print("初始化写入对象失败: \(error)")
        }
    }
    
    open func finishedWithCompletionHanlder(_ handler: (()->())?) {
        guard let writer = writer else {
            return
        }
        writer.finishWriting {
            handler?()
        }
    }
    
    open func encodeVideoAndAudio(sampleBuffer: CMSampleBuffer, isVideo: Bool) -> Bool {
        guard let writer = writer else {
            return false
        }
        
        if CMSampleBufferDataIsReady(sampleBuffer) {
            if writer.status == .unknown && isVideo {
                let startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                writer.startWriting()
                writer.startSession(atSourceTime: startTime)
            }
            
            if writer.status == .failed {
                let fm = FileManager.default
                if fm.fileExists(atPath: filePath!) {
                    print("file exists!")
                }
                print("writer error: \(writer.error.debugDescription)")
                return false
            }
            
            if isVideo {
                if videoInput!.isReadyForMoreMediaData {
                    videoInput!.append(sampleBuffer)
                    return true
                }
            } else {
                if audioInput!.isReadyForMoreMediaData {
                    audioInput!.append(sampleBuffer)
                    return true
                }
            }
        }
        return false
    }
}
