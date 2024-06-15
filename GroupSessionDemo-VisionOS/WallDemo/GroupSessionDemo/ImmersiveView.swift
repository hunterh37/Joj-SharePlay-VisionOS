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
//
// Object Positioning in SharePlay / Multiplayer works by: (Assuming in SharePlay session)
//      - 1) Each user has currentObjectRoot, an empty Entity used as the root object (Global object)
//      - 2) Create a dictionary for each players [currentObjectRoot: PlayerId] - playerObjectRoots (Global object)
//      - 3) Constantly broadcast position of user's currentObjectRoot by sending ObjectMessage's to the GroupSession
//      - 4) When each user receives ObjectMessage, get sender id and update position of Entity in playerObjectRoots for id
//

struct ImmersiveView: View {
    @ObservedObject var gameModel: GameModel
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
        RealityView { content in
            content.add(rootEntity) // Add global rootEntity of the scene, all objects added as children 
            viewModel.spawnFloor()
        } update: { content in
            
            // TODO:  ? need to get offset from spatial origin ?
            // ? if spatial origin offset returns position relative to current player,
            // we should be able to send offset position
            // ...
            // ? for receivers, do we need to check spatial offset of sending user there too
            // and move object to offset relative to sending user spatial origin ?
            
            // Send the position of the currentObjectRoot
            if let pose = Pose3D(currentObjectRoot.transformMatrix(relativeTo: rootEntity)) {
                viewModel.sendObjectRootPositionUpdate(pose: pose) //TEST: position
            }
        }
        .gesture(dragGesture)
        .simultaneousGesture(rotateGesture)
    }
    
    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0.0)
            .targetedToAnyEntity()
            .onChanged { value in
                value.entity.position = value.convert(value.location3D, from: .local, to: .scene)
            }
    }
    
    var rotateGesture: some Gesture {
        RotateGesture3D()
            .targetedToAnyEntity()
            .onChanged { value in
                guard let parent = value.entity.parent else { return }
                value.entity.orientation = value.convert(value.rotation, from: .local, to: parent)
            }
    }
}
