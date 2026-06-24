//
//  EntityStateComponent.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 23/06/26.
//

import RealityKit

struct EntityStateComponent: Component {
    enum State {
        case idle
        case walking
        case stunned
        case connected
    }
    
    var state: State = .walking
    var stunTimer: Double = 0.0
    var connectedToID: Entity.ID?
    
    // Properties for horizontal wandering movement
    var direction: SIMD3<Float> = SIMD3<Float>(
        Float.random(in: -1...1),
        0,
        Float.random(in: -1...1)
    )
    var changeDirTimer: Double = Double.random(in: 1...3)
}
