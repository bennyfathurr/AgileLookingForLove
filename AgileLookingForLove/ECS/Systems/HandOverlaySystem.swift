//
//  HandOverlaySystem.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 26/06/26.
//

import RealityKit
import ARKit
import ILSHandTracking
import Foundation
import UIKit

public class HandOverlaySystem: System {
    public static let query = EntityQuery(where: .has(HandOverlayComponent.self))

    required public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var overlay = entity.components[HandOverlayComponent.self] else { continue }
            
            // Wait until the glove model has been loaded and set
            guard let gloveWrapper = overlay.gloveWrapper else { continue }

            // Locate the ModelEntity from the loaded wrapper if we haven't yet
            if overlay.gloveModel == nil {
                overlay.gloveModel = findModelEntity(in: gloveWrapper)
            }

            // Get the latest hand anchor from HandTrackingService.shared based on chirality
            guard let handAnchor = (overlay.chirality == .left) ?
                HandTrackingService.shared.latestLeftHand :
                HandTrackingService.shared.latestRightHand
            else {
                // Hide glove root if anchor is not tracked or available
                gloveWrapper.isEnabled = false
                continue
            }

            guard handAnchor.isTracked, let skeleton = handAnchor.handSkeleton else {
                gloveWrapper.isEnabled = false
                continue
            }

            // Enable glove mesh
            gloveWrapper.isEnabled = true
            
            // Position the glove root at the hand anchor origin
            gloveWrapper.transform = Transform(matrix: handAnchor.originFromAnchorTransform)

            // Update joint rotations inside the ModelEntity using ARKit hand skeleton's index order
            if let gloveModel = overlay.gloveModel {
                let joints = skeleton.allJoints
                for (index, joint) in joints.enumerated() {
                    if index < gloveModel.jointTransforms.count {
                        let jointTransform = skeleton.joint(joint.name).parentFromJointTransform
                        gloveModel.jointTransforms[index].rotation = simd_quatf(jointTransform)
                    }
                }
            }

            entity.components[HandOverlayComponent.self] = overlay
        }
    }

    private func findModelEntity(in entity: Entity) -> ModelEntity? {
        if let model = entity as? ModelEntity {
            return model
        }
        for child in entity.children {
            if let found = findModelEntity(in: child) {
                return found
            }
        }
        return nil
    }
}
