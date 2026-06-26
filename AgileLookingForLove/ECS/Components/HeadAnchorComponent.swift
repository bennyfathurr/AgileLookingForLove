//
//  HeadAnchorComponent.swift
//  AgileLookingForLove
//

import RealityKit
import ARKit
import Foundation
import QuartzCore

public struct HeadAnchorComponent: Component {
    public init() {}
}

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
