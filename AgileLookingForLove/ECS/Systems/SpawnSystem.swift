//
//  SpawnSystem.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 23/06/26.
//

import RealityKit
import Foundation

final class SpawnSystem: System {
    static let query = EntityQuery(where: .has(ShapeComponent.self))
    
    private var spawnTimer: Double = 0.0
    private let spawnInterval: Double = 3.0
    private let maxEnties = 6
    
    required init(scene: Scene) {}
    
    func update(context: SceneUpdateContext) {
        spawnTimer += context.deltaTime
        guard spawnTimer >= spawnInterval else { return }
        spawnTimer = 0
        
        let existing = context.entities(matching: Self.query, updatingSystemWhen: .rendering)
        let existingCount = Array(existing).count
        guard existingCount < maxEnties else { return }
        
        NotificationCenter.default.post(name: .spawnEntityRequested, object: nil)
    }
}

extension Notification.Name {
    static let spawnEntityRequested = Notification.Name("spawnEntityRequested")
}
