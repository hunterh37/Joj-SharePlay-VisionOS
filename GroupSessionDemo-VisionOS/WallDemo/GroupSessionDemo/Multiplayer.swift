//
//  Multiplayer.swift
//  GroupSessionDemo
//
//  Created by Hunter Harris on 10/21/23.
//

import Combine
import Foundation
import RealityKit
import Spatial
import SwiftUI
@preconcurrency import GroupActivities

/// Starts the GroupSession activity for the app
func startSession() async throws {
    let activity = GroupSessionDemoActivity()
    let activationSuccess = try await activity.activate()
    print("Group Activities session activation: ", activationSuccess)
}

/// Metadata about the GroupActivity
struct GroupSessionDemoActivity: GroupActivity {
    var metadata: GroupActivityMetadata {
        var data = GroupActivityMetadata()
        data.title = "Group Session Demo"
        data.subtitle = "Shared scenes with entity placement."
        data.supportsContinuationOnTV = false
        return data
    }
    static var activityIdentifier = "org.hunt3r.groupsessiondemo"
}

// MARK: - Multiplayer Messages

/// A message that contains current information about the position of another player's object
struct ObjectMessage: Codable {
    let pose: Pose3D
    let name: String
    let isSelectingAttachment: Bool
    let selectedAttachmentId: String?
}

struct ImageMetadataMessage: Codable {
    let location: CGPoint
    let id: String
}

struct ImageDataMessage: Identifiable {
    var id: UUID
    let location: CGPoint
    let imageData: Data
    let fileType: Data.FileType
}

/// A container for group activity session information.
class DemoSessionInfo: ObservableObject {
    @Published var session: GroupSession<GroupSessionDemoActivity>?
    var messenger: GroupSessionMessenger?
    var reliableMessenger: GroupSessionMessenger?
    var journal: GroupSessionJournal?
}

// MARK: - Multiplayer - Basic Session

struct Multiplayer {
    
    /// Create the main GroupSession, configure all logic needed when a user first joins a session
    /// Add objectRoots for each player in the session
    static func configureSession(using viewModel: ViewModel) async {
        
        var session: GroupSession<GroupSessionDemoActivity>
        sessionInfo = .init()
        for await newSession in GroupSessionDemoActivity.sessions() {
            print("New GroupActivities session", newSession)
            
            session = newSession
            sessionInfo?.session = newSession
            let journal = GroupSessionJournal(session: newSession)
            sessionInfo?.journal = journal
            gameModel.isSharePlaying = true
            
            // Spatial coordination.
            if let coordinator = await newSession.systemCoordinator {
                var config = SystemCoordinator.Configuration()
                config.spatialTemplatePreference = .sideBySide
                config.supportsGroupImmersiveSpace = true
                coordinator.configuration = config
                
                Task.detached { @MainActor in
                    for await state in coordinator.localParticipantStates {
                        if state.isSpatial {
                            gameModel.isSpatial = true
                        } else {
                            gameModel.isSpatial = false
                        }
                    }
                }
            }
            
            do {
                print("Waiting before starting group activity.")
                try await Task.sleep(for: .seconds(3))
            } catch {
                print("Couldn't sleep.", error)
            }
            
            gameModel.players = newSession.activeParticipants.map { participant in
                Player(name: String(participant.id.asPlayerName), score: 0, color: .random())
            }
            
            Player.local = gameModel.players.first(where: { $0.name == newSession.localParticipant.id.asPlayerName })
            
            // *Session Handling: Add initial objectRoot for existing players who aren't the `local` player.
            gameModel.players.filter { $0.name != Player.local!.name }.forEach { player in
                Task {
                    let newEntity = await initialObject(for: player)
                    playerObjectRoots[player.name] = newEntity
                    await rootEntity.addChild(newEntity)
                }
            }
            
            
            // *Session Handling: Add objectRoot when new player joins
            Task {
                for try await updatedPlayerList in newSession.$activeParticipants.values {
                    
                    for participant in updatedPlayerList
                    {
                        Player.local = gameModel.players.first(where: { $0.name == newSession.localParticipant.id.asPlayerName })
                        let potentialNewPlayer = Player(name: String(participant.id.asPlayerName), score: 0, color: .random())
                        
                        if !gameModel.players.contains(where: { $0.name == potentialNewPlayer.name })
                        {
                            gameModel.players.append(potentialNewPlayer)
                            
                            Task {
                                let newEntity = await initialObject(for: potentialNewPlayer)
                                playerObjectRoots[potentialNewPlayer.name] = newEntity
                                await rootEntity.addChild(newEntity)
                            }
                        }
                    }
                }
            }
            
            // *Session Handling: Handle receiving attachments / files from the GroupSession Journal
            let task = Task {
                for await images in journal.attachments {
                    await handleReceiveJournal(images, viewModel: viewModel)
                }
            }
            viewModel.tasks.insert(task)
            
            // *Session Handling: Publish new session to the ViewModel
            viewModel.actionSubject.send(.receivedSession(session))
        }
    }
    
    /// Join the GroupSession, subscribe to session messages to update scene with realtime data
    /// Called after session has already been started and configured
    static func joinSession(session: GroupSession<GroupSessionDemoActivity>, viewModel: ViewModel) {
        sessionInfo?.messenger = GroupSessionMessenger(session: session, deliveryMode: .unreliable)
        sessionInfo?.reliableMessenger = GroupSessionMessenger(session: session, deliveryMode: .reliable)
        
        session.join()
        
        session.$state.sink { state in
            if case .invalidated = state {
                gameModel.reset()
                viewModel.resetSession()
                sessionInfo = nil
            }
        }.store(in: &subscriptions)
        
        subscribeToSessionUpdates(viewModel: viewModel)
    }
}

