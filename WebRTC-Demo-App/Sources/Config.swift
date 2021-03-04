//
//  Config.swift
//  WebRTC-Demo
//
//  Created by Stasel on 30/01/2019.
//  Copyright © 2019 Stasel. All rights reserved.
//

import Foundation

// Set this to the machine's address which runs the signaling server
//fileprivate let defaultSignalingServerUrl = URL(string: "wss://13.112.214.196:8443/player")!
fileprivate let defaultSignalingServerUrl = URL(string: "ws://172.20.10.5:5443/helloworld")!
//fileprivate let defaultSignalingServerUrl = URL(string: "wss://183.180.128.220:8443/player")!

// We use Google's public stun servers. For production apps you should deploy your own stun/turn servers.
fileprivate let defaultIceServers = ["stun:stun.l.google.com:19302",
                                     "stun:stun1.l.google.com:19302",
                                     "stun:stun2.l.google.com:19302",
                                     "stun:stun3.l.google.com:19302",
                                     "stun:stun4.l.google.com:19302"]

struct Config {
    let signalingServerUrl: URL
    let webRTCIceServers: [String]
    
    static let `default` = Config(signalingServerUrl: defaultSignalingServerUrl, webRTCIceServers: defaultIceServers)
}
