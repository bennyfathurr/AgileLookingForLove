//
//  GameViewModel.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 23/06/26.
//

import ILSSpatialDraw
import RealityKit
import Observation
import UIKit
import _RealityKit_SwiftUI
import RealityKitContent

@Observable
@MainActor
final class GameViewModel {
    private let repository: GameStateRepository
    private let generateInstruction: GenerateInstructionUseCase
    private let connectEntities: ConnectEntityUseCase
    
    var currentInstruction: GameInstruction?
    var score: Int = 0
    var instructionTimer: Double = 0
    
    enum ConnectionResult {
        case none
        case valid(fromShape: ShapeKind, toShape: ShapeKind)
        case invalid(fromShape: ShapeKind, toShape: ShapeKind)
    }
    
    var connectionResult: ConnectionResult = .none
    var lastConnectionMessage: String = ""
    
    private var content: RealityViewContent?
    
    var firstSelectedEntity: Entity?
    private var canvasEntity: Entity?
    
    private var activeEntities: [Entity] = []
    private let maxEntitiesCount: Int = 8
    
    var shapeTemplates: [ShapeKind: Entity] = [:]
    
    func loadTemplates() async {
        do {
            let sphereTemplate = try await Entity(named: "bundar_walk_anim 2", in: realityKitContentBundle)
            let cubeTemplate = try await Entity(named: "kotak_walk_anim", in: realityKitContentBundle)
            let pyramidTemplate = try await Entity(named: "segitiga_walk_anim", in: realityKitContentBundle)
            
            shapeTemplates[.sphere] = sphereTemplate
            shapeTemplates[.cube] = cubeTemplate
            shapeTemplates[.pyramid] = pyramidTemplate
            
            print("[GameViewModel] Templates loaded successfully!")
        } catch {
            print("[GameViewModel] Error loading templates: \(error)")
        }
    }
    
    init(
        repository: GameStateRepository,
        generateInstruction: GenerateInstructionUseCase,
        connectEntities: ConnectEntityUseCase
    ) {
        self.repository = repository
        self.generateInstruction = generateInstruction
        self.connectEntities = connectEntities
    }
    
    convenience init() {
        let repository = InMemoryGameStateRepository()
        let generateInstruction = GenerateInstructionUseCase(repository: repository)
        let connectEntities = ConnectEntityUseCase(repository: repository)
        self.init(
            repository: repository,
            generateInstruction: generateInstruction,
            connectEntities: connectEntities
        )
        refreshInstruction()
    }
    
    func setContent(_ content: RealityViewContent) {
        self.content = content
        for entity in activeEntities {
            content.add(entity)
        }
    }
    
    func refreshInstruction() {
        // Collect all distinct shape kinds currently active in the room
        let kinds = activeEntities.compactMap { $0.components[ShapeComponent.self]?.kind }
        let uniqueKinds = Array(Set(kinds))
        
        currentInstruction = generateInstruction.execute(availableKinds: uniqueKinds)
        instructionTimer = currentInstruction?.timeLimit ?? 10
    }
    
    func tickTimer(delta: Double) {
        instructionTimer -= delta
        score = repository.score
        if instructionTimer <= 0 { refreshInstruction() }
    }

    func handleShoot(entity: Entity) {
        guard var stateComp = entity.components[EntityStateComponent.self],
              (stateComp.state == .idle || stateComp.state == .walking) else { return }

        // Ubah state ke stunned
        stateComp.state = .stunned
        stateComp.stunTimer = 5.0
        entity.components[EntityStateComponent.self] = stateComp

        // Visual feedback: entity jadi merah
        entity.setStatusIndicator(color: .red)
        
        // Stop animations when stunned
        entity.stopAllAnimations(recursive: true)
    }

    
    func handleConnect(entity: Entity) {
        guard let stateComp = entity.components[EntityStateComponent.self],
              stateComp.state == .stunned,
              let shapeComp = entity.components[ShapeComponent.self],
        let content = self.content else { return }
        
        if firstSelectedEntity == nil {
            firstSelectedEntity = entity   // pilih entity pertama
            highlightEntity(entity)
        } else {
            guard let first = firstSelectedEntity,
                  let firstShape = first.components[ShapeComponent.self] else { return }
            
            let isValid = connectEntities.execute(
                fromShape: firstShape.kind,
                toShape: shapeComp.kind
            )
            
            if isValid {
                createThreadBetween(first, entity, in: content)
                markConnected(first)
                markConnected(entity)
            }
            
            firstSelectedEntity = nil
            score = repository.score
        }
    }
    
