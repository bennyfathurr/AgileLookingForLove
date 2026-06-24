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
    
    static func random() -> GameInstruction {
        let shapes = ShapeKind.allCases
        let form = shapes.randomElement()!
        var to = shapes.randomElement()!
        while to == form { to = shapes.randomElement()!}
        return GameInstruction(formShape: form, toShape: to, timeLimit: Double.random(in: 12...25))
    }
}
