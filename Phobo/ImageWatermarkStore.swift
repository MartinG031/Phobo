// ImageWatermarkStore.swift
// 负责图片水印文件和选中状态的持久化

import Foundation
import UIKit

enum ImageWatermarkStore {
    private static let selectedIndexKey = "ImageWatermarkSelectedIndex"
    private static let ioQueue = DispatchQueue(label: "Martin.Phobo.watermarkStore", qos: .utility)

    static func load(completion: @escaping ([UIImage], Int?) -> Void) {
        ioQueue.async {
            let persistedSelectedIndex = UserDefaults.standard.object(forKey: selectedIndexKey) as? Int
            guard let dir = imageWatermarksDirectoryURL() else {
                DispatchQueue.main.async {
                    completion([], nil)
                }
                return
            }

            let fm = FileManager.default
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

            guard let files = try? fm.contentsOfDirectory(at: dir,
                                                          includingPropertiesForKeys: nil,
                                                          options: [.skipsHiddenFiles]) else {
                DispatchQueue.main.async {
                    completion([], nil)
                }
                return
            }

            let sortedFiles = files.filter { $0.pathExtension.lowercased() == "png" }
                .sorted {
                    $0.lastPathComponent.compare($1.lastPathComponent, options: .numeric) == .orderedAscending
                }

            var loaded: [UIImage] = []
            for url in sortedFiles {
                autoreleasepool {
                    if let data = try? Data(contentsOf: url),
                       let img = UIImage(data: data) {
                        loaded.append(img)
                    }
                }
            }

            let restoredIndex: Int?
            if let index = persistedSelectedIndex,
               loaded.indices.contains(index) {
                restoredIndex = index
            } else {
                restoredIndex = nil
            }

            DispatchQueue.main.async {
                completion(loaded, restoredIndex)
            }
        }
    }

    static func save(images: [UIImage], selectedIndex: Int?) {
        ioQueue.async {
            guard let dir = imageWatermarksDirectoryURL() else { return }

            let fm = FileManager.default
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

            if let files = try? fm.contentsOfDirectory(at: dir,
                                                       includingPropertiesForKeys: nil,
                                                       options: [.skipsHiddenFiles]) {
                for url in files {
                    try? fm.removeItem(at: url)
                }
            }

            for (index, img) in images.enumerated() {
                autoreleasepool {
                    if let data = img.pngData() {
                        let filename = "wm_\(index).png"
                        let fileURL = dir.appendingPathComponent(filename)
                        try? data.write(to: fileURL, options: .atomic)
                    }
                }
            }
            writeSelectedIndex(selectedIndex, imageCount: images.count)
        }
    }

    static func persistSelectedIndex(_ selectedIndex: Int?, imageCount: Int) {
        ioQueue.async {
            writeSelectedIndex(selectedIndex, imageCount: imageCount)
        }
    }

    private static func writeSelectedIndex(_ selectedIndex: Int?, imageCount: Int) {
        if let index = selectedIndex,
           (0..<imageCount).contains(index) {
            UserDefaults.standard.set(index, forKey: selectedIndexKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedIndexKey)
        }
    }

    private static func imageWatermarksDirectoryURL() -> URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return docs.appendingPathComponent("ImageWatermarks", isDirectory: true)
    }
}
