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
var floorEntity = Entity()
var playerObjectRoots: [String: ModelEntity] = [:] /// A map from object root names to entities in multiplayer.
var subscriptions = Set<AnyCancellable>()
var gameModel: GameModel = .init()
var floorCollisionGroup = CollisionGroup(rawValue: 16)

enum SessionAction {
    case receivedSession(GroupSession<GroupSessionDemoActivity>)
    case openImmersiveSpace(Void)
    case dismissImmersiveSpace(Void)
}

class ViewModel: ObservableObject {
    @Published var attachments = [ImageDataMessage]()
    @Published var immersionStyle: ImmersionStyle = .mixed
    @Published var session: GroupSession<GroupSessionDemoActivity>? = nil
    @Published var selectedAttachmentId: String? = nil
    
    @Published var showPlayerNameAlert = false
    
    var tasks = Set<Task<Void, Never>>()
    
    let actionSubject = PassthroughSubject<SessionAction, Never>()
    var sessionActionPublisher: AnyPublisher<SessionAction, Never> { actionSubject.eraseToAnyPublisher() }
    
    init() {
        // Observe sessionActionPublisher when to join GroupSession
        sessionActionPublisher.sink { [weak self] action in
            switch action {
            case .receivedSession(let groupSession):
                guard let self,
                      self.session == nil else { return }
                
                Task { @MainActor in
                    Multiplayer.joinSession(session: groupSession, viewModel: self)
                    self.session = groupSession
                    self.configureCurrentPlayerRoot_Default()
                }
            case .openImmersiveSpace():
                return
                
            case .dismissImmersiveSpace():
                return
            }
        }.store(in: &subscriptions)
    }
}

// MARK: - Basic Session

extension ViewModel {
    
    /// Add the root object for the current users selected object to be added to
    func configureCurrentPlayerRoot_Default() {
        currentObjectRoot.removeFromParent()
        currentObjectRoot = PlaceableObjects.currentModelSelected().clone(recursive: true)
        currentObjectRoot.components[InputTargetComponent.self] = InputTargetComponent(allowedInputTypes: .all)
        currentObjectRoot.generateCollisionShapes(recursive: true)
        rootEntity.addChild(currentObjectRoot)
    }
    
    /// Called when user selects new PlaceableObject,
    /// Update the selectedObject on SelectedObjectManager,
    /// call configureCurrentPlayerRoot to remove old object, re-add new selectedObject
    func selectedNewObject(object: PlaceableObject) {
        SelectedObjectManager.shared.selectedObject = object
        configureCurrentPlayerRoot_Default()
        print("SelectedObjectManager, selected: \(object.name)")
    }
    
    func resetSession() {
        session?.leave()
        session = nil
        attachments = []
        
        subscriptions = []
        
        for child in rootEntity.children {
            child.removeFromParent()
        }
        
        tasks.forEach { $0.cancel() }
        tasks = []
        
        currentObjectRoot.removeFromParent()
        
        actionSubject.send(.dismissImmersiveSpace(()))
    }
}

// MARK: - Send Position Message

extension ViewModel {
    
    /// Send each player's selected object location & name during FaceTime calls that are spatial.
    func sendObjectRootPositionUpdate(pose: Pose3D) {
        let isSelectingAttachment: Bool = (selectedAttachmentId != nil) ? true : false
        if let sessionInfo = sessionInfo,
           let session = sessionInfo.session,
           let messenger = sessionInfo.messenger
        {
            let everyoneElse = session.activeParticipants.subtracting([session.localParticipant])
            let newMessage = ObjectMessage(pose: pose,
                                           name: SelectedObjectManager.shared.selectedObject?.name ?? "",
                                           isSelectingAttachment: isSelectingAttachment,
                                           selectedAttachmentId: selectedAttachmentId)
            
            if gameModel.isSpatial {
                messenger.send(newMessage, to: .only(everyoneElse)) { error in
                    if let error = error { print("Message failure:", error) }
                }
            }
        }
    }
}

