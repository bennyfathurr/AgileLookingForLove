//
//  MergeAnimationComponent.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 26/06/26.
//

import RealityKit
import simd

struct MergeAnimationComponent: Component {
    enum Phase {
        case converging
        case ascending
        case shrinking
    }

    var phase: Phase = .converging

    var midpoint: SIMD3<Float> = .zero

    var startPosition: SIMD3<Float> = .zero

    var timer: Float = 0

    init(midpoint: SIMD3<Float>, startPosition: SIMD3<Float>) {
        self.phase = .converging
        self.midpoint = midpoint
        self.startPosition = startPosition
        self.timer = 0
    }

    static let convergeDuration: Float = 0.55
    static let ascendDuration:   Float = 0.75
    static let shrinkDuration:   Float = 0.45
    static let totalAscentHeight: Float = 0.55 
}
