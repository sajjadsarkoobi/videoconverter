//
//  AVAssetWritter.swift
//  VideoTrimmerExample
//
//  Created by Sajjad Sarkoobi on 10/22/20.
//  Copyright © 2020 AveApps. All rights reserved.
//

import Foundation
import AVFoundation


protocol VideoConverterDelegate: AnyObject {
    func videoConverterFinished(url:URL)
    func videoConverterFinished(data:Data)
    func videoConverterCanceled(error: videoConverterError)
}


enum videoConverterError:String,Error {
    case inputFileError = "Input file error"
    case assetReaderInitErr = "Could not iniitalize asset reader probably"
    case audioOutputError = "Couldn't add audio output reader"
    case videoOutputError = "Couldn't add video output reader"
    case assetWriterError = "Asset writer was nil"
    case urlCreationFailed = "Failed to retrive URL of file"
    case dataCreationFailed = "Faild to create data from video"
}


final class VideoConverter {
    
    public typealias completionType = ((Bool,URL?) -> Void)
    var delegate:VideoConverterDelegate?
    
    private var assetWriter: AVAssetWriter!
    private var assetWriterVideoInput: AVAssetWriterInput!
    private var audioMicInput: AVAssetWriterInput!
    private var videoURL: URL!
    private var audioAppInput: AVAssetWriterInput!
    private var channelLayout = AudioChannelLayout()
    private var assetReader: AVAssetReader?
    private var bitrate: NSNumber = NSNumber(value: 1250000)
    private var videoConvertSize : videoSizeEnum = .videoSize960x540
    
    enum videoSizeEnum: CGFloat , CaseIterable{
        case videoSize640x480 = 480
        case videoSize960x540 = 540
        case videoSize1280x720 = 720
        case videoSize1920x1080 = 1080
    }
    
    enum videoBitrateEnum: NSNumber , CaseIterable{
        case bitRate12o5 = 1250000
        case bitRate25 = 2500000
        case bitRate30 = 3000000
        case defaultVideoRate = 0
    }

    //Set the video output frame
    public var videoOutputSize:videoSizeEnum = .videoSize960x540 {
        didSet {
            self.videoConvertSize = videoOutputSize
        }
    }
    
    
    //Set the video bitrate
    //it will affect the file size
    public var videoOutputBitRate : videoBitrateEnum = .bitRate25 {
        didSet (value){
            if value != .defaultVideoRate {
                self.bitrate = videoOutputBitRate.rawValue
            }else{
                self.bitrate = videoBitrateEnum.bitRate25.rawValue
            }
        }
    }
    
    
    //Compressing video based on AVAsset
    public func compressVideo(asset : AVAsset,completion: @escaping completionType) {
        startCompressingVideo(asset: asset) { (status, url) in
            completion(status,url)
        }
    }
    
    //Compressing video based on Video URL path
    public func compressVideo(videoUrl : URL,completion: @escaping completionType) {
        let asset = AVAsset(url: videoUrl)
        startCompressingVideo(asset: asset){ (status, url) in
            completion(status,url)
        }
    }
    
    //Removing a file at the specific URL
    public func removeFile(url at:URL,completion: @escaping completionType ){
        do {
        _ = try FileManager.default.removeItem(at: at)
            completion(true,nil)
        }catch {
            self.classLog(log: "delete file error -> \(at)")
            completion(false,nil)
        }
    }
    
    
    //MARK: ChecK video file
    private func checkVideoFileBeforeConvert(asset : AVAsset?) -> Bool {
        
        guard let asset = asset else {
            delegate?.videoConverterCanceled(error: .inputFileError)
            return false
        }
        
        if !asset.isPlayable {
            delegate?.videoConverterCanceled(error: .inputFileError)
            return false
        }
        
        if !asset.isReadable {
            delegate?.videoConverterCanceled(error: .inputFileError)
            return false
        }
    
        return true
    }
    
    //MARK: video compression
    private func startCompressingVideo(asset : AVAsset,completion: @escaping completionType) {
    
        //Check the asset before starting the conversion
        if !checkVideoFileBeforeConvert(asset: asset) {
            return
        }
        
        var audioFinished = false
        var videoFinished = false
        
        //create asset reader
        do {
            assetReader = try AVAssetReader(asset: asset)
        } catch {
            assetReader = nil
        }
        
        guard let reader = assetReader else {
            delegate?.videoConverterCanceled(error: .assetReaderInitErr)
            return
        }
        
        guard let videoTrack = asset.tracks(withMediaType: AVMediaType.video).first else {
            delegate?.videoConverterCanceled(error: .inputFileError)
            classLog(log: "videoTrack is empty")
            return
        }
        
        ///https://developer.apple.com/documentation/corevideo/cvpixelformatdescription/1563591-pixel_format_identifiers
        let videoReaderSettings: [String:Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB]
        
        let assetReaderVideoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: videoReaderSettings)
        
        var assetReaderAudioOutput: AVAssetReaderTrackOutput?
        if let audioTrack = asset.tracks(withMediaType: AVMediaType.audio).first {
            let audioReaderSettings: [String : Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2
            ]
            //AVEncoderBitRateKey: 96000
            
            assetReaderAudioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: audioReaderSettings)
            
