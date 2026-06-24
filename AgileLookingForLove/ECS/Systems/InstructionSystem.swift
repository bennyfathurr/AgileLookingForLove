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
                }
                entity.components[EntityStateComponent.self] = stateComp
            }
        }
    }
    
    private func resetEntityVisual(_ entity: Entity) {
        guard let shapeComp = entity.components[ShapeComponent.self],
              var model = entity.components[ModelComponent.self] else { return }
        model.materials = [SimpleMaterial(color: colorFor(shapeComp.kind), isMetallic: true)]
        entity.components[ModelComponent.self] = model
    }
    
    private func colorFor(_ kind: ShapeKind) -> UIColor {
            switch kind {
            case .sphere:  return .systemBlue
            case .cube:    return .systemGreen
            case .pyramid: return .systemOrange
            }
        }
}
