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
                        Spacer()
                        
                        if viewModel.session != nil {
                            // We are in a session, show leave session button
                            inSharePlayView
                        } else if groupStateObserver.isEligibleForGroupSession {
                            // Not in a session, but is eligible for a session (in Facetime call)
                            sharePlayEligibleView
                        } else {
                            // We are not in a session, and we are not eligible for a session (Not in a Facetime call)
                            sharePlayUnavailableView
                        }
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
            }
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
            
            Spacer()
            
            Button {
                viewModel.resetSession()
                gameModel.reset()
            } label: {
                Text("Leave session").padding()
            }.padding().tint(.red)
            
            HStack {
                Image(systemName: "shareplay")
                Text("(\(gameModel.players.count))")
            }
        }
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
            HStack {
                Image(systemName: "shareplay")
                Text("Start SharePlay")
            }
        }.tint(.green).padding()
    }
    
    var sharePlayUnavailableView: some View {
        HStack {
            Image(systemName: "shareplay.slash")
            Text("Join a FaceTime call to start SharePlay")
        }.padding()
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
            Task {
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
