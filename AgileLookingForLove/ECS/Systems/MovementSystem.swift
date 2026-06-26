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
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var stateComp = entity.components[EntityStateComponent.self] else { continue }
            
            var pos = entity.position(relativeTo: nil)
            
            // Failsafe check for falling shapes
            if pos.y < -0.2 {
                var newPos = entity.position
                newPos.y = 0.1
                entity.position = newPos
                pos.y = 0.1
                
                var motion = entity.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
                motion.linearVelocity.y = 0
                entity.components[PhysicsMotionComponent.self] = motion
            }
            
            if stateComp.state == .walking || stateComp.state == .idle {
                stateComp.changeDirTimer -= context.deltaTime
                if stateComp.changeDirTimer <= 0 {
                    let angle = Float.random(in: 0...(2 * .pi))
                    stateComp.direction = SIMD3<Float>(cos(angle), 0, sin(angle))
                    stateComp.changeDirTimer = Double.random(in: 1...3)
                }
                
                // max distance for the love
                let distanceXZ = sqrt(pos.x * pos.x + pos.z * pos.z)
                if distanceXZ > 4.0 {
                    let toOrigin = normalize(SIMD3<Float>(-pos.x, 0, -pos.z))
                    stateComp.direction = toOrigin
                }
                
                // Face the movement direction
                if stateComp.direction.x != 0 || stateComp.direction.z != 0 {
                    let angle = atan2(stateComp.direction.x, stateComp.direction.z)
                    entity.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
                }
                
                let speed: Float = 0.2
                var motion = entity.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
                
                motion.linearVelocity = SIMD3<Float>(
                    stateComp.direction.x * speed,
                    motion.linearVelocity.y,
                    stateComp.direction.z * speed
                )
                
                motion.angularVelocity = .zero
                
                entity.components[PhysicsMotionComponent.self] = motion
                entity.components[EntityStateComponent.self] = stateComp
            } else if stateComp.state == .stunned || stateComp.state == .connected {
                var motion = entity.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
                motion.linearVelocity = SIMD3<Float>(0, motion.linearVelocity.y, 0)
                motion.angularVelocity = .zero
                entity.components[PhysicsMotionComponent.self] = motion
            }
        }
    }
}
