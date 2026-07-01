//
//  GameSimulationBuilder.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 01/07/26.
//

import ARKit
import UIKit
import RealityKit
import RealityKitContent
import ILSHandTracking
import ILSSpatialDraw
import _RealityKit_SwiftUI

@MainActor
final class GameSimulationBuilder {
    
    //Reference for anchors 
    public struct SimulationAnchors{
        let leftHandAnchor: Entity
        let rightHandAnchor: Entity
        let sceneRoot: Entity
    }
    
    public static func setupSimulation(in content: inout RealityViewContent, viewModel: GameViewModel, attachments: RealityViewAttachments,trackingSession: SpatialTrackingSession) async -> SimulationAnchors {
        
        //ECS System and Components
        InstructionSystem.registerSystem()
        ThreadSystem.registerSystem()
        MovementSystem.registerSystem()
        ShapeComponent.registerComponent()
        EntityStateComponent.registerComponent()
        ThreadAnchorComponent.registerComponent()
        OriginalMaterialsComponent.registerComponent()
        RedThreadValidationSystem.registerSystem()
        MergeAnimationComponent.registerComponent()
        MergeAnimationSystem.registerSystem()
        LoveBeamComponent.registerComponent()
        HeadAnchorComponent.registerComponent()
        LoveProjectileComponent.registerComponent()
        HandOverlayComponent.registerComponent()
        HandOverlaySystem.registerSystem()
        
        // Register draw package systems
        ILFeatureHandTrackingSetup.registerSystems()
        IsDrawingComponent.registerComponent()
        DrawingComponent.registerComponent()
        CanvasComponent.registerComponent()
        SharePlayReceiverComponent.registerComponent()
        
        CustomPinchGestureSystem.registerSystem()
        CustomDrawingSystem.registerSystem()
        
        // Canvas setup
        let canvas = Entity()
        canvas.name = "RedThreadCanvas"
        canvas.components.set(CanvasComponent())
        content.add(canvas)
        
        // Draw controller setup
        let drawController = Entity()
        drawController.name = "DrawController"
        
        var drawComp = DrawingComponent()
        drawComp.currentColor = SIMD4<Float>(0.9, 0.1, 0.1, 1.0)
        drawComp.sphereRadius = 0.004
        drawController.components.set(drawComp)
        
        drawController.components.set(IsDrawingComponent())
        drawController.components.set(ILHandAnchorComponent())
        content.add(drawController)
        
        // Setup Entity
        let hands = HandEntitySpawner.spawnHands()
        
        var leftHandAnchor = Entity()
        var rightHandAnchor = Entity()
        
        for hand in hands {
            if hand.name == "LeftHandAnchor" {
                hand.components.set(HandOverlayComponent(chirality: .left))
                leftHandAnchor = hand
            } else if hand.name == "RightHandAnchor" {
                hand.components.set(HandOverlayComponent(chirality: .right))
                rightHandAnchor = hand
            }
            content.add(hand)
        }
        
        // Fallback floor collider
        let fallbackFloor = Entity()
        fallbackFloor.name = "FallbackFloor"
        let floorShape = ShapeResource.generateBox(width: 50, height: 0.1, depth: 50)
        fallbackFloor.components.set(CollisionComponent(shapes: [floorShape], isStatic: true))
        fallbackFloor.components.set(PhysicsBodyComponent(mode: .static))
        fallbackFloor.position = SIMD3<Float>(0, -0.05, 0)
        content.add(fallbackFloor)
        
        viewModel.setContent(content)
        
        // Root entity for loaded items
        let sceneRoot = Entity()
        sceneRoot.name = "SceneRoot"
        content.add(sceneRoot)
        
        // HUD
        let headAnchor = AnchorEntity(.head)
        headAnchor.components.set(HeadAnchorComponent())
        if let hudEntity = attachments.entity(for: "HUDOverlay") {
            hudEntity.position = SIMD3<Float>(0.0, -0.05, -0.85)
            headAnchor.addChild(hudEntity)
        }
        content.add(headAnchor)
        
        let configuration = SpatialTrackingSession.Configuration(
            tracking: [],
            sceneUnderstanding: [.collision, .physics]
        )
        _ = await trackingSession.run(configuration)
        
        return SimulationAnchors(
            leftHandAnchor: leftHandAnchor, rightHandAnchor: rightHandAnchor, sceneRoot: sceneRoot
        )
    }
}
