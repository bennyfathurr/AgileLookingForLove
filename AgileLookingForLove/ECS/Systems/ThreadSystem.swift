//
//  ThreadSystem.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 23/06/26.
//

import RealityKit
import simd

final class ThreadSystem: System {
    static let query = EntityQuery(where: .has(ThreadAnchorComponent.self))
    
    required init(scene: Scene) {
    }
    
    func update(context: SceneUpdateContext) {
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let anchor = entity.components[ThreadAnchorComponent.self],
                  let partnerID = anchor.partnerID,
                  let partner = context.scene.findEntity(id: partnerID),
                  let threadEntity = anchor.threadEntity else { continue }
            
            // Update posisi & rotasi cylinder antara dua entity
            let startPos = entity.position(relativeTo: nil)
            let endPos   = partner.position(relativeTo: nil)
            
            let midPoint = (startPos + endPos) / 2
            let distance = simd_distance(startPos, endPos)
            
            threadEntity.position = midPoint
            threadEntity.look(at: endPos, from: midPoint, relativeTo: nil)
            
            // Scale cylinder panjangnya = distance
            threadEntity.scale = SIMD3(0.005, distance / 2, 0.005)
        }
    }
}
