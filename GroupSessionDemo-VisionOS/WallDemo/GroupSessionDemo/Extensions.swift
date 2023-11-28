//
//  Extensions.swift
//  Joj
//
//  Created by Hunter Harris on 11/26/23.
//

import Foundation
import MobileCoreServices
import UniformTypeIdentifiers

extension Data {
    enum FileType {
        case png
        case jpeg
        case usdz
        case unknown
    }
    
    func detectType() -> FileType {
        let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        let jpegSignature: [UInt8] = [0xFF, 0xD8, 0xFF]
        let usdzSignature: [UInt8] = [0x50, 0x4B, 0x03, 0x04]
        
        if self.starts(with: pngSignature) {
            return .png
        } else if self.starts(with: jpegSignature) {
            return .jpeg
        } else if self.starts(with: usdzSignature) {
            return .usdz
        } else {
            return .unknown
        }
    }
}
