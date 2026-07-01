//
//  GameState.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 01/07/26.
//

import Foundation

public enum GameState: Equatable, Sendable {
    case menu
    case instructions
    case countdown(Int)
    case playing
    case gameOver(victory: Bool)
}
