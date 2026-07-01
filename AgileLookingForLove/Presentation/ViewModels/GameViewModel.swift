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

//Score,
@Observable
@MainActor
final class GameViewModel {

    private let repository: GameStateRepository
    private let generateInstruction: GenerateInstructionUseCase
    private let connectEntities: ConnectEntityUseCase
    
    var gameState: GameState = .menu
    var gameTimeLeft: Double = 50.0
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
    
    var firstSelectedEntity: Entity?
    private var canvasEntity: Entity?
    
    private var activeEntities: [Entity] = []
    private let maxEntitiesCount: Int = 20
    
    var shapeTemplates: [ShapeKind: Entity] = [:]
    
    //Leaderboard
    public let leaderboardRepository: LeaderboardRepository
    public var leaderboardEntries: [LeaderboardEntry] = []
    
    var isHighScoreCandidate: Bool = false
    var hasSavedHighScore: Bool = false
    
    func loadTemplates() async {
        do {
            let sphereTemplate = try await Entity(named: "Animation/bundar_walk_anim", in: realityKitContentBundle)
            let cubeTemplate = try await Entity(named: "Animation/kotak_walk_anim", in: realityKitContentBundle)
            let pyramidTemplate = try await Entity(named: "Animation/segitiga_walk_anim", in: realityKitContentBundle)
            
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
        connectEntities: ConnectEntityUseCase,
        leaderboardRepository: LeaderboardRepository
    ) {
        self.repository = repository
        self.generateInstruction = generateInstruction
        self.connectEntities = connectEntities
        self.leaderboardRepository = leaderboardRepository
        self.leaderboardEntries = leaderboardRepository.getTopScores()
    }
    
    convenience init() {
        let repository = InMemoryGameStateRepository()
        let generateInstruction = GenerateInstructionUseCase(repository: repository)
        let connectEntities = ConnectEntityUseCase(repository: repository)
        let leaderboardRepo = UserDefaultsLeaderboardRepository()
        self.init(
            repository: repository,
            generateInstruction: generateInstruction,
            connectEntities: connectEntities,
            leaderboardRepository: leaderboardRepo
        )
        refreshInstruction()
    }
    
    func setContent(_ content: RealityViewContent) {
        self.content = content
        for entity in activeEntities {
            content.add(entity)
        }
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
        clearPlayingEntities()
        gameState = .playing
        gameTimeLeft = 50.0
        spawnAccumulator = 0.0
        repository.resetScore()
        score = 0
        
        // Spawn initial 10 entities
        for _ in 0..<10 {
            spawnEntity()
        }
        refreshInstruction()
    }
    
    //Spawn Entity
    func spawnEntity(in content: RealityViewContent) {
        guard activeEntities.count < maxEntitiesCount else {
            print("[Spawning] Maximum character limit reached (\(maxEntitiesCount)). Skipping spawn.")
            return
        }
        
        let kind = ShapeKind.allCases.randomElement()!
        let template = shapeTemplates[kind]
        let color = colorFor(kind)
        
        let entity = EntityFactory.createCharacter(kind: kind, template: template, color: color)
        
        entity.components.set(InputTargetComponent())
        
        activeEntities.append(entity)
        //spawn to ECS
        content.add(entity)
    }
    
    func spawnEntity() {
        guard let content = self.content else { return }
        spawnEntity(in: content)
    }
    
    func tickTimer(delta: Double) {
        guard case .playing = gameState else { return }
        
        // Tick instruction timer
        instructionTimer -= delta
        if instructionTimer <= 0 {
            refreshInstruction()
        }
        
        // Spawn entities over time
        spawnAccumulator += delta
        if spawnAccumulator >= spawnInterval {
            spawnAccumulator = 0.0
            for _ in 0..<5 {
                spawnEntity()
            }
        }
        
        // Tick global game timer
        gameTimeLeft -= delta
        if gameTimeLeft <= 0 {
            gameTimeLeft = 0
            
            // kualifikasi skor masuk top 10
            isHighScoreCandidate = leaderboardRepository.isTopScore(score)
            hasSavedHighScore = false
            
            leaderboardEntries = leaderboardRepository.getTopScores()
            
            let isVictory = score >= 400
            gameState = .gameOver(victory: isVictory)
            clearPlayingEntities()
            
            if let content = self.content,
               let sceneRoot = content.entities.first(where: { $0.name == "SceneRoot" }) {
                let sound: AudioManager.SoundEffect = isVictory ? .victory : .defeat
                AudioManager.shared.play(sound, on: sceneRoot)
            }
        }
        
        score = repository.score
    }
    
    func refreshInstruction() {
        let kinds = activeEntities.compactMap { $0.components[ShapeComponent.self]?.kind }
        let uniqueKinds = Array(Set(kinds))
        
        currentInstruction = generateInstruction.execute(availableKinds: uniqueKinds)
        instructionTimer = currentInstruction?.timeLimit ?? 10
    }

    //make entity Stunned
    func handleShoot(entity: Entity) {
        guard var stateComp = entity.components[EntityStateComponent.self] else { return }
        
        guard stateComp.state == .idle || stateComp.state == .walking || stateComp.state == .stunned else { return }
        
        stateComp.state = .stunned
        stateComp.stunTimer = 7.0
        entity.components[EntityStateComponent.self] = stateComp
        
        entity.setStatusIndicator(color: .red)
        entity.stopAllAnimations(recursive: true)
        AudioManager.shared.play(.stunned, on: entity)
    }
    
    //Make
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
            
            AudioManager.shared.play(.connect, on: entityA)
            
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
    
    private func colorFor(_ kind: ShapeKind) -> UIColor {
        switch kind {
        case .sphere:  return .systemRed
        case .cube:    return .systemBlue
        case .pyramid: return .systemGreen
        }
    }
    
    private func setColor(_ color: UIColor, on entity: Entity) {
        entity.setStatusIndicator(color: color)
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
    
    func saveHighScore(playerName: String) {
        guard isHighScoreCandidate, !hasSavedHighScore else { return }
        let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? "Player" : trimmedName
        
        leaderboardRepository.saveScore(score, playerName: name)
        leaderboardEntries = leaderboardRepository.getTopScores()
        hasSavedHighScore = true
    }
    
    func exitToMenu() {
        clearPlayingEntities()
        gameState = .menu
    }
}