// MARK: - Attachments

extension ViewModel {
    
    //TEST: do we need to configure a local entity for this newly added object, or will it get configured same as remote objects do...

    /// Called when user selects photo item from photo picker or,
    /// when user selects usdz file from file importer
    ///
    func userDidSelectData(data: Data) {
        addAttachment(data: data) // Send ImageMetadataMessage to GroupSession Journal
        configureCurrentPlayerRootForAttachment(data: data) // Configure entity for local player only who added the object
    }
    
    /// GroupSession Journal: Add the new ImageMetadataMessage to the GroupSession Journal
    ///
    /// Called when adding both USDZ or Image attachments
    /// Create new ImageMetadataMessage object with new data and random id selectedAttachmentId,
    ///
    /// (Note: this is just sending the ImageMetadataMessage with selected attachment id...
    ///  we observe the ObjectMessage.isSelectingAttachment to position this attachment later on.)
    ///
    func addAttachment(data: Data) {
        Task() { @MainActor in
            let id = UUID().uuidString
            selectedAttachmentId = id
            let metadata = ImageMetadataMessage(location: .init(x: 0, y: 0), id: id)
            if let journal = sessionInfo?.journal {
                let _ = try await journal.add(data, metadata: metadata)
            }
        }
    }
    
    /// Adds the object root for current player when adding new Image or Usdz attachment
    /// Save the data to app documents,
    /// if Image attachment:  return the configured plane entity Model with image
    /// if Usdz attachment: return the configured Model
    ///
    func configureCurrentPlayerRootForAttachment(data: Data) {
        Task { @MainActor in
            
            let fileType = data.detectType()
            switch fileType {
            case .png, .jpeg:
                guard let savedUrl = Utility.writeDataToDocuments(data: data, fileName: UUID().uuidString),
                      let model = await Utility.convertToCGImage_AndCreatePlaneEntity(fromURL: savedUrl, id: savedUrl.pathExtension)
                else { return }
                
                configureCurrentPlayerRoot_FromAttachment(model: model)
              
            case .usdz:
                guard let savedUrl = Utility.writeDataToDocuments(data: data, fileName: UUID().uuidString),
                      let model = await Utility.loadUsdzFromAttachment(url: savedUrl, id: savedUrl.pathExtension)
                else { return }
                
                configureCurrentPlayerRoot_FromAttachment(model: model)
            case .unknown:
                return
            }
        }
    }
    
    func configureCurrentPlayerRoot_FromAttachment(model: ModelEntity) {
        currentObjectRoot.removeFromParent()
        currentObjectRoot = model
        currentObjectRoot.components[InputTargetComponent.self] = InputTargetComponent(allowedInputTypes: .all)
        currentObjectRoot.generateCollisionShapes(recursive: true)
        
        rootEntity.addChild(currentObjectRoot)
        
        model.components[PhysicsBodyComponent.self] = nil
    }
}

extension ViewModel {
    func spawnFloor() {
        let material = UnlitMaterial(color: .green)
        floorEntity = ModelEntity(mesh: .generateBox(width: 5, height: 0.2, depth: 5), materials: [material], collisionShape: .generateBox(width: 5, height: 0.2, depth: 5), mass: 100000)
        floorEntity.components[PhysicsBodyComponent.self] = .init(massProperties: .init(mass: 100000), material: .default,  mode: .static)
        
        var collision = CollisionComponent(shapes: [ .generateBox(width: 5, height: 0.2, depth: 5)])
        collision.mode = .default
        collision.filter = CollisionFilter(group: floorCollisionGroup, mask: [ .default])
        floorEntity.components[CollisionComponent.self] = collision
        
        floorEntity.position = .init(x: 0, y: -0.1, z: 0)
        rootEntity.addChild(floorEntity)
    }
}