    private func highlightEntity(_ entity: Entity) {
        if var model = entity.components[ModelComponent.self] {
            
            model.materials = [SimpleMaterial(color: .yellow, isMetallic: true)]
            entity.components[ModelComponent.self] = model
        }
    }
    
    private func markConnected(_ entity: Entity) {
        var stateComp = entity.components[EntityStateComponent.self] ?? EntityStateComponent()
        stateComp.state = .connected
        entity.components[EntityStateComponent.self] = stateComp
    }
    
    func spawnEntity(in content: RealityViewContent) {
        // Enforce the max entity count limit
        guard activeEntities.count < maxEntitiesCount else {
            print("[Spawning] Maximum character limit reached (\(maxEntitiesCount)). Skipping spawn.")
            return
        }
        
        let kind = ShapeKind.allCases.randomElement()!
        
        let entity: Entity
        if let template = shapeTemplates[kind] {
            entity = template.clone(recursive: true)
            
            let bounds = entity.visualBounds(relativeTo: entity)
            let extents = bounds.extents
            let center = bounds.center
            
            let boxShape = ShapeResource.generateBox(width: extents.x, height: extents.y, depth: extents.z)
                .offsetBy(translation: center)
            entity.components.set(CollisionComponent(shapes: [boxShape]))
        } else {
            let mesh = kind.meshResource
            let color = colorFor(kind)
            let material = SimpleMaterial(color: color, isMetallic: true)
            let modelEntity = ModelEntity(mesh: mesh, materials: [material])
            modelEntity.generateCollisionShapes(recursive: false)
            entity = modelEntity
        }
        
        entity.components.set(InputTargetComponent())
        
        // Random posisi di sekitar player
        let x = Float.random(in: -1.2...1.2)
        let y = Float.random(in: 0.4...0.8)
        let z = Float.random(in: -1.8 ... -1.0)
        entity.position = SIMD3(x, y, z)
        
        let physicsBody = PhysicsBodyComponent(
            massProperties: .init(mass: 0.1),
            material: .default,
            mode: .dynamic
        )
        entity.components.set(physicsBody)
        
        if let animation = entity.availableAnimations.first {
            entity.playAnimation(animation.repeat(duration: .infinity), transitionDuration: 0.5)
        }
        
        entity.components[ShapeComponent.self] = ShapeComponent(kind: kind)
        entity.components[EntityStateComponent.self] = EntityStateComponent()
        
        // Track the entity locally and add it to the scene
        activeEntities.append(entity)
        content.add(entity)
    }


    func spawnEntity() {
        guard let content = self.content else { return }
        spawnEntity(in: content)
    }
        
    private func colorFor(_ kind: ShapeKind) -> UIColor {
        switch kind {
        case .sphere:  return .systemBlue
        case .cube:    return .systemGreen
        case .pyramid: return .systemOrange
        }
    }
    
    func setCanvas(_ canvas: Entity) {
        self.canvasEntity = canvas
    }
    
    func getContent() -> RealityViewContent? {
        return self.content
    }
    
