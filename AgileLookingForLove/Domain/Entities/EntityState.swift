//
//  EntityState.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 22/06/26.
//

import RealityKit

enum EntityState: Sendable {
    case idle
    case stunned(remainingTime: Double)
    case walking
    case connected(to: Entity.ID)
}
