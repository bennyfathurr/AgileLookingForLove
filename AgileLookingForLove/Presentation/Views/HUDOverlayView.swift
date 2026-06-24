//
//  HUDOverlayView.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 23/06/26.
//

import SwiftUI

struct HUDOverlayView: View {
    let instruction: GameInstruction?
    let score: Int
    let timeLeft: Double
    let connectionMessage: String
        
        var body: some View {
            VStack(spacing: 16) {
                // Instruksi utama
                if let instruction {
                    Text(instruction.description)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
                
                // Timer bar
                ProgressView(value: max(0, timeLeft), total: instruction?.timeLimit ?? 10)
                    .tint(timeLeft > 5 ? .green : .red)
                    .frame(width: 300)
                
                if !connectionMessage.isEmpty {
                    Text(connectionMessage)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(connectionMessage.hasPrefix("✅") ? .green : .red)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(duration: 0.3), value: connectionMessage)
                }
                
                // Score
                Text("Score: \(score)")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .padding()
        }
}
