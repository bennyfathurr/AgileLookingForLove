//
//  ConnectEntityUseCase.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 23/06/26.
//

import RealityKit

final class ConnectEntityUseCase {
    private let repository: GameStateRepository
    
    init(repository: GameStateRepository) {
        self.repository = repository
    }
    
    func execute(fromShape: ShapeKind, toShape: ShapeKind) -> Bool {
        guard let instruction = repository.currentInstructions else { return false }
        let isValid = (fromShape == instruction.formShape && toShape == instruction.toShape)
                           || (fromShape == instruction.toShape && toShape == instruction.formShape)
                if isValid { repository.addScore(100) }
                return isValid
    }
}
