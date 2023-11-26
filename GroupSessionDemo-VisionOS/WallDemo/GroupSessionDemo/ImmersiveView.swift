//
//  ImmersiveView.swift
//  GroupSessionDemo
//
//  Created by Hunter Harris on 10/6/23.
//

import Foundation
import _RealityKit_SwiftUI
import SwiftUI
import Spatial

// Configure the objects in the ImmersiveSpace using a RealityView
// Display objects received from the viewModel.sessionActionPublisher
//
// The users currentObjectRoot Entity allows for movement with a drag gesture,
// ObjectMessage position messages with the currentObjectRoot position are constantly sent to others

struct ImmersiveView: View {
    @ObservedObject var gameModel: GameModel
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
        RealityView { content in
            content.add(rootEntity) // Add global rootEntity of the scene, all objects added as children 
        } update: { content in
            
            // Send the position of the currentObjectRoot
            if let pose = Pose3D(currentObjectRoot.transformMatrix(relativeTo: rootEntity)) {
                viewModel.sendObjectRootPositionUpdate(pose: pose) //TEST: position
            }
        }
        .gesture(dragGesture)
        .task {
            viewModel.configureCurrentPlayerRoot()
        }
    }
    
    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0.0)
            .targetedToAnyEntity()
            .onChanged { value in
                value.entity.position = value.convert(value.location3D, from: .local, to: .scene)
            }
    }
}
