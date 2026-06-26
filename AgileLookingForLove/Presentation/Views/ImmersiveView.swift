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
    
    let sceneReconstruction = SceneReconstructionProvider(modes: [.classification])
    let arSession = ARKitSession()

    var body: some View {
        RealityView { (content: inout RealityViewContent, attachments: RealityViewAttachments) in
            //Systems Register
            SpawnSystem.registerSystem()
            InstructionSystem.registerSystem()
            ThreadSystem.registerSystem()
            MovementSystem.registerSystem()
            ShapeComponent.registerComponent()
            EntityStateComponent.registerComponent()
            ThreadAnchorComponent.registerComponent()
            OriginalMaterialsComponent.registerComponent()
            RedThreadValidationSystem.registerSystem()
            LoveBeamComponent.registerComponent()
            HeadAnchorComponent.registerComponent()
            LoveProjectileComponent.registerComponent()
            
            //ILDraw Package
            ILFeatureHandTrackingSetup.registerSystems()
                        
                        IsDrawingComponent.registerComponent()
                        DrawingComponent.registerComponent()
                        CanvasComponent.registerComponent()
                        SharePlayReceiverComponent.registerComponent()
                        
                        CustomPinchGestureSystem.registerSystem()
                        DrawingSystem.registerSystem()
            
            //Canvas Entity
            let canvas = Entity()
            canvas.name = "RedThreadCanvas"
            canvas.components.set(CanvasComponent())
            content.add(canvas)
            
            //DrawController
            let drawController = Entity()
            drawController.name = "DrawController"
            
            //Red Strting
            var drawComp = DrawingComponent()
            drawComp.currentColor = SIMD4<Float>(0.9, 0.1, 0.1, 1.0)
            drawComp.sphereRadius = 0.004
            drawController.components.set(drawComp)
            
            drawController.components.set(IsDrawingComponent())
            drawController.components.set(ILHandAnchorComponent())
            content.add(drawController)
            
            let hands = HandEntitySpawner.spawnHands()
            for hand in hands {content.add(hand)}
            
            // Add a fallback static floor collider so entities don't fall into the abyss before spatial tracking loads
            let fallbackFloor = Entity()
            fallbackFloor.name = "FallbackFloor"
            let floorShape = ShapeResource.generateBox(width: 50, height: 0.1, depth: 50)
            fallbackFloor.components.set(CollisionComponent(shapes: [floorShape], isStatic: true))
            fallbackFloor.components.set(PhysicsBodyComponent(mode: .static))
            fallbackFloor.position = SIMD3<Float>(0, -0.05, 0) // top surface is at y = 0
            content.add(fallbackFloor)
            
            appModel.viewModel.setContent(content)
            
            // Root entity for asynchronously loaded items (bypasses inout capture restriction)
            let sceneRoot = Entity()
            sceneRoot.name = "SceneRoot"
            content.add(sceneRoot)
            
            // Root entity for floors to bypass inout capture restriction
            let floorRoot = Entity()
            floorRoot.name = "FloorRoot"
            content.add(floorRoot)
            
            // Load templates and spawn initial entities once templates are ready
            Task {
                await appModel.viewModel.loadTemplates()
                
                // === LOAD LOVE SHOT PARTICLE ===
                do {
                    let loveShot = try await Entity(named: "Love Shot", in: realityKitContentBundle)
                    loveShot.name = "LoveBeam"
                    loveShot.components.set(LoveBeamComponent())
                    
                    if let emitter = loveShot.findEntity(named: "ParticleEmitter") {
                           if var vfx = emitter.components[ParticleEmitterComponent.self] {
                               vfx.isEmitting = false // Gunakan isEmitting
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
                try? await arSession.run([sceneReconstruction])
            }
            
            // Start scene reconstruction to find and spawn mesh floor
            Task {
                for await update in sceneReconstruction.anchorUpdates {
                    let anchor = update.anchor
                    let floorName = "MeshFloor_\(anchor.id)"
                    
                    switch update.event {
                    case .added, .updated:
                        if let floorEntity = await createVisualFloor(from: anchor) {
                            if let existingFloor = floorRoot.children.first(where: { $0.name == floorName }) {
                                floorRoot.removeChild(existingFloor)
                            }
                            floorRoot.addChild(floorEntity)
                        } else {
                            if let existingFloor = floorRoot.children.first(where: { $0.name == floorName }) {
                                floorRoot.removeChild(existingFloor)
                            }
                        }
                        
                    case .removed:
                        if let existingFloor = floorRoot.children.first(where: { $0.name == floorName }) {
                            floorRoot.removeChild(existingFloor)
                        }
                    }
                }
            }

            
            // UI
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

            // Start head tracker for querying head pose/anchor
            await HeadTracker.shared.start()

            try? await HandTrackingService.shared.start()
        }
        
    }
    
    // Helper function to create the visual floor mesh from MeshAnchor
    private func createVisualFloor(from anchor: MeshAnchor) async -> ModelEntity? {
        guard let floorMesh = try? generateFloorMesh(from: anchor.geometry) else { return nil }
        guard let collisionShape = try? await ShapeResource.generateStaticMesh(from: floorMesh) else { return nil }
        
        var material = SimpleMaterial()
        material.color = .init(tint: UIColor(red: 0.45, green: 0.30, blue: 0.15, alpha: 1.0)) // Dirt brown
        material.roughness = 0.9 // Matte finish
        
        let floorModel = ModelEntity(mesh: floorMesh, materials: [material])
        floorModel.name = "MeshFloor_\(anchor.id)"
        floorModel.transform = Transform(matrix: anchor.originFromAnchorTransform)
        floorModel.components.set(CollisionComponent(shapes: [collisionShape], isStatic: true))
        floorModel.components.set(PhysicsBodyComponent(mode: .static))
        
        return floorModel
    }
    
    // Generates a renderable MeshResource containing only faces classified as floor
    private func generateFloorMesh(from geometry: MeshAnchor.Geometry) throws -> MeshResource? {
        guard let classifications = geometry.classifications else { return nil }
        
        let faceCount = geometry.faces.count
        let bytesPerIndex = geometry.faces.bytesPerIndex
        let faceDataPointer = geometry.faces.buffer.contents()
        let classificationsPointer = classifications.buffer.contents().advanced(by: classifications.offset)
        
        var floorFaces = [Int]()
        for i in 0..<faceCount {
            let classStride = classifications.stride
            let classValue = classificationsPointer.advanced(by: i * classStride).assumingMemoryBound(to: UInt8.self).pointee
            if let classification = SurfaceClassification(rawValue: Int(classValue)), classification == .floor {
                floorFaces.append(i)
            }
        }
        
        guard !floorFaces.isEmpty else { return nil }
        
        // Extract vertices
        let vertices = geometry.vertices
        let vertexCount = vertices.count
        let vertexStride = vertices.stride
        let vertexDataPointer = vertices.buffer.contents().advanced(by: vertices.offset)
        
        var positions = [SIMD3<Float>]()
        positions.reserveCapacity(vertexCount)
        for i in 0..<vertexCount {
            let elementPointer = vertexDataPointer.advanced(by: i * vertexStride)
            let vertex = elementPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
            positions.append(vertex)
        }
        
        // Extract indices
        var indices = [UInt32]()
        indices.reserveCapacity(floorFaces.count * 3)
        
        for faceIndex in floorFaces {
            let faceOffset = faceIndex * 3 * bytesPerIndex
            for j in 0..<3 {
                let indexPointer = faceDataPointer.advanced(by: faceOffset + j * bytesPerIndex)
                if bytesPerIndex == 2 {
                    let index = indexPointer.assumingMemoryBound(to: UInt16.self).pointee
                    indices.append(UInt32(index))
                } else if bytesPerIndex == 4 {
                    let index = indexPointer.assumingMemoryBound(to: UInt32.self).pointee
                    indices.append(index)
                }
            }
        }
        
        var desc = MeshDescriptor()
        desc.positions = .init(positions)
        desc.primitives = .triangles(indices)
        
        return try MeshResource.generate(from: [desc])
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