// MARK: - Multiplayer - Message Handling

extension Multiplayer {
    
    /// Handle all incoming sessionInfo messages,  update scene with realtime data
    ///
    static func subscribeToSessionUpdates(viewModel: ViewModel) {
        // Receive ObjectMessage messages
        let task = Task { @MainActor in
            if let messenger = sessionInfo?.messenger {
                for await (message, sender) in messenger.messages(of: ObjectMessage.self) {
                    await handleObjectMessage(message: message, sender: sender, viewModel: viewModel)
                }
            }
        }
        viewModel.tasks.insert(task)
    
    }
    
    /// Handle receiving of the ObjectMessage sent through GroupSession.
    /// When receiving the message, we first check the type to see if the user has selected an attachment (USDZ or Photo)
    ///     - If it is an attachment, only load the new model if different
    ///
    /// Called when receiving ObjectMessage
    ///     - check playerObjectRoots dict, using key: sender playerId to get playerObjectRoot Entity
    ///     - update object position with message position
    @MainActor
    static func handleObjectMessage(message: ObjectMessage,
                                    sender: GroupSessionMessenger.MessageContext,
                                    viewModel: ViewModel) async
    {
        guard let _ = playerObjectRoots[sender.source.id.asPlayerName] else {
            print("Received ObjectMessage message for an object that doesn't exist:", sender.source.id.asPlayerName)
            return
        }
        // TODO: modify object material color to be players color
        // TODO: can/should we set position with animation
        
        // Check if the user sending this message is selecting attachment (image, usdz..)
        // if so, we need to grab that downloaded data from the GroupSession Journal
        if message.isSelectingAttachment
        {
            if playerObjectRoots[sender.source.id.asPlayerName]?.name != message.selectedAttachmentId
            {   // Only load new Entity once
                playerObjectRoots[sender.source.id.asPlayerName]?.removeFromParent()
                
                if let newEntity = await configuredEntity(for: message, viewModel: viewModel) {
                    rootEntity.addChild(newEntity)
                    playerObjectRoots[sender.source.id.asPlayerName] = newEntity
                }
            }
        } else {
            guard let newEntity = PlaceableObjects.modelForName(name: message.name),
                  playerObjectRoots[sender.source.id.asPlayerName]?.name != newEntity.name // Only load new Entity once
            else { return }
            
            playerObjectRoots[sender.source.id.asPlayerName]?.removeFromParent()
            playerObjectRoots[sender.source.id.asPlayerName] = newEntity
            rootEntity.addChild(newEntity)
        }
        
        // Regardless of message type, set the position of the object to the position sent from message
        playerObjectRoots[sender.source.id.asPlayerName]?.transform = Transform(matrix: simd_float4x4(message.pose))
        
        // TODO: research spatial origin positioning
    }
}

// MARK: - Multiplayer - Entity Configuration

extension Multiplayer {
    
    /// Get the matching attachment data from Group Session Journal (viewModel.images) ...
    /// Write to app documents so we can load it into a ModelEntity
    /// Returns: configured ModelEntity with image plane
    ///
    @MainActor
    static func configuredEntity(for message: ObjectMessage, viewModel: ViewModel) async -> ModelEntity? {
        guard let attachment = viewModel.attachments.first(where: { $0.id.uuidString == message.selectedAttachmentId }),
              let savedUrl = Utility.writeDataToDocuments(data: attachment.imageData, fileName: UUID().uuidString),
              let id = message.selectedAttachmentId 
        else { return nil }
        
        switch attachment.fileType {
        case .png, .jpeg:
            return await Utility.convertToCGImage_AndCreatePlaneEntity(fromURL: savedUrl, id: id)
        case .usdz:
            return await Utility.loadUsdzFromAttachment(url: savedUrl, id: id)
        case .unknown:
            return nil
        }
    }
    
    /// Creates an Object for each player in multiplayer as they join the game and play spatially.
    @MainActor
    static func initialObject(for player: Player) async -> ModelEntity {
        let newObject = PlaceableObjects.cube.modelEntity
        let handOrigin = ModelEntity()
        let objectIntermediate = Entity()
        
        handOrigin.addChild(objectIntermediate)
        objectIntermediate.addChild(newObject)
        
        rootEntity.addChild(handOrigin)
        
        newObject.generateCollisionShapes(recursive: true)
        newObject.name = "root-\(player.name)"
        
        return handOrigin
    }
}

// MARK: - Multiplayer - Group Session Journal

extension Multiplayer {
    
    // TEST: is this called when adding our own files?
    
    /// Handle receiving files from other users in the GroupSession
    static func handleReceiveJournal(_ attachments: GroupSessionJournal.Attachments.Element, viewModel: ViewModel) async
    {
        // Publish list of ImageDataMessage messages received with UUID
        // (when we receive ObjectMessage messages, check if that user is showing attachment..)
        viewModel.attachments = await withTaskGroup(of: ImageDataMessage?.self) { group in
            var images = [ImageDataMessage]()

            attachments.forEach { attachment in
                group.addTask {
                    do {
                        let metadata = try await attachment.loadMetadata(of: ImageMetadataMessage.self)
                        let imageData = try await attachment.load(Data.self)
                        let fileType = imageData.detectType()
                        
                        return .init(id: attachment.id, location: metadata.location, imageData: imageData, fileType: fileType)
                    } catch { return nil }
                }
            }

            for await image in group {
                if let image {
                    images.append(image)
                }
            }

            return images
        }
    }
}
