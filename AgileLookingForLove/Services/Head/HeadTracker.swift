//
//  HeadTracker.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 01/07/26.
//

import ARKit
import Foundation
import RealityKit
import QuartzCore

//Arkit must be in main thread
@MainActor
public class HeadTracker {
    public static let shared = HeadTracker()
    
    private let arSession = ARKitSession()
    private let worldTracking = WorldTrackingProvider()
    private var isRunning = false
    
    public var lastHeadTransform: simd_float4x4? = nil
    
    public func start() async {
        guard !isRunning else { return }
        do {
            try await arSession.run([worldTracking])
            isRunning = true
            print("[HeadTracker] ARKit Session with WorldTrackingProvider started successfully!")
        } catch {
            print("[HeadTracker] Failed to start head tracking: \(error)")
        }
    }
    
    public func update() {
        guard isRunning else { return }
        if let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) {
            lastHeadTransform = deviceAnchor.originFromAnchorTransform
        }
    }
}
