//
//  Utility.swift
//  Joj
//
//  Created by Hunter Harris on 11/22/23.
//

import Foundation
import RealityKit
import SwiftUI

extension UUID {
    var asPlayerName: String {
        String(uuidString.split(separator: "-").last!)
    }
}

class Utility {
    
    static var documentsUrl: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    /// Loads url to create UIImage, uses UIImage to generate SimpleMaterial texture
    /// returns ModelEntity with image texture
    @MainActor
    static func convertToCGImage_AndCreatePlaneEntity(fromURL url: URL, id: String) async -> ModelEntity? {
        do {
            if let imageData = try? Data(contentsOf: url),
                let image = UIImage(data: imageData), let cgImage = image.cgImage {
                    let texture: TextureResource = try await .generate(from: cgImage, options: .init(semantic: .normal))
                    var material: SimpleMaterial = .init()
                    material.color = .init(tint: .white.withAlphaComponent(0.999), texture: .init(texture))
                    let entity = ModelEntity(mesh: .generatePlane(width: 2, height: 1.75), materials: [material])
                    
                    entity.generateCollisionShapes(recursive: false)
                    entity.components.set(InputTargetComponent(allowedInputTypes: .all))
                    entity.position = .zero
                    entity.name = id
                    
                    return entity
               
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
    
    @MainActor
    static func loadUsdzFromAttachment(url: URL, id: String) async -> ModelEntity? {
        do {
            let model = try await ModelEntity(contentsOf: url)
            
            model.generateCollisionShapes(recursive: false)
            model.components.set(InputTargetComponent(allowedInputTypes: .all))
            model.position = .zero
            model.name = id
            
            return model
        } catch {
            return nil
        }
    }
    
    //TEST: this is loading from remote url
//    static func convertToCGImage_AndCreatePlaneEntity(fromURL url: URL, id: String) async throws -> ModelEntity? {
//        let (data, _): (Data, URLResponse) = try await withCheckedThrowingContinuation { continuation in
//            URLSession.shared.dataTask(with: url) { data, response, error in
//                if let error = error {
//                    continuation.resume(throwing: error)
//                    return
//                }
//                guard let data = data, let response = response as? HTTPURLResponse, response.statusCode == 200 else {
//                    continuation.resume(throwing: URLError(.badServerResponse))
//                    return
//                }
//                continuation.resume(returning: (data, response))
//            }.resume()
//        }
//
//        // On the main thread, convert the data to an image and create a ModelEntity
//        return try await withCheckedThrowingContinuation { continuation in
//            DispatchQueue.main.async {
//                if let image = UIImage(data: data), let cgImage = image.cgImage {
//                    do {
//                        let texture: TextureResource = try .generate(from: cgImage, options: .init(semantic: .normal))
//                        var material: SimpleMaterial = .init()
//                        material.color = .init(tint: .white.withAlphaComponent(0.999), texture: .init(texture))
//                        let entity = ModelEntity(mesh: .generatePlane(width: 2, height: 1.75), materials: [material])
//
//                        entity.generateCollisionShapes(recursive: false)
//                        entity.components.set(InputTargetComponent(allowedInputTypes: .all))
//                        entity.position = .zero
//                        entity.name = id
//
//                        continuation.resume(returning: entity)
//                    } catch {
//                        continuation.resume(throwing: error)
//                    }
//                } else {
//                    continuation.resume(returning: nil)
//                }
//            }
//        }
//    }
    
    static func writeDataToDocuments(data: Data, fileName: String) -> URL? {
        do {
            let fileType = data.detectType()
            var fileTypeString = ""
            switch fileType {
            case .jpeg:
                fileTypeString = "jpeg"
            case .png:
                fileTypeString = "png"
            case .usdz:
                fileTypeString = "usdz"
            case .unknown:
                return nil
            }
            
            let savedUrl = documentsUrl.appendingPathComponent(fileName).appendingPathExtension(fileTypeString)
            try data.write(to: savedUrl)
            print("Saved file to: \(savedUrl)")
            return savedUrl
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
}
