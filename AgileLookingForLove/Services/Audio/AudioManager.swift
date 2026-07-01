//
//  AudioManager.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 29/06/26.
//

import RealityKit
import RealityKitContent
import Foundation

@MainActor
public final class AudioManager {
    public static let shared = AudioManager()
    
    private var preloadedResources: [String: AudioFileResource] = [:]
    
    //Add New Sound here
    public enum SoundEffect: String, CaseIterable {
        case connect = "cihuy.mp3"
        case minion = "minion.mp3"
        case laserBeam = "Glimmer.wav"
        case stunned = "jokowi.mp3"
        case victory = "victory.mp3"
        case defeat = "defeat.mp3"
    }
    
    private init() {}
    
    public func preloadAllSounds() async {
        for sound in SoundEffect.allCases {
            do {
                let resource = try await AudioFileResource.load(
                    named: sound.rawValue,
                    in: realityKitContentBundle
                )
                preloadedResources[sound.rawValue] = resource
                print("[AudioManager] Preloaded sound from bundle: \(sound.rawValue)")
            } catch {
                print("[AudioManager] Failed to preload sound \(sound.rawValue): \(error)")
            }
        }
    }
    
    public func play(_ sound: SoundEffect, on entity: Entity) {
        guard let resource = preloadedResources[sound.rawValue] else {
            print("[AudioManager] Sound not preloaded: \(sound.rawValue)")
            return
        }
        
        print("[AudioManager] Playing sound: \(sound.rawValue) on entity: \(entity.name)")
        
        if entity.components[SpatialAudioComponent.self] == nil {
            entity.components.set(SpatialAudioComponent())
        }
        
        let audioController = entity.prepareAudio(resource)
        audioController.play()
    }
}
