//
//  extension.swift
//  VideoCon
//
//  Created by Sajjad Sarkoobi on 11/27/20.
//

import Foundation
import AVFoundation

extension URL {
    var attributes: [FileAttributeKey : Any]? {
        do {
            return try FileManager.default.attributesOfItem(atPath: path)
        } catch let error as NSError {
            print("FileAttribute error: \(error)")
        }
        return nil
    }

    var fileSize: Double {
        return attributes?[.size] as? Double ?? Double(0)
    }

    var fileSizeInMBString: String {
        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }

    var creationDate: Date? {
        return attributes?[.creationDate] as? Date
    }
}


//Check if video is playing
extension AVPlayer {
    var isPlaying: Bool {
        if (self.rate != 0 && self.error == nil) {
            return true
        } else {
            return false
        }
    }
}
