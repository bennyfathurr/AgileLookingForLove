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
    
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 20) {
            ToggleImmersiveSpaceButton()
            
            if appModel.immersiveSpaceState == .open {
                Button(action: {
                    appModel.viewModel.createEnvironment()
                }) {
                    Text("Create Env")
                        .font(.headline)
                        .padding()
                        .frame(minWidth: 160)
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .onReceive(timer) { _ in
            if appModel.immersiveSpaceState == .open {
                appModel.viewModel.tickTimer(delta: 0.1)
            }
        }
    }
}
