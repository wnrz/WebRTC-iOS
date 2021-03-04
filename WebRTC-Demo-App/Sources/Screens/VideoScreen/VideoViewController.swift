//
//  VideoViewController.swift
//  WebRTC
//
//  Created by Stasel on 21/05/2018.
//  Copyright © 2018 Stasel. All rights reserved.
//

import UIKit
import WebRTC

class VideoViewController: UIViewController {
    
    var localRenderer : RTCMTLVideoView!
    var remoteRenderer : RTCMTLVideoView!
    
    @IBOutlet private weak var localVideoView: UIView?
    @IBOutlet private weak var remoteVideoView: UIView?
    private let webRTCClient: WebRTCClient
    
    init(webRTCClient: WebRTCClient) {
        self.webRTCClient = webRTCClient
        super.init(nibName: String(describing: VideoViewController.self), bundle: Bundle.main)
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.webRTCClient.stopCapture(renderer: localRenderer, toRenderer: remoteRenderer)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        #if arch(arm64)
        // Using metal (arm64 only)
        localRenderer = RTCMTLVideoView(frame: self.localVideoView?.frame ?? CGRect.zero)
//        localRenderer.delegate = self
        remoteRenderer = RTCMTLVideoView(frame: self.remoteVideoView?.frame ?? CGRect.zero)
        localRenderer.videoContentMode = .scaleAspectFill
        remoteRenderer.videoContentMode = .scaleAspectFill
        #else
        // Using OpenGLES for the rest
        localRenderer = RTCEAGLVideoView(frame: self.localVideoView?.frame ?? CGRect.zero)
        remoteRenderer = RTCEAGLVideoView(frame: self.remoteVideoView.frame ?? CGRect.zero)
        #endif
        
        remoteRenderer.backgroundColor = .red
        self.webRTCClient.startCaptureLocalVideo(renderer: localRenderer)
        self.webRTCClient.renderRemoteVideo(to: remoteRenderer)
        
        if let localVideoView = self.localVideoView {
            self.embedView(localRenderer, into: localVideoView)
        }
//        localVideoView?.isHidden = true
        if let remoteVideoView = self.remoteVideoView {
            self.embedView(remoteRenderer, into: remoteVideoView)
        }
        remoteVideoView?.isHidden = true;
        self.view.sendSubviewToBack(remoteRenderer)
    }
    
    private func embedView(_ view: UIView, into containerView: UIView) {
        containerView.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[view]|",
                                                                    options: [],
                                                                    metrics: nil,
                                                                    views: ["view":view]))
        
        containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[view]|",
                                                                    options: [],
                                                                    metrics: nil,
                                                                    views: ["view":view]))
        containerView.layoutIfNeeded()
    }
    
    @IBAction private func backDidTap(_ sender: Any) {
        self.dismiss(animated: true)
    }
    
    @IBAction private func switchButton(_ sender: Any) {
        self.webRTCClient.switchCamera()
    }
}

typealias VideoViewControllerRTCVideoViewDelegate = VideoViewController
extension VideoViewControllerRTCVideoViewDelegate : RTCVideoRenderer {
    func setSize(_ size: CGSize) {
        
    }
    
    func renderFrame(_ frame: RTCVideoFrame?) {
        
    }
}

