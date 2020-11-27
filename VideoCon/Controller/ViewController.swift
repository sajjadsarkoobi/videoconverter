//
//  ViewController.swift
//  VideoCon
//
//  Created by Sajjad Sarkoobi on 11/25/20.
//

import UIKit
import AVKit

class ViewController: UIViewController {

    //MARK: IBOutlets:
    @IBOutlet weak var originalVideoContainer: UIView!
    @IBOutlet weak var playVideoButton: UIButton!
    @IBAction func playVideoButtonAction(_ sender: UIButton) {
        handlePlaying(avPlayer:originalPlayer)
    }
    
    @IBOutlet weak var originalSizeLabel: UILabel!

    @IBOutlet weak var bitRateButton: UIButton!
    @IBAction func bitRateButtonAction(_ sender: UIButton) {
        setBitRate()
    }
    
    @IBOutlet weak var outputSizeButton: UIButton!
    @IBAction func outputSizeButtonAction(_ sender: UIButton) {
        setOutPutSize()
    }
    
    @IBOutlet weak var convertButton: UIButton!
    @IBAction func convertButtonAction(_ sender: UIButton) {
        convert()
    }
    
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var convertedVideoContainer: UIView!

    @IBOutlet weak var playConvertedVideoButton: UIButton!
    @IBAction func playConvertedVideoButton(_ sender: UIButton) {
        handlePlaying(avPlayer:convertedPlayer)
    }
    
    
    @IBOutlet weak var convertedVideoSizeLabel: UILabel!
    
    @IBAction func deleteButtonAction(_ sender: UIButton) {
        deletConvertedFiles()
    }
    
    //MARK: Variables and Objecs
    private var originalPlayerController = AVPlayerViewController()
    private var originalPlayer: AVPlayer! {originalPlayerController.player}
    private var convertedPlayerController = AVPlayerViewController()
    private var convertedPlayer: AVPlayer! {convertedPlayerController.player}
    private var converter:VideoConverter = VideoConverter()
    private var convertedURLs: [URL] = []
    
    
    //MARK:DidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupVideoPlayers()
        setOriginalAsset()
    }
    

    //Setup the AVAssets and videoPayers inital data
    func setupVideoPlayers(){
        originalPlayerController.player = AVPlayer()
        originalPlayerController.showsPlaybackControls = false
        addChild(originalPlayerController)
        originalVideoContainer.addSubview(originalPlayerController.view)
        originalPlayerController.view.frame = originalVideoContainer.bounds
        
        convertedPlayerController.player = AVPlayer()
        convertedPlayerController.showsPlaybackControls = false
        addChild(convertedPlayerController)
        convertedVideoContainer.addSubview(convertedPlayerController.view)
        convertedPlayerController.view.frame = convertedVideoContainer.bounds
        playConvertedVideoButton.superview?.bringSubviewToFront(playConvertedVideoButton)
    }
    
    //Some UI stuff
    func setupUI(){
        bitRateButton.layer.cornerRadius = 5
        outputSizeButton.layer.cornerRadius = 5
        convertButton.layer.cornerRadius = 5
    }

    //Setting original video asset
    func setOriginalAsset(){
        let url = Bundle.main.resourceURL!.appendingPathComponent("videoSample.mp4")
       let originalAsset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        originalPlayer.replaceCurrentItem(with: AVPlayerItem(asset: originalAsset))
        calculateSize(fileURL: url, label: originalSizeLabel)
        originalPlayer.seek(to: CMTime(value: 10, timescale: 1))
    }
    
    //Set converted asset
    func setConvertedAsset(url:URL){
       let convertedAsset = AVAsset(url: url)
        convertedPlayer.replaceCurrentItem(with: AVPlayerItem(asset: convertedAsset))
        calculateSize(fileURL: url, label: convertedVideoSizeLabel)
    }
    
    //Handle play/stop of players
    func handlePlaying(avPlayer:AVPlayer){
        if avPlayer.isPlaying {
            avPlayer.pause()
        }else{
            avPlayer.seek(to: CMTime.zero)
            avPlayer.play()
        }
    }
    
    //Calculate the size of the video
    func calculateSize(fileURL : URL, label:UILabel){
        DispatchQueue.main.async {
            label.text = "Size: \(fileURL.fileSizeInMBString)"
        }
    }
    
    //Set the bit rate of video for converting
    func setBitRate(){
        let actionController = UIAlertController(title: "Bit rate", message: "Select video output bit rate", preferredStyle: .actionSheet)
        for item in VideoConverter.videoBitrateEnum.allCases {
            let action = UIAlertAction(title: "\(item)", style: .default) {[weak self] (name) in
                self?.bitRateButton.setTitle(name.title ?? "", for: .normal)
            }
            actionController.addAction(action)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        actionController.addAction(cancelAction)
        self.present(actionController, animated: true, completion: nil)
    }
    
    //Set the output video ratio
    func setOutPutSize(){
        let actionController = UIAlertController(title: "Size ratio", message: "Select video output size ratio", preferredStyle: .actionSheet)
        for item in VideoConverter.videoSizeEnum.allCases {
            let action = UIAlertAction(title: "\(item)", style: .default) {[weak self] (name) in
                self?.outputSizeButton.setTitle(name.title ?? "", for: .normal)
            }
            actionController.addAction(action)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        actionController.addAction(cancelAction)
        self.present(actionController, animated: true, completion: nil)
    }
    
    //Convert the original video
    func convert(){
        activityIndicator.startAnimating()
        guard let asset = originalPlayer.currentItem?.asset else { return }
        
        let selectedBitRate = VideoConverter.videoBitrateEnum.allCases.filter({"\($0)" == bitRateButton.title(for: .normal)}).first ?? .bitRate12o5
        converter.videoOutputBitRate = selectedBitRate
        
        let selectedVideoSize = VideoConverter.videoSizeEnum.allCases.filter({"\($0)" == outputSizeButton.title(for: .normal)}).first ?? .videoSize640x480
        converter.videoOutputSize = selectedVideoSize
        
        converter.compressVideo(asset: asset ) {[weak self] (success, url) in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
            }
            if success {
                if let url = url {
                    self?.convertedURLs.append(url)
                    DispatchQueue.main.async {
                        self?.setConvertedAsset(url: url)
                        self?.showMessage(title:"Convert completed",
                                          message: """
                                                    \(selectedBitRate)
                                                    \(selectedVideoSize)
                                                    converted size: \(url.fileSizeInMBString)
                                                   """)
                    }
                }
            }
        }
    }
    
    
    //Delete all converted URL from Temp folder
    func deletConvertedFiles(){
        convertedURLs.forEach { (url) in
            converter.removeFile(url: url) { (_, _) in
                self.convertedURLs.removeAll { (videoUrl) -> Bool in
                    videoUrl == url
                }
            }
        }
        print("convertedURLs: \(convertedURLs.count)")
        showMessage(title: "Deleted", message: "All converted files in temp folder deleted")
        convertedPlayer.replaceCurrentItem(with: nil)
    }
    
    
    //Show alert message
    func showMessage(title:String? = nil, message:String){
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let alertAction = UIAlertAction(title: "ok", style: .default, handler: nil)
        alertController.addAction(alertAction)
        self.present(alertController, animated: true, completion: nil)
    }
}
