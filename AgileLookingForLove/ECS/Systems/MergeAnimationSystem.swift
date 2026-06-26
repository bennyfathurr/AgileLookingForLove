//
//  MergeAnimationSystem.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 26/06/26.
//

import RealityKit
import simd
import Foundation


class MergeAnimationSystem: System {

    static let query = EntityQuery(where: .has(MergeAnimationComponent.self))

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var merge = entity.components[MergeAnimationComponent.self] else { continue }
            merge.timer += dt

            switch merge.phase {

            case .converging:
                let t = min(merge.timer / MergeAnimationComponent.convergeDuration, 1.0)
                let ease = smoothstep(t)

                let newPos = mix(merge.startPosition, merge.midpoint, t: ease)
                entity.setPosition(newPos, relativeTo: nil)

                if merge.timer >= MergeAnimationComponent.convergeDuration {
                    merge.phase = .ascending
                    merge.timer = 0
                    entity.setPosition(merge.midpoint, relativeTo: nil)
                }

            case .ascending:
                let t = min(merge.timer / MergeAnimationComponent.ascendDuration, 1.0)

                var pos = merge.midpoint
                pos.y += smoothstep(t) * MergeAnimationComponent.totalAscentHeight
                entity.setPosition(pos, relativeTo: nil)

                let angle = merge.timer * .pi * 4.0
                entity.transform.rotation = simd_quatf(angle: angle, axis: [0, 1, 0])

                if merge.timer >= MergeAnimationComponent.ascendDuration {
                    merge.phase = .shrinking
                    merge.timer = 0
                }

            case .shrinking:
                let t = min(merge.timer / MergeAnimationComponent.shrinkDuration, 1.0)
                let scale = max(0, 1.0 - smoothstep(t))

                var peakPos = merge.midpoint
                peakPos.y += MergeAnimationComponent.totalAscentHeight
                entity.setPosition(peakPos, relativeTo: nil)
                entity.transform.scale = SIMD3<Float>(repeating: scale)

                if merge.timer >= MergeAnimationComponent.shrinkDuration {

                    entity.components.remove(MergeAnimationComponent.self)
                    entity.removeFromParent()

                    let entityID = entity.id
                    Foundation.DispatchQueue.main.async {
                        Foundation.NotificationCenter.default.post(
                            name: .entityMergeCompleted,
                            object: nil,
                            userInfo: ["entityID": entityID]
                        )
                    }
                    continue
                }
            }

            entity.components[MergeAnimationComponent.self] = merge
        }
    }

    // MARK: Helpers
    private func smoothstep(_ t: Float) -> Float {
        let c = max(0, min(t, 1))
        return c * c * (3 - 2 * c)
    }
}

extension Foundation.Notification.Name {
    static let entityMergeCompleted = Foundation.Notification.Name("entityMergeCompleted")
}
