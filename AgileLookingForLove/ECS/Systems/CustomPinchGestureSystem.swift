//
//  CustomPinchGestureSystem.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 24/06/26.
//

import RealityKit
import Foundation
import ARKit
import ILSHandTracking
import ILSSpatialDraw
import UIKit

extension Notification.Name {
    static let stunEntityRequested = Notification.Name("stunEntityRequested")
}

public struct LoveProjectileComponent: Component {
    public var direction: SIMD3<Float>
    public var speed: Float = 3.0 // Kecepatan gerak forward (m/s) disamakan dengan speed partikel
    public var distanceTraveled: Float = 0.0
    public var maxDistance: Float = 5.0
    
    public init(direction: SIMD3<Float>) {
        self.direction = direction
    }
}

public struct CustomPinchGestureSystem: System {
    // Query untuk menarik entitas controller hand-tracking yang menggambar benang
    static let query = EntityQuery(where: .has(IsDrawingComponent.self) && .has(ILHandAnchorComponent.self) && .has(DrawingComponent.self))
    
    // Cooldown timer untuk trigger burst tembakan
    static var lastShootTime = Date.distantPast
    
    public init(scene: Scene) {}
    
    public func update(context: SceneUpdateContext) {
        // 1. Cari Love Beam particle entity di dalam scene
        let loveBeamQuery = EntityQuery(where: .has(LoveBeamComponent.self))
        let loveBeams = context.entities(matching: loveBeamQuery, updatingSystemWhen: .rendering)
        var loveBeamIterator = loveBeams.makeIterator()
        guard let loveBeam = loveBeamIterator.next() else {
            return
        }
        
        let entities = context.entities(matching: Self.query, updatingSystemWhen: .rendering)
        
        var isHeartGestureActive = false
        var heartCenter = SIMD3<Float>(0, 0, 0)
        var beamDirection = SIMD3<Float>(0, 0, -1) // default: forward
        
        // Update head tracker untuk mendapatkan arah pandang
        HeadTracker.shared.update()
        if let headTransform = HeadTracker.shared.lastHeadTransform {
            // Ambil forward vector (-Z dari head transform matrix)
            let zAxis = headTransform.columns.2
            let forwardDir = -SIMD3<Float>(zAxis.x, zAxis.y, zAxis.z)
            beamDirection = simd_normalize(forwardDir)
        } else {
            // Fallback ke traditional query jika tracker belum aktif
            let headQuery = EntityQuery(where: .has(HeadAnchorComponent.self))
            let heads = context.entities(matching: headQuery, updatingSystemWhen: .rendering)
            var headIterator = heads.makeIterator()
            if let head = headIterator.next() {
                let orientation = head.orientation(relativeTo: nil)
                beamDirection = orientation.act(SIMD3<Float>(0, 0, -1))
            }
        }
        
        for entity in entities {
            guard var isDrawingComp = entity.components[IsDrawingComponent.self],
                  let anchorComp = entity.components[ILHandAnchorComponent.self] else {
                continue
            }
            
            // --- DETEKSI GESTUR HATI DENGAN DUA TANGAN (🫶) ---
            if let leftHand = anchorComp.leftHand,
               let rightHand = anchorComp.rightHand,
               let leftSkeleton = leftHand.handSkeleton,
               let rightSkeleton = rightHand.handSkeleton,
               leftHand.isTracked,
               rightHand.isTracked {
                
                let leftIndexTip = ILHandPoseUtilities.worldPosition(of: .indexFingerTip, handAnchor: leftHand, skeleton: leftSkeleton)
                let rightIndexTip = ILHandPoseUtilities.worldPosition(of: .indexFingerTip, handAnchor: rightHand, skeleton: rightSkeleton)
                let leftThumbTip = ILHandPoseUtilities.worldPosition(of: .thumbTip, handAnchor: leftHand, skeleton: leftSkeleton)
                let rightThumbTip = ILHandPoseUtilities.worldPosition(of: .thumbTip, handAnchor: rightHand, skeleton: rightSkeleton)
                
                let indexDistance = simd_distance(leftIndexTip, rightIndexTip)
                let thumbDistance = simd_distance(leftThumbTip, rightThumbTip)
                
                let indexY = (leftIndexTip.y + rightIndexTip.y) / 2.0
                let thumbY = (leftThumbTip.y + rightThumbTip.y) / 2.0
                
                if indexDistance < 0.06 && thumbDistance < 0.06 && indexY > thumbY {
                    isHeartGestureActive = true
                    heartCenter = (leftIndexTip + rightIndexTip + leftThumbTip + rightThumbTip) / 4.0
                }
            }
            
            // --- GESTUR PINCH JARI TENGAH (MENGGAMBAR BENANG) ---
            if let rightHand = anchorComp.rightHand,
               let rightSkeleton = rightHand.handSkeleton,
               rightHand.isTracked {
                
                let middleTip = ILHandPoseUtilities.worldPosition(of: .middleFingerTip, handAnchor: rightHand, skeleton: rightSkeleton)
                let thumbTip = ILHandPoseUtilities.worldPosition(of: .thumbTip, handAnchor: rightHand, skeleton: rightSkeleton)
                
                let pinchDist = simd_distance(middleTip, thumbTip)
                let pinchActive = pinchDist < 0.02
                
                if pinchActive {
                    isDrawingComp.frameCount = min(isDrawingComp.frameCount + 1, 10)
                } else {
                    isDrawingComp.frameCount = max(isDrawingComp.frameCount - 1, 0)
                }
                isDrawingComp.isActive = (isDrawingComp.frameCount >= 3)
                
                if isDrawingComp.isActive {
                    isDrawingComp.tipPosition = middleTip
                }
            } else {
                isDrawingComp.frameCount = 0
                isDrawingComp.isActive = false
            }
            
            entity.components.set(isDrawingComp)
        }
        
        // --- UPDATE UTAMA PARTIKEL & HIT-SCAN (Sekali per frame, diluar loop entities) ---
        if isHeartGestureActive {
            loveBeam.position = heartCenter
            
            if let emitterEntity = loveBeam.findEntity(named: "ParticleEmitter") {
                if var vfx = emitterEntity.components[ParticleEmitterComponent.self] {
                    // Update emitter properties
                    vfx.speed = 3.0 // Slower, more visible speed
                    vfx.speedVariation = 0.5
                    
                    vfx.mainEmitter.size = 0.05 // start size
                    vfx.mainEmitter.sizeMultiplierAtEndOfLifespan = 4.0 // grow to 4x
                    vfx.mainEmitter.sizeMultiplierAtEndOfLifespanPower = 1.0
                    vfx.mainEmitter.lifeSpan = 1.5 // travel ~4.5 meters
                    // Continuous emission (burst-like stream)
                    vfx.mainEmitter.birthRate = 25.0 // thick continuous stream
                    vfx.mainEmitter.stretchFactor = 0.0 // no flat/gepeng
                    vfx.mainEmitter.acceleration = SIMD3<Float>(0, 1.5, 0)
                    vfx.mainEmitter.angleVariation = 0.15
                    
                    let from = SIMD3<Float>(0, 1, 0)
                    let to = beamDirection
                    emitterEntity.orientation = quaternionFromTo(from: from, to: to)
                    
                    if !vfx.isEmitting {
                        vfx.isEmitting = true
                    }
                    
                    // Cooldown trigger untuk spawn proxy projectile: 0.5 detik agar spaced out stuns
                    let now = Date()
                    if now.timeIntervalSince(Self.lastShootTime) >= 0.5 {
                        Self.lastShootTime = now
                        
                        // Spawn an invisible projectile proxy that tracks the burst arrival
                        let projectile = Entity()
                        projectile.name = "LoveProjectile"
                        projectile.position = heartCenter
                        projectile.components.set(LoveProjectileComponent(direction: beamDirection))
                        
                        if let parent = loveBeam.parent {
                            parent.addChild(projectile)
                        } else if let sceneRoot = context.scene.findEntity(named: "SceneRoot") {
                            sceneRoot.addChild(projectile)
                        } else {
                            loveBeam.addChild(projectile)
                        }
                    }
                    
                    emitterEntity.components.set(vfx)
                }
            }
        } else {
            // Matikan particle emitter jika gesture tidak aktif
            if let emitterEntity = loveBeam.findEntity(named: "ParticleEmitter") {
                if var vfx = emitterEntity.components[ParticleEmitterComponent.self] {
                    if vfx.isEmitting {
                        vfx.isEmitting = false
                        emitterEntity.components.set(vfx)
                    }
                }
            }
        }
        
        // --- UPDATE ALL ACTIVE PROJECTILES (Satu kali per frame, sinkronisasi tabrakan) ---
        let projectileQuery = EntityQuery(where: .has(LoveProjectileComponent.self))
        let projectiles = context.entities(matching: projectileQuery, updatingSystemWhen: .rendering)
        let deltaTime = Float(context.deltaTime)
        
        var cachedShapes: QueryResult<Entity>? = nil
        
        for projectile in projectiles {
            guard var projComp = projectile.components[LoveProjectileComponent.self] else { continue }
            
            let movement = projComp.direction * projComp.speed * deltaTime
            projectile.position += movement
            projComp.distanceTraveled += simd_length(movement)
            
            var hitTarget = false
            
            let activeShapes: QueryResult<Entity>
            if let cached = cachedShapes {
                activeShapes = cached
            } else {
                let shapesQuery = EntityQuery(where: .has(ShapeComponent.self) && .has(EntityStateComponent.self))
                let evaluated = context.entities(matching: shapesQuery, updatingSystemWhen: .rendering)
                cachedShapes = evaluated
                activeShapes = evaluated
            }
            
            for shape in activeShapes {
                    guard let stateComp = shape.components[EntityStateComponent.self],
                          (stateComp.state == .idle || stateComp.state == .walking) else { continue }
                    
                    let shapePos = shape.position(relativeTo: nil as Entity?)
                    let dist = simd_distance(projectile.position, shapePos)
                    
                    // Stun triggered exactly when the projectile arrives at the shape (0.4m radius)
                    if dist < 0.4 {
                        var mutableStateComp = stateComp
                        mutableStateComp.state = .stunned
                        mutableStateComp.stunTimer = 5.0
                        shape.components[EntityStateComponent.self] = mutableStateComp
                        
                        // Efek visual stun
                        NotificationCenter.default.post(
                            name: .stunEntityRequested,
                            object: nil,
                            userInfo: ["entity": shape]
                        )
                        
                        hitTarget = true
                        break
                    }
                }
                
                if hitTarget || projComp.distanceTraveled >= projComp.maxDistance {
                    projectile.removeFromParent()
                } else {
                    projectile.components.set(projComp)
                }
            }
    }
    
    /// Compute quaternion that rotates vector `from` to vector `to`
    private func quaternionFromTo(from: SIMD3<Float>, to: SIMD3<Float>) -> simd_quatf {
        let dot = simd_dot(from, to)
        if dot > 0.9999 {
            return simd_quatf(ix: 0, iy: 0, iz: 0, r: 1) // same direction
        } else if dot < -0.9999 {
            // 180° flip — find perpendicular axis
            var perp = simd_cross(from, SIMD3<Float>(0, 1, 0))
            if simd_length(perp) < 0.001 {
                perp = simd_cross(from, SIMD3<Float>(1, 0, 0))
            }
            return simd_quatf(angle: Float.pi, axis: simd_normalize(perp))
        }
        let cross = simd_cross(from, to)
        return simd_normalize(simd_quatf(ix: cross.x, iy: cross.y, iz: cross.z, r: 1.0 + dot))
    }
}
