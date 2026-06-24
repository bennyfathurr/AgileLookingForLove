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
        print("[ConnectEntityUseCase] execute called with fromShape: \(fromShape), toShape: \(toShape)")
        guard let instruction = repository.currentInstructions else {
            print("[ConnectEntityUseCase] repository.currentInstructions is NIL!")
            return false
        }
        print("[ConnectEntityUseCase] Comparing with instruction: from=\(instruction.formShape), to=\(instruction.toShape)")
        let isValid = (fromShape == instruction.formShape && toShape == instruction.toShape)
                           || (fromShape == instruction.toShape && toShape == instruction.formShape)
        print("[ConnectEntityUseCase] Comparison result: \(isValid)")
        if isValid {
            repository.addScore(100)
            print("[ConnectEntityUseCase] Score added! New score: \(repository.score)")
        }
        return isValid
    }
}
