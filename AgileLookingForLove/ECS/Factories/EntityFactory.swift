//
//  EntityFactory.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 01/07/26.
//

import RealityKit
import UIKit

@MainActor
public enum EntityFactory {
    
    static func createCharacter(kind: ShapeKind,template: Entity?,color: UIColor) -> Entity {
        
        let entity: Entity
        
        if let template = template {
            entity = template.clone(recursive: true)
            
            let bounds = entity.visualBounds(relativeTo: entity)
            let extents = bounds.extents
            let center = bounds.center
            
            let boxShape = ShapeResource.generateBox(width: extents.x, height: extents.y, depth: extents.z)
                .offsetBy(translation: center)
            entity.components.set(CollisionComponent(shapes: [boxShape]))
        } else {
            let mesh = kind.meshResource
            let material = SimpleMaterial(color: color, isMetallic: true)
            let modelEntity = ModelEntity(mesh: mesh, materials: [material])
            modelEntity.generateCollisionShapes(recursive: false)
            entity = modelEntity
        }
        
        entity.components.set(InputTargetComponent())
        
        //Spawn Distance
        let x = Float.random(in: -1.2...1.2)
        let y = Float.random(in: 0.4...0.8)
        let z = Float.random(in: -1.8 ... -1.0)
        entity.position = SIMD3(x, y, z)
        
        //Configure pyshic
        let physicsBody = PhysicsBodyComponent(
            massProperties: .init(mass: 0.1),
            material: .default,
            mode: .dynamic
        )
        entity.components.set(physicsBody)
        
        //Animation
        if let animation = entity.availableAnimations.first {
            entity.playAnimation(animation.repeat(duration: .infinity), transitionDuration: 0.5)
        }
        
        //ecs Component
        entity.components[ShapeComponent.self] = ShapeComponent(kind: kind)
        entity.components[EntityStateComponent.self] = EntityStateComponent()
        
        //back to caller
        return entity
    }
}
