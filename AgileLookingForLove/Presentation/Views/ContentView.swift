//
//  ContentView.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 22/06/26.
//

import SwiftUI
import RealityKit
import RealityKitContent
import Combine

struct ContentView: View {
    @Environment(AppModel.self) var appModel
    
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            switch appModel.viewModel.gameState {
            case .menu:
                MainMenuView(appModel: appModel) {
                    appModel.viewModel.gameState = .instructions
                }
                
            case .instructions:
                InstructionsView(appModel: appModel) {
                    Task { @MainActor in
                        if appModel.immersiveSpaceState == .closed {
                            appModel.immersiveSpaceState = .inTransition
                            let result = await openImmersiveSpace(id: appModel.immersiveSpaceID)
                            if result == .opened {
                                appModel.viewModel.gameState = .playing
                            } else {
                                appModel.immersiveSpaceState = .closed
                            }
                        } else {
                            appModel.viewModel.gameState = .playing
                        }
                    }
                }
                
            case .countdown, .playing, .gameOver:
                InGameDashboardView(appModel: appModel) {
                    Task { @MainActor in
                        if appModel.immersiveSpaceState == .open {
                            appModel.immersiveSpaceState = .inTransition
                            await dismissImmersiveSpace()
                        }
                        appModel.viewModel.exitToMenu()
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 460, height: 500)
        .onReceive(timer) { _ in
            if appModel.immersiveSpaceState == .open {
                appModel.viewModel.tickTimer(delta: 0.1)
            }
        }
    }
}

// Main Menu View
struct MainMenuView: View {
    let appModel: AppModel
    let startAction: () -> Void
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 80))
                .foregroundColor(.pink)
                .shadow(radius: 4)
            
            VStack(spacing: 8) {
                Text("Agile: Looking For Love")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Connect lonely shapes with the Red Thread of Fate.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            
            Spacer()
            
            Button(action: startAction) {
                Text("Start Game")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }
}

// Instructions View
struct InstructionsView: View {
    let appModel: AppModel
    let readyAction: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Text("How to Play")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.top, 12)
            
            VStack(alignment: .leading, spacing: 16) {
                InstructionRow(icon: "eye.fill", text: "Look at a minion and perform a Pinch gesture (thumb + middle finger) to stun them.")
                
                InstructionRow(icon: "paintbrush.fill", text: "Draw a Red Thread between two stunned minions to connect them.")
                
                InstructionRow(icon: "list.bullet.clipboard.fill", text: "Follow the Target Recipe shown in the Objective panel (e.g. Square + Circle).")
                
                InstructionRow(icon: "clock.fill", text: "Reach a score of 100 before the game timer runs out!")
            }
            .padding(.horizontal, 16)
            
            Spacer()
            
            Button(action: readyAction) {
                Text("Ready")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal, 32)
            .disabled(appModel.immersiveSpaceState == .inTransition)
            .padding(.bottom, 24)
        }
    }
}

struct InstructionRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.pink)
                .frame(width: 28, alignment: .center)
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// In-Game Dashboard View
struct InGameDashboardView: View {
    let appModel: AppModel
    let exitAction: () -> Void
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            
            if appModel.viewModel.environmentEntity == nil {
                VStack(spacing: 16) {
                    Text("Place the Environment")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Drag the Green Placement Indicator in spatial space to position the platform, then tap below to lock the area.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        appModel.viewModel.createEnvironment()
                    }) {
                        Text("Create Env")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                .padding(.horizontal, 24)
            } else {
                VStack(spacing: 12) {
                    Text(appModel.viewModel.gameTimeLeft > 0 ? "Game in Progress..." : "Game Ended")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if appModel.viewModel.gameTimeLeft > 0 {
                        Text("Look around in the Immersive Space to play.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            
            Spacer()
            
            Button(action: exitAction) {
                Text("Exit Game")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
            .padding(.horizontal, 32)
            .disabled(appModel.immersiveSpaceState == .inTransition)
            .padding(.bottom, 24)
        }
    }
}
