//
//  BroadcastVC.swift
//  OpenLive
//
//  Created by cyril chaillan on 14/02/2020.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import AgoraRtcEngineKit

class BroadcastVC: UIViewController {

    @IBOutlet var vUser1: UIView!
    @IBOutlet var vUser2: UIView!
    
    var user2: UInt = 0
    
    private var agoraKit: AgoraRtcEngineKit {
        return dataSource!.liveVCNeedAgoraKit()
    }
    
    private var settings: Settings {
        return dataSource!.liveVCNeedSettings()
    }
    
    weak var dataSource: LiveVCDataSource?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        loadAgoraKit()
    }
    
    func setupLocalVideo() {
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = 0
        videoCanvas.view = vUser1
        videoCanvas.renderMode = .hidden
        agoraKit.setupLocalVideo(videoCanvas)
    }

    @IBAction func goBackTapped(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
}

private extension BroadcastVC {
    func loadAgoraKit() {
        guard let channelId = settings.roomName else {
            return
        }
        
//        setIdleTimerActive(false)
        
        // Step 1, set delegate to inform the app on AgoraRtcEngineKit events
        agoraKit.delegate = self
        // Step 2, set live broadcasting mode
        // for details: https://docs.agora.io/cn/Video/API%20Reference/oc/Classes/AgoraRtcEngineKit.html#//api/name/setChannelProfile:
        agoraKit.setChannelProfile(.liveBroadcasting)
        // set client role
        agoraKit.setClientRole(settings.role)
        
        // Step 3, Warning: only enable dual stream mode if there will be more than one broadcaster in the channel
        agoraKit.enableDualStreamMode(true)
        
        // Step 4, enable the video module
        agoraKit.enableVideo()
        // set video configuration
        agoraKit.setVideoEncoderConfiguration(
            AgoraVideoEncoderConfiguration(
                size: settings.dimension,
                frameRate: settings.frameRate,
                bitrate: AgoraVideoBitrateStandard,
                orientationMode: .adaptative
            )
        )
        
        // if current role is broadcaster, add local render view and start preview
        if settings.role == .broadcaster {
            addLocalSession()
            agoraKit.startPreview()
        }
        
        // Step 5, join channel and start group chat
        // If join  channel success, agoraKit triggers it's delegate function
        // 'rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int)'
        agoraKit.joinChannel(byToken: KeyCenter.Token, channelId: channelId, info: nil, uid: 0, joinSuccess: nil)
        
//        session.setCategory(AVAudioSession.CategoryOptions.mixWithOthers)
        // Step 6, set speaker audio route
        agoraKit.muteLocalAudioStream(false)
        agoraKit.enableAudio()
        agoraKit.enableLocalAudio(true)
        agoraKit.setEnableSpeakerphone(true)
    }
    
    func addLocalSession() {
        let localSession = VideoSession.localSession()
        localSession.updateInfo(fps: settings.frameRate.rawValue)
//        videoSessions.append(localSession)
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = 0
        videoCanvas.view = vUser1
        videoCanvas.renderMode = .hidden
        agoraKit.setupLocalVideo(videoCanvas)
//        agoraKit.setupLocalVideo(localSession.canvas)
    }
    
    func leaveChannel() {
        // Step 1, release local AgoraRtcVideoCanvas instance
        agoraKit.setupLocalVideo(nil)
        // Step 2, leave channel and end group chat
        agoraKit.leaveChannel(nil)
        
        // Step 3, if current role is broadcaster,  stop preview after leave channel
        if settings.role == .broadcaster {
            agoraKit.stopPreview()
        }
        
//        setIdleTimerActive(true)
        
        navigationController?.popViewController(animated: true)
    }
}

extension BroadcastVC: AgoraRtcEngineDelegate {
    
    // first remote video frame
    func rtcEngine(_ engine: AgoraRtcEngineKit, firstRemoteVideoDecodedOfUid uid: UInt, size: CGSize, elapsed: Int) {
        if user2 == 0 {
            user2 = uid
            vUser2.isHidden = false
            let videoCanvas = AgoraRtcVideoCanvas()
            videoCanvas.uid = uid
            videoCanvas.view = vUser2
            videoCanvas.renderMode = .hidden
            agoraKit.setupRemoteVideo(videoCanvas)
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        let session: AVAudioSession = AVAudioSession.sharedInstance()
        try! session.setCategory(AVAudioSession.Category.playAndRecord, options: AVAudioSession.CategoryOptions.mixWithOthers)
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        let session: AVAudioSession = AVAudioSession.sharedInstance()
        try! session.setCategory(AVAudioSession.Category.playAndRecord, options: AVAudioSession.CategoryOptions.mixWithOthers)
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        if user2 != 0 {
            vUser2.isHidden = true
        }
    }
    
    // warning code
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraWarningCode) {
        print("warning code: \(warningCode.description)")
    }
    
    // error code
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        print("warning code: \(errorCode.description)")
    }
}