    private func createThreadBetween(_ entityA: Entity, _ entityB: Entity, in content: RealityViewContent) {
        let posA = entityA.position(relativeTo: nil)
        let posB = entityB.position(relativeTo: nil)
        // Buat titik-titik benang dengan sedikit sag agar terlihat alami
        let points = makeThreadPoints(from: posA, to: posB, segments: 12, sag: 0.06)
        let descriptor = TubeMeshBuilder.generateMeshDescriptor(from: points, radius: 0.004)
        do {
            let mesh = try MeshResource.generate(from: [descriptor])
            var material = UnlitMaterial()
            material.color = .init(tint: UIColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1.0))
            let threadEntity = ModelEntity(mesh: mesh, materials: [material])
            threadEntity.name = "RedThread_\(entityA.id)_\(entityB.id)"
            // Tambah ke canvas jika ada, atau langsung ke content
            if let canvas = canvasEntity {
                canvas.addChild(threadEntity)
            } else {
                content.add(threadEntity)
            }
        } catch {
            print("[RedThread] Failed to generate mesh: \(error)")
        }
    }
    
    private func makeThreadPoints(from start: SIMD3<Float>, to end: SIMD3<Float>, segments: Int = 12, sag: Float = 0.06) -> [SIMD3<Float>] {
        var points: [SIMD3<Float>] = []
        for i in 0...segments {
            let t = Float(i) / Float(segments)
            var p = start + (end - start) * t
            p.y -= sag * sin(t * .pi)   // catenary effect
            points.append(p)
        }
        return points
    }
    
    func handleThreadStroke(entityA: Entity, entityB: Entity, strokeEntity: Entity?) {
        guard let shapeA = entityA.components[ShapeComponent.self],
              let shapeB = entityB.components[ShapeComponent.self] else {
            print("[Connection] Entity tidak punya ShapeComponent")
            strokeEntity?.removeFromParent()
            return
        }

        let isValid = connectEntities.execute(
            fromShape: shapeA.kind,
            toShape: shapeB.kind
        )

        if isValid {
            // VALID
            connectionResult = .valid(fromShape: shapeA.kind, toShape: shapeB.kind)
            lastConnectionMessage = "BENAR! \(shapeA.kind.displaySymbol) → \(shapeB.kind.displaySymbol) +100"
            score = repository.score

            markConnected(entityA)
            markConnected(entityB)
            
            activeEntities.removeAll(where: {$0 == entityA || $0 == entityB})

            setColor(.systemGreen, on: entityA)
            setColor(.systemGreen, on: entityB)

            if let strokeEntity {
                strokeEntity.name = "RedThread_\(entityA.id)_\(entityB.id)"
            }

            // Clear entities and the thread after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                strokeEntity?.removeFromParent()
                
                if strokeEntity == nil {
                    let threadName = "RedThread_\(entityA.id)_\(entityB.id)"
                    if let parent = entityA.parent,
                       let thread = parent.children.first(where: { $0.name == threadName }) {
                        thread.removeFromParent()
                    }
                }
                
                entityA.removeFromParent()
                entityB.removeFromParent()
            }

            print("[Connection] VALID: \(shapeA.kind) → \(shapeB.kind) | Score: \(score)")

            // Auto clear result message setelah 2 detik
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                connectionResult = .none
                lastConnectionMessage = ""
            }

        } else {
            // INVALID
            let instruction = currentInstruction?.description ?? "?"
            connectionResult = .invalid(fromShape: shapeA.kind, toShape: shapeB.kind)
            lastConnectionMessage = "SALAH! \(shapeA.kind.displaySymbol) → \(shapeB.kind.displaySymbol) | Instruksi: \(instruction)"

            print("[Connection] INVALID: \(shapeA.kind) → \(shapeB.kind) | Instruksi: \(instruction)")

            // Remove the invalid connection line immediately
            strokeEntity?.removeFromParent()

            setColor(.red, on: entityA)
            setColor(.red, on: entityB)

            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                connectionResult = .none
                lastConnectionMessage = ""
            }
        }
    }
    
    private func setColor(_ color: UIColor, on entity: Entity) {
        entity.setStatusIndicator(color: color)
    }
}
