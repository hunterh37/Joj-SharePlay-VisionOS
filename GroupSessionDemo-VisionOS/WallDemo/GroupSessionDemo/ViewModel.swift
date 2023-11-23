//
//  ViewModel.swift
//  GroupSessionDemo
//
//  Created by Hunter Harris on 10/6/23.
//

import ARKit
import Combine
import GroupActivities
import RealityKit
import SwiftUI

/// State information about the current group activity.
var sessionInfo: DemoSessionInfo? = nil

// Global Objects
var currentObjectRoot = ModelEntity()
let rootEntity = Entity()
var playerObjectRoots: [String: ModelEntity] = [:] /// A map from object root names to entities in multiplayer.
var subscriptions = Set<AnyCancellable>()
var gameModel: GameModel = .init()

enum SessionAction {
    case receivedSession(GroupSession<GroupSessionDemoActivity>)
}

class ViewModel: ObservableObject {
    @Published var images = [ImageDataMessage]()
    @Published var immersionStyle: ImmersionStyle = .mixed
    @Published var session: GroupSession<GroupSessionDemoActivity>? = nil
    @Published var selectedAttachmentId: String? = nil
    
    let actionSubject = PassthroughSubject<SessionAction, Never>()
    var sessionActionPublisher: AnyPublisher<SessionAction, Never> { actionSubject.eraseToAnyPublisher() }
    
    init() {
        // Observe sessionActionPublisher when to join GroupSession
        sessionActionPublisher.sink { [weak self] action in
            switch action {
            case .receivedSession(let groupSession):
                guard let self else { return }
                Multiplayer.joinSession(session: groupSession, viewModel: self)
                self.session = groupSession
            }
        }.store(in: &subscriptions)
    }
}

// MARK: - Basic Session

extension ViewModel {
    
    /// Add the root object for the current users selected object to be added to
    func configureCurrentPlayerRoot() {
        currentObjectRoot.removeFromParent()
        currentObjectRoot = PlaceableObjects.currentModelSelected().clone(recursive: true)
        currentObjectRoot.components[InputTargetComponent.self] = InputTargetComponent(allowedInputTypes: .all)
        currentObjectRoot.generateCollisionShapes(recursive: true)
        rootEntity.addChild(currentObjectRoot)
    }
    
    func resetSession() {
        session?.leave()
        session = nil
        images = []
        
        for child in rootEntity.children {
            child.removeFromParent()
        }
    }
}

// MARK: - Attachments

extension ViewModel {
    
    func userDidSelectPhoto(data: Data) {
        //TODO: here we can save file to documents then get file type then add img or usdz

        // Send ImageMetadataMessage to GroupSession Journal
        addImageAttachment(data: data)
        
        //TEST: do we need to configure a local entity for this newly added object, or will it get configured same as remote objects do...
        
        // Configure entity for local player only who added the object
        configureCurrentPlayerRootWithData(data: data)
    }
    
    /// GroupSession Journal: Add the new ImageMetadataMessage to the GroupSession Journal\
    func addImageAttachment(data: Data) {
        Task(priority: .userInitiated) {            
            let id = UUID().uuidString
            selectedAttachmentId = id
            let metadata = ImageMetadataMessage(location: .init(x: 0, y: 0), id: id)
            if let journal = sessionInfo?.journal {
                let _ = try await journal.add(data, metadata: metadata)
            }
        }
    }
    
    /// Adds the object root for current player when adding new attachment
    /// Saves data to app documents, then creates plane entity modle with image
    ///
    func configureCurrentPlayerRootWithData(data: Data) {
        Task { @MainActor in
            guard let savedUrl = Utility.writeDataToDocuments(data: data, fileName: UUID().uuidString),
                  let model = await Utility.convertToCGImage_AndCreatePlaneEntity(fromURL: savedUrl, id: savedUrl.pathExtension)
            else { return }
            
            currentObjectRoot.removeFromParent()
            currentObjectRoot = model
            currentObjectRoot.components[InputTargetComponent.self] = InputTargetComponent(allowedInputTypes: .all)
            currentObjectRoot.generateCollisionShapes(recursive: true)
        }
    }
}
