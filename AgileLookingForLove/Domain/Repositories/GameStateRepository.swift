//
//  GameStateRepository.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 22/06/26.
//

protocol GameStateRepository: AnyObject {
    var score: Int { get }
    var currentInstructions: GameInstruction? { get }
    func addScore(_ points: Int)
    func updateInstructions(_ instruction: GameInstruction)
}
