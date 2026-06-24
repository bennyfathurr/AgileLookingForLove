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
    
    func execute() -> GameInstruction {
        let instruction = GameInstruction.random()
        repository.updateInstructions(instruction)
        return instruction
    }
}
