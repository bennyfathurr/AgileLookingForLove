//
//  InMemoryGameStateRepository.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 23/06/26.
//

import RealityKit
import SwiftUI

@Observable
final class InMemoryGameStateRepository: GameStateRepository {
    private (set) var score: Int = 0
    private (set) var currentInstructions: GameInstruction?
    
    func addScore(_ points: Int) {
        score += points
    }
    func updateInstructions(_ instruction: GameInstruction) {
        currentInstructions = instruction
    }
}
