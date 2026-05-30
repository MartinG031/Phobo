import SwiftUI
import UIKit

struct EditorState {
    var backgroundColor: Color = .white
    var borderPercent: Double = 1
    var selectedTool: EditingTool = .border

    var watermarkText: String = ""
    var watermarkScale: Double = 0.05
    var watermarkColor: Color = .black
    var watermarkFontName: String = "System"
    var watermarkX: CGFloat = 0.85
    var watermarkY: CGFloat = 0.9

    var imageWatermarks: [UIImage] = []
    var selectedImageWatermarkIndex: Int?
    var imageWatermarkScale: Double = 0.22
    var imageWatermarkOpacity: Double = 1.0
    var imageWatermarkX: CGFloat = 0.85
    var imageWatermarkY: CGFloat = 0.85

    var selectedStickerImage: UIImage? {
        guard let index = selectedImageWatermarkIndex,
              imageWatermarks.indices.contains(index) else {
            return nil
        }
        return imageWatermarks[index]
    }

    mutating func appendImageWatermark(_ image: UIImage) {
        imageWatermarks.append(image)
        selectedImageWatermarkIndex = imageWatermarks.indices.last
    }

    mutating func restoreImageWatermarks(_ images: [UIImage], selectedIndex: Int?) {
        imageWatermarks = images
        selectedImageWatermarkIndex = selectedIndex
    }

    mutating func deleteImageWatermark(at index: Int) {
        guard imageWatermarks.indices.contains(index) else { return }

        imageWatermarks.remove(at: index)
        if let selected = selectedImageWatermarkIndex {
            if selected == index {
                selectedImageWatermarkIndex = nil
            } else if selected > index {
                selectedImageWatermarkIndex = selected - 1
            }
        }
    }

    func saveImageWatermarks() {
        ImageWatermarkStore.save(
            images: imageWatermarks,
            selectedIndex: selectedImageWatermarkIndex
        )
    }

    func saveSelectedImageWatermarkIndex() {
        ImageWatermarkStore.persistSelectedIndex(
            selectedImageWatermarkIndex,
            imageCount: imageWatermarks.count
        )
    }

    func renderConfig(for originalImage: UIImage,
                      aspectWidth: Double,
                      aspectHeight: Double) -> RenderConfig {
        RenderConfig(
            originalImage: originalImage,
            backgroundColor: UIColor(backgroundColor),
            borderPercent: borderPercent,
            aspectWidth: aspectWidth,
            aspectHeight: aspectHeight,
            watermarkText: watermarkText,
            watermarkScale: watermarkScale,
            watermarkFontName: watermarkFontName,
            watermarkColor: UIColor(watermarkColor),
            watermarkX: watermarkX,
            watermarkY: watermarkY,
            stickerImage: selectedStickerImage,
            stickerScale: imageWatermarkScale,
            stickerOpacity: imageWatermarkOpacity,
            stickerX: imageWatermarkX,
            stickerY: imageWatermarkY
        )
    }
}
