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
    enum GameState: Equatable {
        case menu
        case instructions
        case countdown(Int)
        case playing
        case gameOver(victory: Bool)
    }
    
    private let repository: GameStateRepository
    private let generateInstruction: GenerateInstructionUseCase
    private let connectEntities: ConnectEntityUseCase
    
    var gameState: GameState = .menu
    var gameTimeLeft: Double = 30.0
    var spawnAccumulator: Double = 0.0
    let spawnInterval: Double = 5.0
    
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
    
    // Persistent root entity added synchronously to RealityView.
    // All async entity additions use addChild() on this root to avoid closed-transaction errors.
    var rootEntity: Entity?
    
    var firstSelectedEntity: Entity?
    private var canvasEntity: Entity?
    
    // Environment placement properties
    var environmentEntity: Entity?
    var placementIndicator: Entity?
    
    private var activeEntities: [Entity] = []
    private let maxEntitiesCount: Int = 8
    private var spawnTimer: Double = 0.0
    //private let spawnInterval: Double = 5.0
    private let maxSpawnedEntities = 6
    
    var shapeTemplates: [ShapeKind: Entity] = [:]
    var shapeCenterOffsets: [ShapeKind: SIMD3<Float>] = [:]
    private var isSessionRestored = false
    
    func loadTemplates() async {
        do {
            let sphereTemplate = try await Entity(named: "Animation/bundar_walk_anim", in: realityKitContentBundle)
            let cubeTemplate = try await Entity(named: "Animation/kotak_walk_anim", in: realityKitContentBundle)
            let pyramidTemplate = try await Entity(named: "Animation/segitiga_walk_anim", in: realityKitContentBundle)
            
            setupTemplateCollision(sphereTemplate, for: .sphere)
            setupTemplateCollision(cubeTemplate, for: .cube)
            setupTemplateCollision(pyramidTemplate, for: .pyramid)
            
            shapeTemplates[.sphere] = sphereTemplate
            shapeTemplates[.cube] = cubeTemplate
            shapeTemplates[.pyramid] = pyramidTemplate
            
            print("[GameViewModel] Templates loaded successfully!")
        } catch {
            print("[GameViewModel] Error loading templates: \(error)")
        }
    }
    
    private func setupTemplateCollision(_ entity: Entity, for kind: ShapeKind) {
        var bounds = entity.computeAccumulatedBounds(relativeTo: entity)
        if bounds.isEmpty || (bounds.extents.x < 0.05 && bounds.extents.z < 0.05) {
            bounds = entity.visualBounds(relativeTo: entity)
        }
        
        var extents = bounds.extents
        var center = bounds.center
        
        // Fallback for templates if bounds are zero/invalid
        if extents.x < 0.05 || extents.z < 0.05 {
            print("[GameViewModel] Template \(kind) bounds are invalid or zero. Applying fallback dimensions.")
            extents = SIMD3<Float>(0.3, 0.3, 0.3)
            center = SIMD3<Float>(0.0, 0.15, 0.0) // Center at half height
        }
        
        shapeCenterOffsets[kind] = center
        
        let boxShape = ShapeResource.generateBox(width: extents.x, height: extents.y, depth: extents.z)
            .offsetBy(translation: center)
        entity.components.set(CollisionComponent(shapes: [boxShape]))
        entity.components.set(InputTargetComponent())
        print("[GameViewModel] Setup template collision for \(kind): extents=\(extents), center=\(center)")
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
    
    func setContent(_ content: RealityViewContent, root: Entity) {
        self.content = content
        self.rootEntity = root
        
        // Re-attach environment and minions to the new root entity when immersive space reopens.
        if let env = environmentEntity {
            if env.parent == nil {
                root.addChild(env)
            }
            
            if !isSessionRestored, !activeEntities.isEmpty, let envComp = env.components[EnvironmentComponent.self] {
                isSessionRestored = true
                let topY = env.position.y + envComp.topYOffset
                for entity in activeEntities {
                    var pos = entity.position
                    pos.y = topY + 0.05
                    
                    // Temporarily remove PhysicsBodyComponent to teleport dynamic physics body
                    let physicsBody = entity.components[PhysicsBodyComponent.self]
                    entity.components.remove(PhysicsBodyComponent.self)
                    entity.position = pos
                    if let physicsBody = physicsBody {
                        entity.components.set(physicsBody)
                    }
                    
                    var motion = entity.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
                    motion.linearVelocity = .zero
                    motion.angularVelocity = .zero
                    entity.components[PhysicsMotionComponent.self] = motion
                }
                print("[GameViewModel] Restored existing minions onto the environment platform.")
            }
        }
        
        for entity in activeEntities {
            if entity.parent == nil {
                root.addChild(entity)
            }
        }
    }
    
    func refreshInstruction() {
        let kinds = activeEntities.compactMap { $0.components[ShapeComponent.self]?.kind }
        let uniqueKinds = Array(Set(kinds))
        
        currentInstruction = generateInstruction.execute(availableKinds: uniqueKinds)
        instructionTimer = currentInstruction?.timeLimit ?? 10
    }
    
    func tickTimer(delta: Double) {
        guard case .playing = gameState else { return }
        
        // Tick instruction timer
        instructionTimer -= delta
        if instructionTimer <= 0 {
            refreshInstruction()
        }
        
        // Spawning is now handled by the periodic spawning logic below.
        
        // Tick global game timer
        gameTimeLeft -= delta
        if gameTimeLeft <= 0 {
            gameTimeLeft = 0
            gameState = .gameOver(victory: score >= 100)
            clearPlayingEntities()
        }
        
        score = repository.score
        if instructionTimer <= 0 { refreshInstruction() }
        
        // Periodic spawning logic to replace SpawnSystem (prevents duplicate spawning race conditions)
        if environmentEntity != nil {
            spawnTimer += delta
            if spawnTimer >= spawnInterval {
                spawnTimer = 0.0
                if activeEntities.count < maxSpawnedEntities {
                    if let env = environmentEntity {
                        let groundY = env.position(relativeTo: nil).y
                        spawnEntityAt(groundY: groundY)
                    }
                }
            }
        }
    }
    
    func handleShoot(entity: Entity) {
        guard var stateComp = entity.components[EntityStateComponent.self] else { return }
        
        guard stateComp.state == .idle || stateComp.state == .walking || stateComp.state == .stunned else { return }
        
        stateComp.state = .stunned
        stateComp.stunTimer = 5.0
        entity.components[EntityStateComponent.self] = stateComp
        
        entity.setStatusIndicator(color: .red)
        entity.stopAllAnimations(recursive: true)
    }
    
    func handleConnect(entity: Entity) {
        guard let stateComp = entity.components[EntityStateComponent.self],
              stateComp.state == .stunned,
              let shapeComp = entity.components[ShapeComponent.self],
              let content = self.content else { return }
        
        if firstSelectedEntity == nil {
            firstSelectedEntity = entity
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
    
    func spawnEntityAt(groundY: Float) {
        guard let root = self.rootEntity else {
            print("[Spawning] rootEntity is nil — cannot spawn yet.")
            return
        }
        
        // Enforce the max entity count limit
        guard activeEntities.count < maxEntitiesCount else {
            print("[Spawning] Maximum character limit reached (\(maxEntitiesCount)). Skipping spawn.")
            return
        }
        
        let kind = ShapeKind.allCases.randomElement()!
        print("[Spawning] Requesting spawn for shape kind: \(kind)")
        
        let entity: Entity
        if let template = shapeTemplates[kind] {
            entity = template.clone(recursive: true)
            // Remove any existing PhysicsBodyComponent from the clone; we'll add it after positioning
            entity.components.remove(PhysicsBodyComponent.self)
            print("[Spawning] Cloned template entity successfully.")
        } else {
            let mesh = kind.meshResource
            let color = colorFor(kind)
            let material = SimpleMaterial(color: color, isMetallic: true)
            let modelEntity = ModelEntity(mesh: mesh, materials: [material])
            modelEntity.generateCollisionShapes(recursive: false)
            entity = modelEntity
            entity.components.set(InputTargetComponent())
            print("[Spawning] Created fallback primitive shape entity.")
        }
        
        // Set ECS components (no physics yet)
        let centerOffset = shapeCenterOffsets[kind] ?? .zero
        entity.components[ShapeComponent.self] = ShapeComponent(kind: kind, localCenterOffset: centerOffset)
        entity.components[EntityStateComponent.self] = EntityStateComponent()
        
        // Step 1: Add to scene (no physics body) so world-space APIs work
        activeEntities.append(entity)
        root.addChild(entity)
        
        // Step 2: Set world-space position at exactly groundY — the platform slab top surface is there.
        // The entity collision box (offset from setupTemplateCollision) starts just above it.
        let spawnY = groundY
        if let env = environmentEntity, let envComp = env.components[EnvironmentComponent.self] {
            let envWorldPos = env.position(relativeTo: nil)
            let xOffset = Float.random(in: -envComp.radius * 0.6 ... envComp.radius * 0.6)
            let zOffset = Float.random(in: -envComp.radius * 0.6 ... envComp.radius * 0.6)
            entity.setPosition(SIMD3<Float>(envWorldPos.x + xOffset, spawnY, envWorldPos.z + zOffset), relativeTo: nil)
        } else {
            let x = Float.random(in: -1.2...1.2)
            let z = Float.random(in: -1.8 ... -1.0)
            entity.setPosition(SIMD3(x, spawnY, z), relativeTo: nil)
        }
        
        print("[Spawning] Entity at world pos \(entity.position(relativeTo: nil)). Total: \(activeEntities.count)")
        
        // Step 3: NOW add physics body — simulation starts from the correctly placed position
        let physicsBody = PhysicsBodyComponent(
            massProperties: .init(mass: 0.1),
            material: .default,
            mode: .dynamic
        )
        entity.components.set(physicsBody)
        
        if let animation = entity.availableAnimations.first {
            entity.playAnimation(animation.repeat(duration: .infinity), transitionDuration: 0.5)
            print("[Spawning] Started default animation.")
        }
    }
    
    private func colorFor(_ kind: ShapeKind) -> UIColor {
        switch kind {
        case .sphere:  return .systemRed
        case .cube:    return .systemBlue
        case .pyramid: return .systemGreen
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
        let points = makeThreadPoints(from: posA, to: posB, segments: 12, sag: 0.06)
        let descriptor = TubeMeshBuilder.generateMeshDescriptor(from: points, radius: 0.004)
        do {
            let mesh = try MeshResource.generate(from: [descriptor])
            var material = UnlitMaterial()
            material.color = .init(tint: UIColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1.0))
            let threadEntity = ModelEntity(mesh: mesh, materials: [material])
            threadEntity.name = "RedThread_\(entityA.id)_\(entityB.id)"
            
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
            p.y -= sag * sin(t * .pi)
            points.append(p)
        }
        return points
    }
    
    func handleThreadStroke(entityA: Entity, entityB: Entity, strokeEntity: Entity?) {
        guard let shapeA = entityA.components[ShapeComponent.self],
              let shapeB = entityB.components[ShapeComponent.self] else {
            print("[Connection] Entity does not have ShapeComponent")
            strokeEntity?.removeFromParent()
            return
        }
        
        let isValid = connectEntities.execute(
            fromShape: shapeA.kind,
            toShape: shapeB.kind
        )
        
        if isValid {
            connectionResult = .valid(fromShape: shapeA.kind, toShape: shapeB.kind)
            lastConnectionMessage = "CORRECT! \(shapeA.kind.displaySymbol) → \(shapeB.kind.displaySymbol) +100"
            score = repository.score
            
            markConnected(entityA)
            markConnected(entityB)
            
            activeEntities.removeAll(where: { $0 == entityA || $0 == entityB })
            
            setColor(.systemGreen, on: entityA)
            setColor(.systemGreen, on: entityB)
            
            if let strokeEntity {
                strokeEntity.name = "RedThread_\(entityA.id)_\(entityB.id)"
            }
            
            // Immediately remove thread on valid merge
            strokeEntity?.removeFromParent()
            if strokeEntity == nil {
                let threadName = "RedThread_\(entityA.id)_\(entityB.id)"
                if let parent = entityA.parent,
                   let thread = parent.children.first(where: { $0.name == threadName }) {
                    thread.removeFromParent()
                }
            }
            
            // Calculate midpoint for the merge
            let posA = entityA.position(relativeTo: nil)
            let posB = entityB.position(relativeTo: nil)
            let midpoint = (posA + posB) / 2.0
            
            // Add Merge animation, remove physics & old animations
            entityA.components.remove(PhysicsBodyComponent.self)
            entityB.components.remove(PhysicsBodyComponent.self)
            entityA.stopAllAnimations(recursive: true)
            entityB.stopAllAnimations(recursive: true)
            
            entityA.components.set(MergeAnimationComponent(midpoint: midpoint, startPosition: posA))
            entityB.components.set(MergeAnimationComponent(midpoint: midpoint, startPosition: posB))
            
            print("[Connection] VALID: \(shapeA.kind) → \(shapeB.kind) | Score: \(score)")
            
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                connectionResult = .none
                lastConnectionMessage = ""
            }
        } else {
            let instruction = currentInstruction?.description ?? "?"
            connectionResult = .invalid(fromShape: shapeA.kind, toShape: shapeB.kind)
            lastConnectionMessage = "WRONG! \(shapeA.kind.displaySymbol) → \(shapeB.kind.displaySymbol) | Instruction: \(instruction)"
            
            print("[Connection] INVALID: \(shapeA.kind) → \(shapeB.kind) | Instruction: \(instruction)")
            
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
    
    func setupPlacementIndicator() {
        guard self.environmentEntity == nil else {
            print("[GameViewModel] Environment already exists, skipping placement indicator.")
            return
        }
        guard let root = self.rootEntity else {
            print("[GameViewModel] rootEntity not set, cannot setup placement indicator.")
            return
        }
        
        if let indicator = self.placementIndicator {
            if indicator.parent == nil {
                root.addChild(indicator)
            }
            print("[GameViewModel] Existing placement indicator added back to scene.")
            return
        }
        
        let indicator = ModelEntity(
            mesh: .generateSphere(radius: 0.15),
            materials: [SimpleMaterial(color: UIColor.systemGreen.withAlphaComponent(0.5), isMetallic: false)]
        )
        indicator.name = "PlacementIndicator"
        indicator.position = SIMD3<Float>(0, 0, -1.5)
        
        // Enable collision and input target for drag gesture
        indicator.components.set(InputTargetComponent())
        indicator.generateCollisionShapes(recursive: false)
        
        self.placementIndicator = indicator
        root.addChild(indicator)
        print("[GameViewModel] New placement indicator spawned!")
    }
    
    func createEnvironment() {
        guard self.environmentEntity == nil else {
            print("[GameViewModel] Environment already exists!")
            return
        }
        guard let root = self.rootEntity, let indicator = self.placementIndicator else {
            print("[GameViewModel] Cannot create environment: rootEntity or indicator is nil")
            return
        }
        
        // Capture indicator world-space position before async
        let indicatorPosition = indicator.position(relativeTo: nil)
        
        Task {
            do {
                // Load envi.usdc from bundle (under Meshes/envi.usdc)
                let environment = try await Entity(named: "Meshes/envi", in: realityKitContentBundle)
                environment.name = "Environment"
                
                // Add to scene first, then set world position
                root.addChild(environment)
                environment.setPosition(indicatorPosition, relativeTo: nil)
                
                // Determine XZ size from visualBounds if available, fallback to 3x3m
                let bounds = environment.visualBounds(relativeTo: environment)
                let useWidth: Float = bounds.extents.x > 0.5 ? bounds.extents.x : 3.0
                let useDepth: Float = bounds.extents.z > 0.5 ? bounds.extents.z : 3.0
                
                print("[GameViewModel] Collider size: \(useWidth) x \(useDepth)")
                
                // Place collider AT the env pivot (y=0 relative to env).
                // The indicator WAS at the platform surface — so this is exactly the right height.
                // Thin 2cm slab. Top surface at exactly Y=0 in env-local space (= indicator placement = platform surface).
                // offsetBy moves center to Y=-0.01 so top is at Y=0.
                let boxShape = ShapeResource.generateBox(width: useWidth, height: 0.02, depth: useDepth)
                    .offsetBy(translation: SIMD3<Float>(0, -0.01, 0))
                
                environment.components.set(CollisionComponent(shapes: [boxShape], isStatic: true))
                environment.components.set(PhysicsBodyComponent(mode: .static))
                
                let wanderRadius = max(1.0, (useWidth / 2.0) - 0.2)
                // topYOffset = 0 (top surface is at env.y = indicator.y = platform surface)
                environment.components.set(EnvironmentComponent(radius: wanderRadius, topYOffset: 0))
                
                self.environmentEntity = environment
                indicator.isEnabled = false
                
                print("[GameViewModel] Environment ready at \(indicatorPosition), radius=\(wanderRadius)")
                
                // Spawn AT the indicator Y — entity's collision box bottom will rest exactly on the collider surface.
                let groundY = indicatorPosition.y
                for _ in 0..<4 {
                    spawnEntityAt(groundY: groundY)
                }
            } catch {
                print("[GameViewModel] Failed to load environment: \(error)")
            }
        }
    }
    
    func resetSession() {
        self.environmentEntity?.removeFromParent()
        self.environmentEntity = nil
        
        self.placementIndicator?.removeFromParent()
        self.placementIndicator = nil
        
        for entity in activeEntities {
            entity.removeFromParent()
        }
        self.activeEntities.removeAll()
        self.firstSelectedEntity = nil
        self.connectionResult = .none
        self.lastConnectionMessage = ""
        self.isSessionRestored = false
        print("[GameViewModel] Session state reset successfully!")
    }
    
    func prepareForReopen() {
        self.isSessionRestored = false
        print("[GameViewModel] Prepared session for reopening.")
    }
    
    func startCountdown() {
        gameState = .countdown(3)
        
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if case .countdown(3) = gameState {
                gameState = .countdown(2)
            } else { return }
            
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if case .countdown(2) = gameState {
                gameState = .countdown(1)
            } else { return }
            
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if case .countdown(1) = gameState {
                startGamePlay()
            }
        }
    }
    
    private func startGamePlay() {
        if environmentEntity != nil {
            if activeEntities.isEmpty {
                if let env = environmentEntity {
                    let groundY = env.position(relativeTo: nil).y
                    for _ in 0..<4 {
                        spawnEntityAt(groundY: groundY)
                    }
                }
            }
        }
        
        gameState = .playing
        gameTimeLeft = 30.0
        spawnAccumulator = 0.0
        repository.resetScore()
        score = 0
        
        refreshInstruction()
    }
    
    func clearPlayingEntities() {
        for entity in activeEntities {
            entity.removeFromParent()
        }
        activeEntities.removeAll()
        
        if let content = self.content {
            if let drawController = content.entities.first(where: { $0.name == "DrawController" }) {
                if var dc = drawController.components[DrawingComponent.self] {
                    dc.activeStrokeEntity = nil
                    dc.currentStrokeID = nil
                    dc.activeStrokePoints.removeAll()
                    dc.lastPlacedPosition = nil
                    dc.isGeneratingMesh = false
                    drawController.components.set(dc)
                }
                if var isDrawing = drawController.components[IsDrawingComponent.self] {
                    isDrawing.isActive = false
                    isDrawing.frameCount = 0
                    drawController.components.set(isDrawing)
                }
            }
            
            if let canvas = content.entities.first(where: { $0.name == "RedThreadCanvas" }) {
                canvas.children.removeAll()
            }
            
            let extraEntities = content.entities.filter { 
                ($0.name.hasPrefix("RedThread") && $0.name != "RedThreadCanvas") || 
                $0.name == "LoveProjectile" 
            }
            for entity in extraEntities {
                entity.removeFromParent()
            }
        }
        firstSelectedEntity = nil
    }
    
    func exitToMenu() {
        clearPlayingEntities()
        resetSession()
        gameState = .menu
    }
}

extension Entity {
    func computeAccumulatedBounds(relativeTo reference: Entity) -> BoundingBox {
        var combined: BoundingBox? = nil
        
        if let modelComp = self.components[ModelComponent.self] {
            let meshBounds = modelComp.mesh.bounds
            let transform = self.transformMatrix(relativeTo: reference)
            let localMin = meshBounds.min
            let localMax = meshBounds.max
            
            let corners = [
                SIMD3<Float>(localMin.x, localMin.y, localMin.z),
                SIMD3<Float>(localMin.x, localMin.y, localMax.z),
                SIMD3<Float>(localMin.x, localMax.y, localMin.z),
                SIMD3<Float>(localMin.x, localMax.y, localMax.z),
                SIMD3<Float>(localMax.x, localMin.y, localMin.z),
                SIMD3<Float>(localMax.x, localMin.y, localMax.z),
                SIMD3<Float>(localMax.x, localMax.y, localMin.z),
                SIMD3<Float>(localMax.x, localMax.y, localMax.z)
            ]
            
            for corner in corners {
                let transformedCorner4 = transform * SIMD4<Float>(corner.x, corner.y, corner.z, 1.0)
                let transformedCorner = SIMD3<Float>(transformedCorner4.x / transformedCorner4.w,
                                                     transformedCorner4.y / transformedCorner4.w,
                                                     transformedCorner4.z / transformedCorner4.w)
                if combined == nil {
                    combined = BoundingBox(min: transformedCorner, max: transformedCorner)
                } else {
                    combined!.formUnion(transformedCorner)
                }
            }
        }
        
        for child in children {
            let childBounds = child.computeAccumulatedBounds(relativeTo: reference)
            if childBounds.extents.x > 0.001 || childBounds.extents.z > 0.001 {
                if combined == nil {
                    combined = childBounds
                } else {
                    combined!.formUnion(childBounds)
                }
            }
        }
        
        return combined ?? BoundingBox(min: .zero, max: .zero)
    }
}
