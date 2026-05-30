import Combine
import SwiftUI
import UIKit

struct SharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

@MainActor
final class ImagePipeline: ObservableObject {
    @Published var inputImage: UIImage? {
        didSet {
            updatePreviewImage(for: inputImage)
        }
    }
    @Published private(set) var previewImage: UIImage?
    @Published var sharePayload: SharePayload?
    @Published var isRenderingOutput = false
    @Published var showSaveSuccessAlert = false
    @Published var showSaveErrorAlert = false
    @Published var saveErrorMessage = ""

    private var previewGenerationID = UUID()

    func save(config: RenderConfig) {
        guard !isRenderingOutput else { return }
        isRenderingOutput = true

        DispatchQueue.global(qos: .userInitiated).async {
            let renderedImage = RenderService.render(config: config)

            SaveService.saveToPhotos(image: renderedImage) { [weak self] result in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.isRenderingOutput = false
                    switch result {
                    case .success:
                        self.showSaveSuccessAlert = true
                    case .failure(let error):
                        self.saveErrorMessage = error.localizedDescription
                        self.showSaveErrorAlert = true
                    }
                }
            }
        }
    }

    func share(config: RenderConfig) {
        guard !isRenderingOutput else { return }
        isRenderingOutput = true

        DispatchQueue.global(qos: .userInitiated).async {
            let renderedImage = RenderService.render(config: config)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isRenderingOutput = false
                self.sharePayload = SharePayload(image: renderedImage)
            }
        }
    }

    private func updatePreviewImage(for image: UIImage?) {
        let generationID = UUID()
        previewGenerationID = generationID
        previewImage = nil

        guard let image else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let resizedImage = image.resizedForPreview(maxPixelLength: 1600)

            DispatchQueue.main.async { [weak self] in
                guard let self, self.previewGenerationID == generationID else { return }
                self.previewImage = resizedImage
            }
        }
    }
}
