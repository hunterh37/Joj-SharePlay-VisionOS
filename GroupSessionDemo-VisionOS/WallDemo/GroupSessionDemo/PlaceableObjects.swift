//
//  PlaceableObjects.swift
//  GroupSessionDemo
//
//  Created by Hunter Harris on 10/22/23.
//

import RealityKit
import Foundation

struct PlaceableObject: Identifiable {
    var id: UUID = UUID()
    var name: String
    var modelEntity: ModelEntity
    var imageName: String
    var isUsdz: Bool
}

class PlaceableObjects {
    
    static let shared: PlaceableObjects = .init()
    
    init() {
        
       
        
        // Test crash fix: 1/28/23
        Task { @MainActor in
            cube = PlaceableObject(name: "cube", modelEntity: ModelEntity(mesh: .generateBox(size: 1), materials: [UnlitMaterial(color: .blue)], collisionShape: .generateBox(size: .one), mass: 100), imageName: "cube.fill", isUsdz: false)
            cube.modelEntity.components[PhysicsBodyComponent.self] = nil
            
            sphere = PlaceableObject(name: "sphere", modelEntity: ModelEntity(mesh: .generateSphere(radius: 0.5), materials: [UnlitMaterial(color: .blue)], collisionShape: .generateSphere(radius: 0.5), mass: 100), imageName: "circle.fill", isUsdz: false)
            sphere.modelEntity.components[PhysicsBodyComponent.self] = nil
            
            allObjects = [cube, sphere, PlaceableObjects.toy]
            
            loadAllUsdzObjects()
        }
    }
    
    var allObjects: [PlaceableObject] = []
    var cube = PlaceableObject(name: "cube", modelEntity: ModelEntity(), imageName: "cube.fill", isUsdz: false)
    var sphere = PlaceableObject(name: "sphere", modelEntity: ModelEntity(), imageName: "circle.fill", isUsdz: false)
    
    static var toy = PlaceableObject(name: "toy", modelEntity: ModelEntity(mesh: .generateSphere(radius: 0.5), materials: [UnlitMaterial(color: .blue)], collisionShape: .generateSphere(radius: 0.5), mass: 100), imageName: "circle.fill", isUsdz: true)
    
    /// The list of allObjects contains RealityKit generic ModelEntity such as cube and sphere,
    /// but also contains usdz objects that must be loaded from app files
    /// these are custom usdz's we ship in the app, different from if user imports custom usdz
    ///
    /// Loop through all objects in allObjects list, load the object using ModelEntity.load if it isUsdz
    /// replace the corresponding PlaceableObject object inside allObjects with this newly loaded ModelEntity
    /// 
    func loadAllUsdzObjects() {
        Task { @MainActor in
            for object in allObjects {
                if object.isUsdz {
                    do {
                        let loadedModel = try await ModelEntity(named: object.name)
                        let loadedPlaceableObject = PlaceableObject(name: object.name, modelEntity: loadedModel, imageName: object.imageName, isUsdz: true)
                        if let indexToReplace = allObjects.firstIndex(where: { $0.name == object.name }) {
                           allObjects[indexToReplace] = loadedPlaceableObject
                            print("loaded usdz: \(object.name)")
                        }
                    } catch {
                        
                    }
                }
            }
        }
    }
    
    static func modelForName(name: String) -> ModelEntity? {
        let model = PlaceableObjects.shared.allObjects.first { $0.name == name }?.modelEntity
        if let model {
            return model
        } else {
            return nil
        }
    }
    
    static func currentModelSelected() -> ModelEntity {
        if let name = SelectedObjectManager.shared.selectedObject?.name, 
            let model = modelForName(name: name) {
            return model
        } else {
            return PlaceableObjects.shared.cube.modelEntity
        }
    }
    
    
}


class SelectedObjectManager {
    
    static var shared = SelectedObjectManager()
    var selectedObject: PlaceableObject? = nil
}
