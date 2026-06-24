//
//  InstructionSystem.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 23/06/26.
//

import RealityKit
import UIKit

//okay set everytime system is final class
final class InstructionSystem: System {
    static let query = EntityQuery(where: .has(EntityStateComponent.self))
    
    required init(scene: Scene) {}
    
    func update(context: SceneUpdateContext) {
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var stateComp = entity.components[EntityStateComponent.self] else { continue }
            
            if stateComp.state == .stunned {
                stateComp.stunTimer -= context.deltaTime
                if stateComp.stunTimer <= 0 {
                    stateComp.state = .idle
                    stateComp.stunTimer = 0
                    // Reset visual
                    resetEntityVisual(entity)
                    // Resume walk animation
                    if let animation = entity.availableAnimations.first {
                        entity.playAnimation(animation.repeat(duration: .infinity), transitionDuration: 0.5)
                    }
                }
                entity.components[EntityStateComponent.self] = stateComp
            }
        }
    }
    
    private func resetEntityVisual(_ entity: Entity) {
        entity.setStatusIndicator(color: nil)
    }
    
    private func colorFor(_ kind: ShapeKind) -> UIColor {
            switch kind {
            case .sphere:  return .systemBlue
            case .cube:    return .systemGreen
            case .pyramid: return .systemOrange
            }
        }
}
