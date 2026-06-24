//
//  GameInstruction.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 22/06/26.
//

struct GameInstruction: Sendable {
    let formShape: ShapeKind
    let toShape: ShapeKind
    let timeLimit: Double
    
    var description: String {
        "Sambung to \(formShape.displaySymbol) -> \(toShape.displaySymbol)"
    }
    
    static func generate(from availableKinds: [ShapeKind]) -> GameInstruction {
        let kinds = availableKinds.count >= 2 ? availableKinds : ShapeKind.allCases
        
        let form = kinds.randomElement()!
        var to = kinds.randomElement()!
        while to == form && kinds.count > 1 {
            to = kinds.randomElement()!
        }
        return GameInstruction(formShape: form, toShape: to, timeLimit: Double.random(in: 12...25))
    }
        
    static func random() -> GameInstruction {
        return generate(from: ShapeKind.allCases)
    }
}
