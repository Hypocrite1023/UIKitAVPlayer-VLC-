//
//  SettingViewController.swift
//  UIKitAVPlayer
//
//  Created by 邱翊均 on 2024/6/28.
//

import UIKit
import AVKit
import AVFoundation
import Combine
import MobileVLCKit

///啟動播放器需要至少一個參數 AVAsset, delegate?如果需要顯示剪輯時間
class PlayerViewController: UIViewController {
    
    //MARK: - Gesture
    var longTapHoldGesture: UIPanGestureRecognizer? //長按並拖動手指快轉
    var doubleTapGesture: UITapGestureRecognizer? //點兩下快轉
    var timeProcessBarGesture: UITapGestureRecognizer? //點進度條迅速調整播放時間段
    var singleTapToShowOrHideControlItemGesture: UITapGestureRecognizer? //單點控制顯示或隱藏控制介面
    
    var cancellables: Set<AnyCancellable> = []
    var playerItemPublisher: AnyCancellable?
    
    var panGestureStartPoint: CGPoint?
    // MARK: - clip 相關功能及變數宣告
    var clipComplete = true
    var clipRecord: [clipInfo] = []
    var tmpClipRecord: clipInfo?
    
    var playerView: PlayerView!
    var mediaPlayer: VLCMediaPlayer!
    var vlcMedia: VLCMedia?
    var mediaTotalTime: Int?
    var isPlayerControlVisible = true
    var idleTimer: Timer?
    
    weak var clipTableViewDataSourceDelegate: ClipRecordDelegate?
    
