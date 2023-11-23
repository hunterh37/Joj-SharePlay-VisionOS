//
//  GroupSessionDemoApp.swift
//  GroupSessionDemo
//
//  Created by Hunter Harris on 10/5/23.
//

import SwiftUI

@main
struct JojApp: App {
    
    @State private var viewModel = ViewModel()
    @State private var gameModel = GameModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }.defaultSize(width: 400, height: 200)
        
        ImmersiveSpace(id: "ImmersiveView") {
            ImmersiveView(gameModel: gameModel, viewModel: viewModel)
        }.immersionStyle(selection: $viewModel.immersionStyle, in: .full, .mixed)
    }
}
