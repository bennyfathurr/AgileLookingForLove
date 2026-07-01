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

//search about the view what
struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel
    private let trackingSession = SpatialTrackingSession()

    var body: some View {
        RealityView { (content: inout RealityViewContent, attachments: RealityViewAttachments) in
            
            let anchors = await GameSimulationBuilder.setupSimulation(in: &content, viewModel: appModel.viewModel, attachments: attachments, trackingSession: trackingSession)
            
            // Load templates and initial particle beam
            Task {
                
                await appModel.viewModel.loadTemplates()
                
                // Load Glove Meshes from RealityKitContent bundle
                do {
                    let leftGlove = try await Entity(named: "Meshes/LeftGlove", in: realityKitContentBundle)
                    let rightGlove = try await Entity(named: "Meshes/RightGlove", in: realityKitContentBundle)
                    
                    // Force all materials in glove models to be opaque
                    makeMaterialsOpaque(in: leftGlove)
                    makeMaterialsOpaque(in: rightGlove)
                    
                    anchors.leftHandAnchor.addChild(leftGlove)
                    if var comp = anchors.leftHandAnchor.components[HandOverlayComponent.self] {
                        comp.gloveWrapper = leftGlove
                        comp.gloveModel = nil
                        anchors.leftHandAnchor.components.set(comp)
                    }
                    
                    anchors.rightHandAnchor.addChild(rightGlove)
                    if var comp = anchors.rightHandAnchor.components[HandOverlayComponent.self] {
                        comp.gloveWrapper = rightGlove
                        comp.gloveModel = nil
                        anchors.rightHandAnchor.components.set(comp)
                    }
                    
                    print("[ImmersiveView] Glove entities loaded directly from RealityKitContent bundle!")
                } catch {
                    print("[ImmersiveView] Failed to load glove entities: \(error)")
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
                    
                    anchors.sceneRoot.addChild(loveShot)
                    
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
            appModel.viewModel.setContent(content)
        } attachments: {
            Attachment(id: "HUDOverlay") {
                HUDOverlayView(viewModel: appModel.viewModel)
            }
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
            await AudioManager.shared.preloadAllSounds()
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
