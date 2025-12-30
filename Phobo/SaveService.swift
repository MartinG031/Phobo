// SaveService.swift
// 负责将 UIImage 保存到系统相册，并控制输出文件大小

import UIKit
import Photos

enum SaveService {

    enum SaveError: Error {
        case cannotGenerateData
        case photoLibrary(String)
    }

    /// 保存到相册：PNG ≤ 10MB 优先，其余情况用 JPEG 逐级压缩
    static func saveToPhotos(image: UIImage,
                             completion: @escaping (Result<Void, SaveError>) -> Void) {

        let maxFileSizeBytes = 10 * 1024 * 1024   // 约 10MB

        var imageData: Data?
        var uniformTypeIdentifier = "public.png"

        // 1. 先尝试 PNG
        if let pngData = image.pngData(),
           pngData.count <= maxFileSizeBytes {
            imageData = pngData
            uniformTypeIdentifier = "public.png"
        } else {
            // 2. PNG 太大或失败，用 JPEG 逐级压缩
            let qualities: [CGFloat] = [0.95, 0.9, 0.85, 0.8, 0.75, 0.7, 0.65, 0.6]
            var selectedData: Data?

            for q in qualities {
                if let jpegData = image.jpegData(compressionQuality: q) {
                    selectedData = jpegData
                    uniformTypeIdentifier = "public.jpeg"
                    if jpegData.count <= maxFileSizeBytes {
                        break
                    }
                }
            }

            imageData = selectedData
        }

        guard let finalData = imageData else {
            completion(.failure(.cannotGenerateData))
            return
        }

        PHPhotoLibrary.shared().performChanges({
            let options = PHAssetResourceCreationOptions()
            options.uniformTypeIdentifier = uniformTypeIdentifier
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .photo, data: finalData, options: options)
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(()))
                } else {
                    let message = error?.localizedDescription ?? "保存图像失败。"
                    completion(.failure(.photoLibrary(message)))
                }
            }
        })
    }
}
