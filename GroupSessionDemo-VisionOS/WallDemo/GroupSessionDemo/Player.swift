//
//  Player.swift
//  GroupSessionDemo
//
//  Created by Hunter Harris on 10/21/23.
//

import SwiftUI

/// Data about a player in a multiplayer session.
class Player {
    let name: String
    var score: Int
    let color: Color
    var isReady = false
    
    init(name: String, score: Int, color: Color) {
        self.name = name
        self.score = score
        self.color = color
    }
    
    /// The local player, "me".
    static var local: Player? = nil
}

// A utility to randomly assign players a theme color for some UI presentations.
extension Color {
    static func random() -> Self {
        [.red, .blue, .green, .pink, .purple].randomElement()!
    }
}