    init(vlcMedia: VLCMedia , frame: CGRect) {
        playerView = PlayerView(frame: frame)
        self.vlcMedia = vlcMedia
        self.playerView.frame = frame
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: - viewDidLoad()
    override func viewDidLoad() {
        super.viewDidLoad()
        // MARK: - 建構介面
        
        playerView.playerViewDelegate = self
        self.view.addSubview(playerView)
        mediaPlayer = VLCMediaPlayer()
        mediaPlayer.media = self.vlcMedia
        mediaPlayer.drawable = playerView.videoRenderView
        mediaPlayer.play()
        // 將影片總時長publish
        playerItemPublisher = mediaPlayer.media?.publisher(for: \.length)
            .sink {
                [weak self] length in
//                guard let lengthInt = length else { return }
                //設定影片總時長標籤
                let lengthInSecond = length.intValue / 1000
                self?.mediaTotalTime = Int(lengthInSecond)
                self?.playerView?.totalTimeLabel.text = String(format: "%02d:%02d:%02d", Int(lengthInSecond) / 3600, (Int(lengthInSecond) % 3600) / 60, Int(lengthInSecond) % 60)
                //取消訂閱
                self?.cancelTheDurationPublisher()
            }
        playerItemPublisher?.store(in: &cancellables)
        
        // MARK: - 設定播放器支持的手勢
        setupGesture()
        // MARK: ------------------
        // 開始播放
        mediaPlayer.play()
        playerView.playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        //每秒更新player的currentTime
//        Timer.publish(every: 1.0, on: .main, in: RunLoop.Mode.common)
//            .autoconnect()
//            .sink {
//                [weak self] _ in
//                guard let self = self else { return }
//                self.updateCurrentTime(time: mediaPlayer.time.value?.intValue)
//                if let mediaTotalTimeInSec = self.mediaTotalTime {
//                    if mediaTotalTimeInSec != 0 {
//                        playerView.totalProgressView.setProgress(Float(((mediaPlayer.time.value?.intValue ?? 0) / 1000) / mediaTotalTimeInSec), animated: true)
//                    }
//                }
//            }
//            .store(in: &cancellables)
        NotificationCenter.default.addObserver(self, selector: #selector(mediaPlayerStateChanged), name: .VLCMediaPlayerStateChanged, object: mediaPlayer)
        NotificationCenter.default.addObserver(self, selector: #selector(mediaPlayerCurrentTimeChanged), name: .VLCMediaPlayerTimeChanged, object: mediaPlayer)
        setupIdleTimer()
        
    }
    
    @objc func mediaPlayerCurrentTimeChanged(notification: NSNotification) {
        print("current time change")

        guard let mediaPlayer = notification.object as? VLCMediaPlayer else { return }
        self.updateCurrentTime(time: mediaPlayer.time.value?.intValue)
//        print(self.mediaTotalTime, Float(Float((mediaPlayer.time.value?.intValue ?? 0) / 1000) / 596))
        if let mediaTotalTimeInSec = self.mediaTotalTime {
            if mediaTotalTimeInSec != 0 {
                playerView.totalProgressView.setProgress(Float(Float((mediaPlayer.time.value?.intValue ?? 0) / 1000) / Float(mediaTotalTimeInSec)), animated: true)
            }
        }
    }
    @objc func mediaPlayerStateChanged(notification: NSNotification) {
        guard let mediaPlayer = notification.object as? VLCMediaPlayer else { return }
        switch mediaPlayer.state {
        case .buffering:
            print("Buffering...")
        case .playing:
            print("Playing...")
        case .stopped:
            print("Stopped")
        case .paused:
            print("Paused")
        case .ended:
            print("Ended")
        case .error:
            print("Error")
        default:
            break
        }
    }
    //MARK: - setup idleTimer
    func setupIdleTimer() {
        isPlayerControlVisible = true
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(hidePlayerControlIfNeed), userInfo: nil, repeats: false)
    }
    @objc func hidePlayerControlIfNeed() {
        if isPlayerControlVisible {
            hidePlayerControl()
            isPlayerControlVisible.toggle() // true -> false
        }
    }
    //MARK: - 設定手勢property
    fileprivate func setupGesture() {
        longTapHoldGesture = UIPanGestureRecognizer(target: self, action: #selector(longTapHoldSwipeGesture))
        longTapHoldGesture?.minimumNumberOfTouches = 1
        longTapHoldGesture?.maximumNumberOfTouches = 1
        self.view.addGestureRecognizer(longTapHoldGesture!)
        
        doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTap))
        doubleTapGesture?.numberOfTapsRequired = 2
        self.view.addGestureRecognizer(doubleTapGesture!)
        
        timeProcessBarGesture = UITapGestureRecognizer(target: self, action: #selector(seekTimeThroughTimePrcessBar))
        timeProcessBarGesture?.numberOfTapsRequired = 1
        playerView.totalProgressView.addGestureRecognizer(timeProcessBarGesture!)
        
        singleTapToShowOrHideControlItemGesture = UITapGestureRecognizer(target: self, action: #selector(singleTapToShowOrHideControlItem))
        singleTapToShowOrHideControlItemGesture?.numberOfTapsRequired = 1
        playerView.mergeView.addGestureRecognizer(singleTapToShowOrHideControlItemGesture!)
        
        singleTapToShowOrHideControlItemGesture?.require(toFail: doubleTapGesture!)
    }
    // MARK: - normal player function
    
    func updateCurrentTime(time: Int?) -> () {
        if let time = time {
            let currentTimeInSecond = time / 1000
    //        print(currentTimeInSecond)
            let hour = Int(currentTimeInSecond / 3600)
            let minute = (Int(currentTimeInSecond) % 3600) / 60
            let second = Int(currentTimeInSecond) % 60
            let timeLabel = String(format: "%02d:%02d:%02d", hour, minute, second)
            playerView.currentTimeLabel.text = timeLabel
        }
    }
    
    func cancelTheDurationPublisher() {
        playerItemPublisher?.cancel()
    }
    // MARK: - Gesture functions
    @objc func doubleTap(sender: UIGestureRecognizer) {
        showPlayerControl()
        setupIdleTimer()
        if sender.state == .ended {
            let location = sender.location(in: self.view)
            print(location.x, location.y)
            if location.x >= self.view.bounds.width / 2 {
                fastForwardVideo(sender: nil)
                playerView.fastForwardAnimateImageView.isHidden = false
                UIView.animateKeyframes(withDuration: 0.5, delay: 0, options: [], animations: {
                    UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.25) {
                        self.playerView.fastForwardAnimateImageView.bounds.size = CGSize(width: 100, height: 100)
                    }
                    UIView.addKeyframe(withRelativeStartTime: 0.25, relativeDuration: 0.25) {
                        self.playerView.fastForwardAnimateImageView.bounds.size = CGSize(width: 50, height: 50)
                    }
                }) {
                    _ in
                    self.playerView.fastForwardAnimateImageView.isHidden = true
                }
            } else {
                fastBackwardVideo(sender: nil)
                playerView.fastBackwardAnimateImageView.isHidden = false
                UIView.animateKeyframes(withDuration: 0.5, delay: 0, options: [], animations: {
                    UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.25) {
                        self.playerView.fastBackwardAnimateImageView.bounds.size = CGSize(width: 100, height: 100)
                    }
                    UIView.addKeyframe(withRelativeStartTime: 0.25, relativeDuration: 0.25) {
                        self.playerView.fastBackwardAnimateImageView.bounds.size = CGSize(width: 50, height: 50)
                    }
                }) {
                    _ in
                    self.playerView.fastBackwardAnimateImageView.isHidden = true
                }
            }
        }
    }
    
    @objc func longTapHoldSwipeGesture(sender: UIPanGestureRecognizer) {
        switch sender.state {
        case .possible:
            break
        case .began:
            print("began", sender.location(in: self.view))
            self.panGestureStartPoint = sender.location(in: self.view)
        case .changed:
            print("changed", sender.location(in: self.view))
            if let startPoint = self.panGestureStartPoint?.x {
                let currentPoint = sender.location(in: self.view)
                let threshold: CGFloat = 10.0 // 設定一個閾值來防止過於頻繁的觸發
                if currentPoint.x - startPoint > threshold {
//                    let newTime = CMTimeAdd(videoPlayerModel.player.currentTime(), CMTimeMake(value: 1, timescale: 1))
//                    videoPlayerModel.player.seek(to: newTime)
                    mediaPlayer.jumpForward(1)
                    self.panGestureStartPoint = currentPoint
//                    videoPlayerModel.player.isMuted = true
                    mediaPlayer.audio?.isMuted = true
                } else if startPoint - currentPoint.x > threshold {
//                    let newTime = CMTimeAdd(videoPlayerModel.player.currentTime(), CMTimeMake(value: -1, timescale: 1))
//                    videoPlayerModel.player.seek(to: newTime)
                    mediaPlayer.jumpBackward(1)
                    self.panGestureStartPoint = currentPoint
//                    videoPlayerModel.player.isMuted = true
                    mediaPlayer.audio?.isMuted = true
                }
            }
        case .ended:
            print("ended", sender.location(in: self.view))
//            videoPlayerModel.player.isMuted = false
            mediaPlayer.audio?.isMuted = false
            break
        case .cancelled:
//            videoPlayerModel.player.isMuted = false
            mediaPlayer.audio?.isMuted = false
            break
        case .failed:
//            videoPlayerModel.player.isMuted = false
            mediaPlayer.audio?.isMuted = false
            break
        @unknown default:
            break
        }
    }
    
    @objc func seekTimeThroughTimePrcessBar(sender: UITapGestureRecognizer) -> () {
        showPlayerControl()
        setupIdleTimer()
        print(sender.location(in: playerView.totalProgressView), playerView.totalProgressView.bounds.width)
        let seekTime = sender.location(in: playerView.totalProgressView).x / playerView.totalProgressView.bounds.width * ((mediaPlayer.media?.length.value as! CGFloat) / 1000)
        if seekTime > (mediaPlayer.time.value as! CGFloat) / 1000 {
            mediaPlayer.jumpForward(Int32(seekTime))
        } else {
            mediaPlayer.jumpBackward(Int32(seekTime))
        }
    }
    
    @objc func singleTapToShowOrHideControlItem(sender: UITapGestureRecognizer) -> () {
        if isPlayerControlVisible {
            hidePlayerControl()
        } else {
            showPlayerControl()
            setupIdleTimer()
        }
    }
    
    func hidePlayerControl() {
        isPlayerControlVisible = false
        for view in self.playerView.mergeView.subviews {
            view.isHidden = true
        }
    }
    
    func showPlayerControl() {
        isPlayerControlVisible = true
        for view in self.playerView.mergeView.subviews {
            view.isHidden = false
        }
    }
    
    func updateClipButtonStatus() -> () {
        playerView.clipStartButton.isHidden = !clipComplete
        playerView.clipEndButton.isHidden = clipComplete
    }
    
    // MARK: - when view transition this function will execute
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            if let windowScene = self.view.window?.windowScene {
                let orientation = windowScene.interfaceOrientation
                if orientation.isLandscape {
                    
                    self.playerView.frame = self.view.bounds
                    self.playerView.mergeView.frame = self.view.bounds
                    self.playerView.setupConstraints()
//                    self.playerView.playerLayer.videoGravity = .resizeAspect
                    print("橫向")
                } else if orientation.isPortrait {
                    self.playerView.frame = self.view.bounds
                    self.playerView.mergeView.frame = self.view.bounds
                    self.playerView.setupConstraints()
//                    self.playerView.playerLayer.videoGravity = .resizeAspect
                    print("縱向")
                }
            }
        }, completion: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        clipTableViewDataSourceDelegate = nil
        print("view disappear, delegate release")
    }
    //MARK: - deinit
    deinit {
        print("deinit VideoViewController")
        NotificationCenter.default.removeObserver(self, name: .VLCMediaPlayerStateChanged, object: nil)
    }
}



