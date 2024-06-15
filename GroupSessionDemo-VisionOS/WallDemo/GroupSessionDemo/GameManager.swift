//
//  MultiplayerManager.swift
//  Joj
//
//  Created by Hunter Harris on 6/14/24.
//

import Foundation

class GameManager {
    static var shared = GameManager()
    
    var localPlayer: Player?
    
    var playerName: String = UserDefaults.standard.string(forKey: "player-name22") ?? "" {
        didSet {
            UserDefaults.standard.set(playerName, forKey: "player-name22")
        }
    }
}
