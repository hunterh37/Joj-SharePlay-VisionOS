//
//  ContentView.swift
//  GroupSessionDemo
//
//  Created by Hunter Harris on 10/5/23.
//

import GroupActivities
import Combine
import RealityKit
import SwiftUI
import PhotosUI

struct ContentView: View {
    
    @ObservedObject var viewModel: ViewModel
    @StateObject var groupStateObserver = GroupStateObserver()
    @StateObject var gameModel2 = gameModel
    
    @State var isActivitySharingSheetPresented = false
    @State var playerName = ""
    @State private var selectedItem: PhotosPickerItem? = nil // Photo import
    @State private var isImporting = false // Usdz import
    
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            GeometryReader { geometry in
                ZStack { // Display the Gradient bg colors
                    HStack {
                        Image("Gradient").resizable()
                            .scaledToFill()
                            .edgesIgnoringSafeArea(.all) .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                    }
                }.zIndex(-1)
                
                VStack {
                    Spacer()
                    Text("Joj").padding(20)
                    HStack {
                        if viewModel.session != nil && groupStateObserver.isEligibleForGroupSession {
                            // We are in a session, show leave session button
                            inSharePlayView
                        } else if groupStateObserver.isEligibleForGroupSession {
                            // Not in a session, but is eligible for a session (in Facetime call)
                            sharePlayEligibleView
                        } else {
                            // We are not in a session, and we are not eligible for a session (Not in a Facetime call)
                            sharePlayUnavailableView
                        }
                    }.padding()
                    
                    Spacer()
                }
            }
        }
        
        // Open the ImmersiveSpace when we receive .openImmersiveSpace from sessionActionPublisher
        .onReceive(viewModel.sessionActionPublisher, perform: { action in
            switch action {
            case .openImmersiveSpace():
                Task { @MainActor in
                    await openImmersiveSpace(id: "ImmersiveView")
                }
                
            case .dismissImmersiveSpace():
                Task { @MainActor in
                    await dismissImmersiveSpace()
                }
            default: return
            }
        })
        
        // When view appears, await the first new session received from GroupSession,
        // this does not create new session, this leaves us open waiting to either join
        // other session we are invited to, or we can create our own new session
        .task { @MainActor in
            await Multiplayer.configureSession(using: viewModel)
        }
        .sheet(isPresented: $isActivitySharingSheetPresented) {
            ActivitySharingViewController(activity: GroupSessionDemoActivity())
        }
        .alert("What's your name?", isPresented: $viewModel.showPlayerNameAlert)
        {
            TextField("Name", text: $playerName).textContentType(.givenName)
            
            Button("Play") {
                GameManager.shared.playerName = playerName
            }
        } message: {
            Text("This name is shown to the other participants in your SharePlay session.")
        }
    }
    
    var inSharePlayView: some View {
        VStack {
            
            photosPickerView.padding()
            
            Button { // Import usdz files button
                isImporting = true
            } label: {
                Label("Import file",
                      systemImage: "square.and.arrow.down")
            }
            
            // Object selection List
            VStack {
                ScrollView(.horizontal,showsIndicators: false) {
                    HStack(alignment: .center, spacing: 5) {
                        ForEach(PlaceableObjects.shared.allObjects) { object in
                            VStack {
                                Image(systemName: object.imageName).font(.extraLargeTitle2)
                            }
                            .onTapGesture {
                                viewModel.selectedNewObject(object: object)
                            }
                        }
                    }
                }
            }.padding(.leading, 100)
            
            Spacer()
            
            Button {
                viewModel.resetSession()
                gameModel.reset()
            } label: {
                Text("Leave session").padding()
            }.padding().tint(.red)
            
            HStack {
                Image(systemName: "shareplay")
                Text("(\($gameModel2.players.wrappedValue.count))")
            }
        }
        // Handle USDZ import
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.usdz]) { result in
            switch result {
            case .success(let url):
                let readResult = read(from: url)
                switch readResult {
                case .success(let data):
                    viewModel.userDidSelectData(data: data)
                case .failure( _):
                   return
                }
            case .failure( _):
                // File import failure
               return
            }
        }
    }
    
    var sharePlayEligibleView: some View {
        HStack {
            Spacer()
            startShareplayButton
            Spacer()
        }
    }
    
    var startShareplayButton: some View {
        Button {
            Task { @MainActor in
                do {
                    // Start New GroupSession
                    try await startSession()
                } catch {
                    print("SharePlay session failure", error)
                }
            }
        } label: {
            HStack {
                Image(systemName: "shareplay")
                Text("Start SharePlay")
            }
        }.tint(.green).padding()
    }
    
    var sharePlayUnavailableView: some View {
        VStack {
            HStack {
                Spacer()
                HStack {
                    Image(systemName: "shareplay.slash")
                    Text("Join a FaceTime call to start SharePlay")
                }.padding()
                Spacer()
            }
            
            VStack {
                Button {
                    isActivitySharingSheetPresented = true
                } label: {
                    HStack {
                        Image(systemName: "shareplay")
                        Text("Invite to SharePlay")
                    }
                }.tint(.green).padding()
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
                .background(Color.red)
        }
        .onChange(of: selectedItem) { _, newItem in
            Task { @MainActor in
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    // User has selected a photo item and we have loaded the data,
                    // need to add it to the GroupSession Journal
                    viewModel.userDidSelectData(data: data)
                }
            }
        }
    }
}

extension ContentView {
    private func read(from url: URL) -> Result<Data, Error> {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        return Result { try Data(contentsOf: url) }
    }
}

#Preview {
    ContentView(viewModel: .init())
}

import UniformTypeIdentifiers

struct USDZDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.usdz] } // USDZ file type
    
    var fileData: Data // Data to store the contents of the USDZ file
    
    // Initialize from USDZ file data
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        fileData = data
    }
    
    // Write USDZ file data
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: fileData)
    }
}




import GroupActivities
import SwiftUI
import UIKit

struct ActivitySharingViewController: UIViewControllerRepresentable {

    let activity: GroupActivity

    func makeUIViewController(context: Context) -> GroupActivitySharingController {
        return try! GroupActivitySharingController(activity)
    }

    func updateUIViewController(_ uiViewController: GroupActivitySharingController, context: Context) { }
}