extension PlayerViewController: PlayerViewDelegate {
    func playOrPauseVideo(sender: UIButton) {
        if mediaPlayer.isPlaying {
            mediaPlayer.pause()
            playerView.playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        } else {
            mediaPlayer.play()
            playerView.playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
    }
    
    func fastForwardVideo(sender: UIButton?) {
//        let newTime = CMTimeAdd(videoPlayerModel.player.currentTime(), CMTimeMake(value: 10, timescale: 1))
//        videoPlayerModel.player.seek(to: newTime)
        mediaPlayer.jumpForward(10)
    }
    
    func fastBackwardVideo(sender: UIButton?) {
//        let newTime = CMTimeAdd(videoPlayerModel.player.currentTime(), CMTimeMake(value: -10, timescale: 1))
//        videoPlayerModel.player.seek(to: newTime)
        mediaPlayer.jumpBackward(10)
    }
    
    func closePlayer(sender: UIButton) {
//        for subview in self.view.subviews {
//            subview.removeFromSuperview()
//        }
        
        // 停止播放器
//        videoPlayerModel.player.pause()
        mediaPlayer.pause()
        
        // 取消所有的訂閱
        self.cancellables.forEach { $0.cancel() }
        self.cancellables.removeAll()
        
        clipTableViewDataSourceDelegate?.receiveClipRecord(clipRecord: self.clipRecord)
        // 解釋掉self.view.window?.rootViewController = nil
        // 這會導致返回到主頁面
        self.dismiss(animated: true, completion: nil)
    }
    // MARK: - 額外剪輯function
    func setClipEndPoint(sender: UIButton) -> () {
        print("clip end")
        clipComplete.toggle()
        if let currentTime = mediaPlayer.time.value?.intValue {
            let currentTimeInSecond = currentTime / 1000
            let hour = Int(currentTimeInSecond / 3600)
            let minute = (Int(currentTimeInSecond) % 3600) / 60
            let second = Int(currentTimeInSecond) % 60
            let timeLabel = String(format: "%02d:%02d:%02d", hour, minute, second)
            tmpClipRecord?.endTime = timeLabel
            if let tmpClipRecord = tmpClipRecord {
                clipRecord.append(tmpClipRecord)
            }
            self.tmpClipRecord = nil
            print(clipRecord.description)
        }
        UIView.animateKeyframes(withDuration: 0.5, delay: 0, animations: {
            let originalSize = self.playerView.clipEndButton.bounds.size
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.25) {
                self.playerView.clipEndButton.bounds.size = CGSize(width: originalSize.width + 10, height: originalSize.height + 10)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.25, relativeDuration: 0.25) {
                self.playerView.clipEndButton.bounds.size = originalSize
            }
        }) {
            _ in
            self.updateClipButtonStatus()
        }
    }
    func setClipStartPoint(sender: UIButton) -> () {
        print("clip start")
        clipComplete.toggle()
        if let currentTime = mediaPlayer.time.value?.intValue {
            let currentTimeInSecond = currentTime / 1000
            let hour = Int(currentTimeInSecond / 3600)
            let minute = (Int(currentTimeInSecond) % 3600) / 60
            let second = Int(currentTimeInSecond) % 60
            let timeLabel = String(format: "%02d:%02d:%02d", hour, minute, second)
            tmpClipRecord?.endTime = timeLabel
            if let tmpClipRecord = tmpClipRecord {
                clipRecord.append(tmpClipRecord)
            }
            self.tmpClipRecord = nil
            print(clipRecord.description)
        }
        UIView.animateKeyframes(withDuration: 0.5, delay: 0, animations: {
            let originalSize = self.playerView.clipStartButton.bounds.size
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.25) {
                self.playerView.clipStartButton.bounds.size = CGSize(width: originalSize.width + 10, height: originalSize.height + 10)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.25, relativeDuration: 0.25) {
                self.playerView.clipStartButton.bounds.size = originalSize
            }
        }) {
            _ in
            self.updateClipButtonStatus()
        }
        
        
//        updateClipButtonStatus()
    }
}
