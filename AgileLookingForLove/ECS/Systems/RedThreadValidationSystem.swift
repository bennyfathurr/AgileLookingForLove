//
//  RedThreadValidationSystem.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 23/06/26.
//

import RealityKit
import ILSSpatialDraw
import Foundation

final class RedThreadValidationSystem: System {
    static let drawQuery  = EntityQuery(where: .has(DrawingComponent.self) && .has(IsDrawingComponent.self))
    static let shapeQuery = EntityQuery(where: .has(ShapeComponent.self) && .has(EntityStateComponent.self))
    private var wasDrawing: Bool = false
    private var cachedStrokePoints: [SIMD3<Float>] = []
    private var cachedStrokeEntity: Entity? = nil
    
    required init(scene: Scene) {}
    func update(context: SceneUpdateContext) {
        // print periodically to verify the system is running
        if Int.random(in: 1...300) == 1 {
            print("[RedThreadValidationSystem] System is updating...")
        }

        // Ambil draw controller entity
        guard let drawer = context.entities(matching: Self.drawQuery, updatingSystemWhen: .rendering)
            .first(where: { _ in true }),
              let isDrawing = drawer.components[IsDrawingComponent.self],
              let drawComp  = drawer.components[DrawingComponent.self]
        else { 
            if Int.random(in: 1...300) == 1 {
                print("[RedThreadValidationSystem] DrawController not found in scene.")
            }
            return 
        }
        let isCurrentlyDrawing = isDrawing.isActive
        
        if isCurrentlyDrawing {
            cachedStrokePoints = drawComp.activeStrokePoints
            cachedStrokeEntity = drawComp.activeStrokeEntity
            if Int.random(in: 1...60) == 1 {
                print("[RedThreadValidationSystem] User is drawing. Cached points count: \(cachedStrokePoints.count)")
            }
        }
        
        // Deteksi momen BERHENTI drawing (stroke just ended)
        if wasDrawing && !isCurrentlyDrawing {
            let strokePoints = cachedStrokePoints
            let strokeEntity = cachedStrokeEntity
            cachedStrokePoints = []
            cachedStrokeEntity = nil
            
            print("[RedThreadValidationSystem] Stroke ended! Points count: \(strokePoints.count)")
            
            guard strokePoints.count >= 2 else {
                print("[RedThreadValidationSystem] Stroke points count < 2. Ignoring.")
                strokeEntity?.removeFromParent()
                wasDrawing = isCurrentlyDrawing
                return
            }
            let startPoint = strokePoints.first!
            let endPoint   = strokePoints.last!
            
            print("[RedThreadValidationSystem] Start point: \(startPoint), End point: \(endPoint)")
            
            // Cari entity stunned yang paling dekat dengan ujung-ujung stroke
            let shapes = context.entities(matching: Self.shapeQuery, updatingSystemWhen: .rendering)
            var startEntity: Entity? = nil
            var endEntity:   Entity? = nil
            var minStartDist: Float = 0.80   // max jarak 80cm dari ujung stroke
            var minEndDist:   Float = 0.80
            
            let shapeArray = Array(shapes)
            print("[RedThreadValidationSystem] Found \(shapeArray.count) shapes in scene.")
            
            for shape in shapeArray {
                guard let stateComp = shape.components[EntityStateComponent.self] else { continue }
                
                guard stateComp.state == .stunned else { continue }
                
                // Use the visual center of the shape (visual bounds center in world space)
                let visualCenter = shape.visualBounds(relativeTo: nil).center
                let dStart = simd_distance(visualCenter, startPoint)
                let dEnd   = simd_distance(visualCenter, endPoint)
                
                print("[RedThreadValidationSystem] Shape: \(shape.name), Position: \(shape.position(relativeTo: nil)), VisualCenter: \(visualCenter), StartDist=\(dStart)m, EndDist=\(dEnd)m")
                
                if dStart < minStartDist {
                    minStartDist = dStart
                    startEntity  = shape
                }
                if dEnd < minEndDist {
                    minEndDist = dEnd
                    endEntity  = shape
                }
            }
            
            if let a = startEntity, let b = endEntity {
                print("[RedThreadValidationSystem] Selected: A=\(a.name) (dist \(minStartDist)), B=\(b.name) (dist \(minEndDist))")
                if a.id != b.id {
                    print("[RedThreadValidationSystem] Posting threadStrokeConnected notification!")
                    NotificationCenter.default.post(
                        name: .threadStrokeConnected,
                        object: nil,
                        userInfo: [
                            "entityA": a,
                            "entityB": b,
                            "strokeEntity": strokeEntity as Any
                        ]
                    )
                } else {
                    print("[RedThreadValidationSystem] Start and End matched the SAME entity.")
                    strokeEntity?.removeFromParent()
                }
            } else {
                print("[RedThreadValidationSystem] No shapes were within proximity threshold.")
                strokeEntity?.removeFromParent()
            }
        }
        wasDrawing = isCurrentlyDrawing
    }
}

extension Notification.Name {
    static let threadStrokeConnected = Notification.Name("threadStrokeConnected")
}
