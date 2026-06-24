//
//  GenerateInstructionUseCase.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 23/06/26.
//

import RealityKit

final class GenerateInstructionUseCase {
    private let repository: GameStateRepository
    
    init(repository: GameStateRepository) {
        self.repository = repository
    }
    
    func execute(availableKinds: [ShapeKind]) -> GameInstruction {
        let instruction = GameInstruction.generate(from: availableKinds)
        repository.updateInstructions(instruction)
        return instruction
    }

}
