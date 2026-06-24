//
//  OriginalMaterialsComponent.swift
//  AgileLookingForLove
//

import RealityKit
import UIKit

struct OriginalMaterialsComponent: Component {
    let materials: [Material]
}

extension Entity {
    func setStatusIndicator(color: UIColor?) {
        // Remove existing indicator if present
        if let existing = self.findEntity(named: "StatusIndicator") {
            existing.removeFromParent()
        }
        
        guard let color = color else { return }
        
        // Create a flat disc/cylinder under the character's feet
        let ringMesh = MeshResource.generateCylinder(height: 0.002, radius: 0.22)
        var material = UnlitMaterial()
        material.color = .init(tint: color.withAlphaComponent(0.6))
        
        let indicator = ModelEntity(mesh: ringMesh, materials: [material])
        indicator.name = "StatusIndicator"
        indicator.position = SIMD3<Float>(0, 0.002, 0) // slightly offset to prevent Z-fighting with floors
        
        self.addChild(indicator)
    }
}
