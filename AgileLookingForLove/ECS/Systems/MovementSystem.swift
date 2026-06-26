//
//  MovementSystem.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 23/06/26.
//

import RealityKit
import simd
import Foundation

final class MovementSystem: System {
    static let query = EntityQuery(where: .has(ShapeComponent.self) && .has(EntityStateComponent.self))
    
    required init(scene: Scene) {}
    
    func update(context: SceneUpdateContext) {
        let env = context.scene.findEntity(named: "Environment")
        let center = env?.position(relativeTo: nil) ?? SIMD3<Float>(0, 0, 0)
        let limitRadius: Float = env != nil ? 1.5 : 4.0
        let limitY = center.y - 0.5
        
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var stateComp = entity.components[EntityStateComponent.self] else { continue }
            
            var pos = entity.position(relativeTo: nil)
            
            // Failsafe: if entity falls below the floor, reset it relative to center
            if pos.y < limitY {
                var newPos = entity.position
                newPos.y = center.y + 0.5
                newPos.x = center.x + Float.random(in: -0.5...0.5)
                newPos.z = center.z + Float.random(in: -0.5...0.5)
                entity.position = newPos
                pos = newPos // Update local pos variable
                
                var motion = entity.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
                motion.linearVelocity = .zero
                entity.components[PhysicsMotionComponent.self] = motion
            }
            
            if stateComp.state == .walking || stateComp.state == .idle {
                stateComp.changeDirTimer -= context.deltaTime
                if stateComp.changeDirTimer <= 0 {
                    let angle = Float.random(in: 0...(2 * .pi))
                    stateComp.direction = SIMD3<Float>(cos(angle), 0, sin(angle))
                    stateComp.changeDirTimer = Double.random(in: 1...3)
                }
                
                // Keep entities within the limit radius from the center
                let offset = pos - center
                let distanceXZ = sqrt(offset.x * offset.x + offset.z * offset.z)
                if distanceXZ > limitRadius {
                    // Turn back towards the center on the XZ plane
                    let toCenter = normalize(SIMD3<Float>(-offset.x, 0, -offset.z))
                    stateComp.direction = toCenter
                }
                
                // Rotate the entity to face its walking direction on the XZ plane
                if stateComp.direction.x != 0 || stateComp.direction.z != 0 {
                    let angle = atan2(stateComp.direction.x, stateComp.direction.z)
                    entity.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
                }
                
                let speed: Float = 0.2 // 20 cm/s
                var motion = entity.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
                
                // We keep the gravity velocity (Y) and override X and Z
                motion.linearVelocity = SIMD3<Float>(
                    stateComp.direction.x * speed,
                    motion.linearVelocity.y,
                    stateComp.direction.z * speed
                )
                
                // Prevent shapes from tumbling or rolling (keep upright)
                motion.angularVelocity = .zero
                
                entity.components[PhysicsMotionComponent.self] = motion
                entity.components[EntityStateComponent.self] = stateComp
            } else if stateComp.state == .stunned || stateComp.state == .connected {
                // When stunned or connected, stop movement entirely but preserve gravity Y velocity
                var motion = entity.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
                motion.linearVelocity = SIMD3<Float>(0, motion.linearVelocity.y, 0)
                motion.angularVelocity = .zero
                entity.components[PhysicsMotionComponent.self] = motion
            }
        }
    }
}
