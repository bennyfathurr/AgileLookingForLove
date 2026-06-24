//
//  ShapeKind.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 22/06/26.
//

import RealityKit

enum ShapeKind: String, CaseIterable, Sendable {
    case sphere, cube, pyramid
    
    var meshResource: MeshResource {
        switch self {
        case .sphere:  return .generateSphere(radius: 0.1)
        case .cube:    return .generateBox(size: 0.15)
        case .pyramid: return .generateCone(height: 0.2, radius: 0.1)
        }
    }
    
    var displaySymbol: String {
        switch self {
        case .sphere:  return "Bulet"
        case .cube:    return "Kotak"
        case .pyramid: return "Segitiga"
        }
    }
}
