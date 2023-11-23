//
//  GameModel.swift
//  GroupSessionDemo
//
//  Created by Hunter Harris on 10/21/23.
//

import Foundation
import SwiftUI

class GameModel: ObservableObject {
    @Published var players: [Player] = []
    @Published var isPlaying = false
    @Published var isSharePlaying = false
    @Published var isSpatial = false
    
    /// Preload assets when the app launches to avoid pop-in during the game.
    init() {
        Task { @MainActor in
            
        }
    }
    
    /// Removes 3D content when then game is over.
    func clear() {
        rootEntity.children.removeAll()
    }
    
    /// Resets game state information.
    func reset() {
        isPlaying = false
        isSharePlaying = false
        players = []
        
        clear()
    }
}
