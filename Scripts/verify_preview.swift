import UIKit

@main
struct PreviewRegressionChecks {
    @MainActor
    static func main() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 400), format: format)
            .image { context in
                UIColor.red.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 800, height: 400))
            }
        let preview = image.resizedForPreview(maxPixelLength: 1600)
        precondition(preview.cgImage?.width == 1600)
        precondition(preview.cgImage?.height == 800)
        precondition(preview.resizedForPreview(maxPixelLength: 1600) === preview)
        precondition(image.resizedForPreview(maxPixelLength: 0) === image)
        precondition(image.resizedForPreview(maxPixelLength: .nan) === image)

        func configuration(opacity: Double) -> PreviewCanvasUIView.Configuration {
            PreviewCanvasUIView.Configuration(
                image: preview, backgroundColor: .white,
                borderPercent: 1, aspectWidth: 1, aspectHeight: 1,
                activeTool: .imageWatermark, watermarkText: "",
                watermarkScale: 0.05, watermarkFontName: "System",
                watermarkColor: .black, watermarkX: 0.5, watermarkY: 0.5,
                stickerImage: image, stickerScale: 0.22, stickerOpacity: opacity,
                stickerX: 0.5, stickerY: 0.5
            )
        }
        let original = configuration(opacity: 1)
        precondition(original == configuration(opacity: 1))
        precondition(original != configuration(opacity: 0.5))
        var moved = original
        moved.stickerX = 0.6
        precondition(moved != original)
        precondition(original.stickerX == 0.5)
        print("PASS: pixel resize, invalid limits, unchanged configuration, opacity and position changes")
    }
}
