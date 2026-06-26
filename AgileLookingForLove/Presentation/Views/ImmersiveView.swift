//
//  ImmersiveView.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 22/06/26.
//

import SwiftUI
import RealityKit
import RealityKitContent
import ILSSpatialDraw
import ILSHandTracking
import ARKit

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel
    @State private var floorEntity: Entity? = nil
    private let trackingSession = SpatialTrackingSession()

    var body: some View {
        RealityView { (content: inout RealityViewContent, attachments: RealityViewAttachments) in
            SpawnSystem.registerSystem()
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
            DrawingSystem.registerSystem()
            
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
            
            let hands = HandEntitySpawner.spawnHands()
            var leftHandAnchor: Entity? = nil
            var rightHandAnchor: Entity? = nil
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
            
            appModel.viewModel.setContent(content)
            
            // Root entity for loaded items
            let sceneRoot = Entity()
            sceneRoot.name = "SceneRoot"
            content.add(sceneRoot)
            
            // Load templates and initial particle beam
            Task {
                await appModel.viewModel.loadTemplates()
                
                // Load Glove Meshes from main app bundle directly
                do {
                    if let leftURL = Bundle.main.url(forResource: "LeftGlove", withExtension: "usdz"),
                       let rightURL = Bundle.main.url(forResource: "RightGlove", withExtension: "usdz") {
                        
                        let leftGlove = try await ModelEntity(contentsOf: leftURL)
                        let rightGlove = try await ModelEntity(contentsOf: rightURL)
                        
                        if let leftAnchor = leftHandAnchor {
                            leftAnchor.addChild(leftGlove)
                            if var comp = leftAnchor.components[HandOverlayComponent.self] {
                                comp.gloveWrapper = leftGlove
                                comp.gloveModel = leftGlove
                                leftAnchor.components.set(comp)
                            }
                        }
                        
                        if let rightAnchor = rightHandAnchor {
                            rightAnchor.addChild(rightGlove)
                            if var comp = rightAnchor.components[HandOverlayComponent.self] {
                                comp.gloveWrapper = rightGlove
                                comp.gloveModel = rightGlove
                                rightAnchor.components.set(comp)
                            }
                        }
                        print("[ImmersiveView] Glove ModelEntities loaded directly from main bundle resources!")
                    } else {
                        print("[ImmersiveView] LeftGlove or RightGlove not found in main bundle.")
                    }
                } catch {
                    print("[ImmersiveView] Failed to load glove ModelEntities: \(error)")
                }
                
                do {
                    let loveShot = try await Entity(named: "Love Shot", in: realityKitContentBundle)
                    loveShot.name = "LoveBeam"
                    loveShot.components.set(LoveBeamComponent())
                    
                    if let emitter = loveShot.findEntity(named: "ParticleEmitter") {
                        if var vfx = emitter.components[ParticleEmitterComponent.self] {
                            vfx.isEmitting = false
                            emitter.components.set(vfx)
                        }
                    }
                    
                    sceneRoot.addChild(loveShot)
                    print("[ImmersiveView] Love Shot particle system loaded!")
                } catch {
                    print("[ImmersiveView] Failed to load Love Shot: \(error)")
                }
                
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                for _ in 0..<4 {
                    appModel.viewModel.spawnEntity()
                }
            }
            
            // Start room tracking session
            Task {
                let configuration = SpatialTrackingSession.Configuration(
                    tracking: [],
                    sceneUnderstanding: [.collision, .physics]
                )
                _ = await trackingSession.run(configuration)
                print("Spatial Tracking Session running successfully!")
            }
            
            // HUD placement relative to user head
            let headAnchor = AnchorEntity(.head)
            headAnchor.components.set(HeadAnchorComponent())
            if let hudEntity = attachments.entity(for: "HUDOverlay") {
                hudEntity.position = SIMD3<Float>(0.10, -0.15, -0.7)
                headAnchor.addChild(hudEntity)
            }
            content.add(headAnchor)
            
        } update: { (content: inout RealityViewContent, attachments: RealityViewAttachments) in
            appModel.viewModel.setContent(content)
        } attachments: {
            Attachment(id: "HUDOverlay") {
                HUDOverlayView(
                    instruction: appModel.viewModel.currentInstruction,
                    score: appModel.viewModel.score,
                    timeLeft: appModel.viewModel.instructionTimer,
                    connectionMessage: appModel.viewModel.lastConnectionMessage
                )
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    let entity = value.entity
                    let stateComp = entity.components[EntityStateComponent.self]
                    
                    if stateComp?.state == .idle || stateComp?.state == .walking {
                        appModel.viewModel.handleShoot(entity: entity)
                    }
                }
        )
        .onReceive(NotificationCenter.default.publisher(for: .spawnEntityRequested)) { _ in
            appModel.viewModel.spawnEntity()
        }
        .onReceive(NotificationCenter.default.publisher(for: .threadStrokeConnected)) { notif in
            guard let a = notif.userInfo?["entityA"] as? Entity,
                  let b = notif.userInfo?["entityB"] as? Entity else { return }
            let stroke = notif.userInfo?["strokeEntity"] as? Entity
            appModel.viewModel.handleThreadStroke(entityA: a, entityB: b, strokeEntity: stroke)
        }
        .onReceive(NotificationCenter.default.publisher(for: .stunEntityRequested)) { notif in
            if let entity = notif.userInfo?["entity"] as? Entity {
                appModel.viewModel.handleShoot(entity: entity)
            }
        }
        .task {
            let arSession = ARKitSession()
            _ = await arSession.requestAuthorization(for: [.handTracking, .worldSensing])
            await HeadTracker.shared.start()
            try? await HandTrackingService.shared.start()
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