            if reader.canAdd(assetReaderAudioOutput!) {
                reader.add(assetReaderAudioOutput!)
            } else {
                delegate?.videoConverterCanceled(error: .audioOutputError)
                return
            }
        }else{
            classLog(log: "audioTrack is empty")
        }
        
        if reader.canAdd(assetReaderVideoOutput) {
            reader.add(assetReaderVideoOutput)
        } else {
            delegate?.videoConverterCanceled(error: .videoOutputError)
            return
        }
        
        //Generate output height width:
        let outputSize = calculateVideoSize(initSize: videoTrack.naturalSize, size: videoConvertSize)
        
        
        //MARK: if videoOutputBitRate = default video rate
        if videoOutputBitRate == .defaultVideoRate {
            self.bitrate = NSNumber(value: asset.preferredRate)
            classLog(log: "default Video Rate: \(self.bitrate)")
        }
        
        //Create output video settings
        let videoSettings:[String:Any] = [
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: self.bitrate],
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoHeightKey: outputSize.height,
            AVVideoWidthKey: outputSize.width,
            AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill
        ]
        
        let audioSettings: [String:Any] = [AVFormatIDKey : kAudioFormatMPEG4AAC,
                                           AVNumberOfChannelsKey : 2,
                                           AVSampleRateKey : 44100.0,
                                           AVEncoderBitRateKey: 96000
        ]
        
        let audioInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioSettings)
        let videoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        videoInput.transform = videoTrack.preferredTransform
        
        
        //Queues for converterin procedures
        let videoInputQueue = DispatchQueue(label: "videoQueue")
        let audioInputQueue = DispatchQueue(label: "audioQueue")
        
        do {
            //Creat files based on time format
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
            let date = Date()
            let tempDir = NSTemporaryDirectory()
            let outputPath = "\(tempDir)/\(formatter.string(from: date)).mp4"
            let outputURL = URL(fileURLWithPath: outputPath)
            
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
            
        } catch {
            assetWriter = nil
        }
        
        guard let writer = assetWriter else {
            delegate?.videoConverterCanceled(error: .assetWriterError)
            return
        }
        
        writer.shouldOptimizeForNetworkUse = true
        writer.add(videoInput)
        writer.add(audioInput)
        
        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: CMTime.zero)
        
        audioInput.requestMediaDataWhenReady(on: audioInputQueue) { [weak self] in
            
            while(audioInput.isReadyForMoreMediaData) {
                if let cmSampleBuffer = assetReaderAudioOutput?.copyNextSampleBuffer() {
                    
                    audioInput.append(cmSampleBuffer)
                    
                } else {
                    audioInput.markAsFinished()
                    self?.classLog(log: "Audio converting finished")
                        audioFinished = true
                        if (audioFinished && videoFinished) {
                            self?.closeWriter(assetWriter: writer, completion: { (status, url) in
                                completion(status,url)
                            })
                        }
                    
                    break;
                }
            }
        }
    
        videoInput.requestMediaDataWhenReady(on: videoInputQueue) {[weak self] in
          
            // request data here
            while(videoInput.isReadyForMoreMediaData) {
                if let cmSampleBuffer = assetReaderVideoOutput.copyNextSampleBuffer() {
                    
                    videoInput.append(cmSampleBuffer)
                    
                } else {
                    videoInput.markAsFinished()
                    self?.classLog(log: "Video converting finished")
                        videoFinished = true
                        if (audioFinished && videoFinished) {
                            self?.closeWriter(assetWriter: writer) { (status, url) in
                                completion(status,url)
                            }
                        }
                    
                    break;
                }
            }
        }
    }
    
    
    //MARK: Closing the writer and create the output
    private func closeWriter(assetWriter: AVAssetWriter?,completion: @escaping completionType) {
        guard let assetWriter = assetWriter else {
            delegate?.videoConverterCanceled(error: .assetWriterError)
            return
        }
        
        assetWriter.finishWriting(completionHandler: { [weak self] in
            
            //MARK: Return URL of converted file
            self?.delegate?.videoConverterFinished(url: assetWriter.outputURL)
            self?.classLog(log: "Video File URL: \(assetWriter.outputURL)")
            completion(true,assetWriter.outputURL)
            do {
                let data = try Data(contentsOf: assetWriter.outputURL)
                self?.delegate?.videoConverterFinished(data: data)
               
            } catch let err as NSError {
                self?.classLog(log: "compressFile Error: \(err.localizedDescription)")
                self?.delegate?.videoConverterCanceled(error: .dataCreationFailed)
            }

        })
        
        self.assetReader?.cancelReading()
    }
    
    
    //Loging the Events
    private func classLog(log:String){
        #if DEBUG
        DispatchQueue.main.async {
            print("[VideoConverter] \(log)")
        }
        #endif
    }
    
    
    private func calculateVideoSize(initSize:CGSize,size to:videoSizeEnum) -> CGSize {
        
        if initSize.width > initSize.height {
            let width = (initSize.width*to.rawValue)/initSize.height
            return CGSize(width: width, height: to.rawValue)
        }else{
            let height = (initSize.height*to.rawValue)/initSize.width
            return CGSize(width: to.rawValue, height: height)
        }
    }
}
