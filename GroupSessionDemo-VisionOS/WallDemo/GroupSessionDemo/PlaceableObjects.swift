//
//  PlaceableObjects.swift
//  GroupSessionDemo
//
//  Created by Hunter Harris on 10/22/23.
//

import RealityKit

struct PlaceableObject {
    var name: String
    var modelEntity: ModelEntity
}

struct PlaceableObjects {
    
    static var allObjects = [cube, sphere]
    static var cube = PlaceableObject(name: "cube", modelEntity: ModelEntity(mesh: .generateBox(size: 1), materials: [UnlitMaterial(color: .blue)], collisionShape: .generateBox(size: .one), mass: 100))
    
    static var sphere = PlaceableObject(name: "sphere", modelEntity: ModelEntity(mesh: .generateSphere(radius: 0.5), materials: [UnlitMaterial(color: .blue)], collisionShape: .generateSphere(radius: 0.5), mass: 100))
    
    static func modelForName(name: String) -> ModelEntity? {
        let model = allObjects.first { $0.name == name }?.modelEntity
        if let model {
            return model
        } else {
            return nil
        }
    }
    
    static func currentModelSelected() -> ModelEntity {
        if let name = SelectedObjectManager.selectedObject?.name, let model = modelForName(name: name) {
            return model
        } else {
            return PlaceableObjects.cube.modelEntity
        }
    }
}


struct SelectedObjectManager {
    static var selectedObject: PlaceableObject? = nil
}
