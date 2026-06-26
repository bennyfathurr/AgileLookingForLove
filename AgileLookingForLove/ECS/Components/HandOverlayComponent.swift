//
//  HandOverlayComponent.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 26/06/26.
//

import RealityKit
import ARKit

public struct HandOverlayComponent: Component {
    public let chirality: HandAnchor.Chirality
    
    // The top-level wrapper entity loaded from the bundle
    public var gloveWrapper: Entity? = nil
    
    // The actual ModelEntity containing the skinned mesh and jointTransforms
    public var gloveModel: ModelEntity? = nil

    public init(chirality: HandAnchor.Chirality) {
        self.chirality = chirality
    }
}
