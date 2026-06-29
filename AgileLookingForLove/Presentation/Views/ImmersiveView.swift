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
            //Systems Register
            InstructionSystem.registerSystem()
            ThreadSystem.registerSystem()
            MovementSystem.registerSystem()
            ShapeComponent.registerComponent()
            EntityStateComponent.registerComponent()
            ThreadAnchorComponent.registerComponent()
            RedThreadValidationSystem.registerSystem()
            MergeAnimationComponent.registerComponent()
            MergeAnimationSystem.registerSystem()
            LoveBeamComponent.registerComponent()
            HeadAnchorComponent.registerComponent()
            LoveProjectileComponent.registerComponent()
            EnvironmentComponent.registerComponent()
            
            // Hand Overlay Setup
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
            
            // Persistent root entity for all async entity additions.
            // Must be created synchronously so rootEntity is available to the view model.
            let sceneRoot = Entity()
            sceneRoot.name = "SceneRoot"
            content.add(sceneRoot)
            
            appModel.viewModel.setContent(content, root: sceneRoot)
            appModel.viewModel.setupPlacementIndicator()
            
            // Load templates and spawn initial entities once templates are ready
            Task {
                await appModel.viewModel.loadTemplates()
                
                // Load Glove Meshes from RealityKitContent bundle
                do {
                    let leftGlove = try await Entity(named: "Meshes/LeftGlove", in: realityKitContentBundle)
                    let rightGlove = try await Entity(named: "Meshes/RightGlove", in: realityKitContentBundle)
                    
                    // Force all materials in glove models to be opaque
                    makeMaterialsOpaque(in: leftGlove)
                    makeMaterialsOpaque(in: rightGlove)
                    
                    if let leftAnchor = leftHandAnchor {
                        leftAnchor.addChild(leftGlove)
                        if var comp = leftAnchor.components[HandOverlayComponent.self] {
                            comp.gloveWrapper = leftGlove
                            comp.gloveModel = nil
                            leftAnchor.components.set(comp)
                        }
                    }
                    
                    if let rightAnchor = rightHandAnchor {
                        rightAnchor.addChild(rightGlove)
                        if var comp = rightAnchor.components[HandOverlayComponent.self] {
                            comp.gloveWrapper = rightGlove
                            comp.gloveModel = nil
                            rightAnchor.components.set(comp)
                        }
                    }
                    print("[ImmersiveView] Glove entities loaded directly from RealityKitContent bundle!")
                } catch {
                    print("[ImmersiveView] Failed to load glove entities: \(error)")
                }
                
                // OAD LOVE SHOT PARTICLE
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
                hudEntity.position = SIMD3<Float>(0.0, -0.05, -0.85)
                headAnchor.addChild(hudEntity)
            }
            content.add(headAnchor)
            
        } update: { (content: inout RealityViewContent, attachments: RealityViewAttachments) in
            // Update block: only update content reference; root is already persistent in the scene.
            if let root = appModel.viewModel.rootEntity {
                appModel.viewModel.setContent(content, root: root)
            }
        } attachments: {
            Attachment(id: "HUDOverlay") {
                HUDOverlayView(viewModel: appModel.viewModel)
            }
        }
//        .gesture(
//            SpatialTapGesture()
//                .targetedToAnyEntity()
//                .onEnded { value in
//                    let entity = value.entity
//                    let stateComp = entity.components[EntityStateComponent.self]
//                    
//                    if stateComp?.state == .idle || stateComp?.state == .walking {
//                        appModel.viewModel.handleShoot(entity: entity)
//                    }
//                }
//        )
        .gesture(
            DragGesture()
                .targetedToAnyEntity()
                .onChanged { value in
                    if value.entity.name == "PlacementIndicator" {
                        let parent = value.entity.parent ?? value.entity
                        value.entity.position = value.convert(value.location3D, from: .local, to: parent)
                    }
                }
        )
        .onReceive(NotificationCenter.default.publisher(for: .spawnEntityRequested)) { _ in
            let groundY = appModel.viewModel.environmentEntity?.position(relativeTo: nil).y ?? 0
            appModel.viewModel.spawnEntityAt(groundY: groundY)
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

    @MainActor
    private func makeMaterialsOpaque(in entity: Entity) {
        if var modelComp = entity.components[ModelComponent.self] {
            modelComp.materials = modelComp.materials.map { material in
                if var pbr = material as? PhysicallyBasedMaterial {
                    pbr.blending = .opaque
                    return pbr
                } else if var unlit = material as? UnlitMaterial {
                    unlit.blending = .opaque
                    return unlit
                }
                return material
            }
            entity.components.set(modelComp)
        }
        for child in entity.children {
            makeMaterialsOpaque(in: child)
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
