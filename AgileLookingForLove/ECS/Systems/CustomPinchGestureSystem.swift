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
    public var speed: Float = 3.0
    public var distanceTraveled: Float = 0.0
    public var maxDistance: Float = 5.0
    
    public init(direction: SIMD3<Float>) {
        self.direction = direction
    }
}

public struct CustomPinchGestureSystem: System {
    static let query = EntityQuery(where: .has(IsDrawingComponent.self) && .has(ILHandAnchorComponent.self) && .has(DrawingComponent.self))
    static var lastShootTime = Date.distantPast
    
    public init(scene: Scene) {}
    
    public func update(context: SceneUpdateContext) {
        let loveBeamQuery = EntityQuery(where: .has(LoveBeamComponent.self))
        let loveBeams = context.entities(matching: loveBeamQuery, updatingSystemWhen: .rendering)
        var loveBeamIterator = loveBeams.makeIterator()
        guard let loveBeam = loveBeamIterator.next() else { return }
        
        let entities = context.entities(matching: Self.query, updatingSystemWhen: .rendering)
        
        var isHeartGestureActive = false
        var heartCenter = SIMD3<Float>(0, 0, 0)
        var beamDirection = SIMD3<Float>(0, 0, -1)
        
        HeadTracker.shared.update()
        if let headTransform = HeadTracker.shared.lastHeadTransform {
            let zAxis = headTransform.columns.2
            let forwardDir = -SIMD3<Float>(zAxis.x, zAxis.y, zAxis.z)
            beamDirection = simd_normalize(forwardDir)
        } else {
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
            
            // Detect two-handed heart gesture
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
            
            // Detect right hand middle-finger drawing pinch
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
        
        // Update particle beam and projectiles
        if isHeartGestureActive {
            loveBeam.position = heartCenter
            
            if let emitterEntity = loveBeam.findEntity(named: "ParticleEmitter") {
                if var vfx = emitterEntity.components[ParticleEmitterComponent.self] {
                    vfx.speed = 3.0
                    vfx.speedVariation = 0.5
                    vfx.mainEmitter.size = 0.05
                    vfx.mainEmitter.sizeMultiplierAtEndOfLifespan = 4.0
                    vfx.mainEmitter.sizeMultiplierAtEndOfLifespanPower = 1.0
                    vfx.mainEmitter.lifeSpan = 1.5
                    vfx.mainEmitter.birthRate = 25.0
                    vfx.mainEmitter.stretchFactor = 0.0
                    vfx.mainEmitter.acceleration = SIMD3<Float>(0, 1.5, 0)
                    vfx.mainEmitter.angleVariation = 0.15
                    
                    let from = SIMD3<Float>(0, 1, 0)
                    let to = beamDirection
                    emitterEntity.orientation = quaternionFromTo(from: from, to: to)
                    
                    if !vfx.isEmitting {
                        vfx.isEmitting = true
                    }
                    
                    let now = Date()
                    if now.timeIntervalSince(Self.lastShootTime) >= 0.5 {
                        Self.lastShootTime = now
                        
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
            if let emitterEntity = loveBeam.findEntity(named: "ParticleEmitter") {
                if var vfx = emitterEntity.components[ParticleEmitterComponent.self] {
                    if vfx.isEmitting {
                        vfx.isEmitting = false
                        emitterEntity.components.set(vfx)
                    }
                }
            }
        }
        
        // Update projectiles and collision detection
        let projectileQuery = EntityQuery(where: .has(LoveProjectileComponent.self))
        let projectiles = context.entities(matching: projectileQuery, updatingSystemWhen: .rendering)
        let deltaTime = Float(context.deltaTime)
        
        for projectile in projectiles {
            guard var projComp = projectile.components[LoveProjectileComponent.self] else { continue }
            
            let movement = projComp.direction * projComp.speed * deltaTime
            projectile.position += movement
            projComp.distanceTraveled += simd_length(movement)
            
            var hitTarget = false
            let shapesQuery = EntityQuery(where: .has(ShapeComponent.self) && .has(EntityStateComponent.self))
            let shapes = context.entities(matching: shapesQuery, updatingSystemWhen: .rendering)
            
            for shape in shapes {
                guard let stateComp = shape.components[EntityStateComponent.self],
                      (stateComp.state == .idle || stateComp.state == .walking) else { continue }
                
                let shapePos = shape.position(relativeTo: nil as Entity?)
                let dist = simd_distance(projectile.position, shapePos)
                
                if dist < 0.4 {
                    var mutableStateComp = stateComp
                    mutableStateComp.state = .stunned
                    mutableStateComp.stunTimer = 5.0
                    shape.components[EntityStateComponent.self] = mutableStateComp
                    
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
    
    private func quaternionFromTo(from: SIMD3<Float>, to: SIMD3<Float>) -> simd_quatf {
        let dot = simd_dot(from, to)
        if dot > 0.9999 {
            return simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        } else if dot < -0.9999 {
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
