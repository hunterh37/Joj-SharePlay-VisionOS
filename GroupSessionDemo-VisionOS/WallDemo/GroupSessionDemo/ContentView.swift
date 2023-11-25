//
//  ContentView.swift
//  GroupSessionDemo
//
//  Created by Hunter Harris on 10/5/23.
//

@preconcurrency import GroupActivities
import Combine
import RealityKit
import SwiftUI
import PhotosUI

struct ContentView: View {
    
    @ObservedObject var viewModel: ViewModel
    @StateObject var groupStateObserver = GroupStateObserver()
    @State private var selectedItem: PhotosPickerItem? = nil
    
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    var body: some View {
        VStack {
            Text("Joj").padding(.bottom, 30)
            
            if viewModel.session != nil {
                // We are in a session, show leave session button
                VStack {
                    Button {
                        viewModel.resetSession()
                        gameModel.reset()
                    } label: {
                        Text("Leave session").padding()
                    }.padding()
                    
                    photosPickerView
                    
                    HStack {
                        Image(systemName: "shareplay")
                        Text("(\(gameModel.players.count))")
                    }
                }

            } else if groupStateObserver.isEligibleForGroupSession {
                // Not in a session, but is eligible for a session (in Facetime call)
                Button {
                    Task {
                        do { // Configure GroupSession & Join ImmersiveSpace
                            try await startSession()
                            await Multiplayer.configureSession(using: viewModel)
                            await openImmersiveSpace(id: "ImmersiveView")
                        } catch {
                            print("SharePlay session failure", error)
                        }
                    }
                } label: {
                    Image(systemName: "shareplay")
                    Text("Start SharePlay")
                }
            } else {
                // We are not in a session, and we are not eligible for a session (Not in a Facetime call)
                HStack {
                    Image(systemName: "shareplay.slash")
                    Text("Join a FaceTime call to start SharePlay")
                }.padding()
            }
        }
    }
    
    var photosPickerView: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .images,
            photoLibrary: .shared())
        {
            Text("Add Photo")
            Image(systemName: "photo.fill")
                .foregroundColor(Color.white)
                .background(Color.accentColor)
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    // User has selected a photo item and we have loaded the data,
                    // need to add it to the GroupSession Journal
                    viewModel.userDidSelectPhoto(data: data)
                }
            }
        }
    }
}

#Preview {
    ContentView(viewModel: .init())
}
