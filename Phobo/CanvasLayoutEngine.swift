import UIKit

struct CanvasLayout {
    let canvasRect: CGRect
    let imageRect: CGRect

    var canvasSize: CGSize {
        canvasRect.size
    }
}

enum CanvasLayoutEngine {
    static func previewLayout(imageSize: CGSize,
                              availableSize: CGSize,
                              borderPercent: Double,
                              aspectWidth: Double,
                              aspectHeight: Double) -> CanvasLayout? {
        let baseCanvasSize = baseCanvasSize(
            imageSize: imageSize,
            borderPercent: borderPercent,
            aspectWidth: aspectWidth,
            aspectHeight: aspectHeight
        )

        let previewScale = min(availableSize.width / baseCanvasSize.width,
                               availableSize.height / baseCanvasSize.height)
        guard previewScale.isFinite, previewScale > 0 else { return nil }

        let canvasSize = CGSize(width: baseCanvasSize.width * previewScale,
                                height: baseCanvasSize.height * previewScale)
        let canvasOrigin = CGPoint(x: (availableSize.width - canvasSize.width) / 2,
                                   y: (availableSize.height - canvasSize.height) / 2)
        let imageDrawSize = CGSize(width: max(imageSize.width, 1) * previewScale,
                                   height: max(imageSize.height, 1) * previewScale)
        let imageOrigin = CGPoint(x: canvasOrigin.x + (canvasSize.width - imageDrawSize.width) / 2,
                                  y: canvasOrigin.y + (canvasSize.height - imageDrawSize.height) / 2)

        return CanvasLayout(
            canvasRect: CGRect(origin: canvasOrigin, size: canvasSize),
            imageRect: CGRect(origin: imageOrigin, size: imageDrawSize)
        )
    }

    static func renderLayout(imageSize: CGSize,
                             borderPercent: Double,
                             aspectWidth: Double,
                             aspectHeight: Double,
                             maxCanvasSide: CGFloat = 4000) -> CanvasLayout {
        let baseCanvasSize = baseCanvasSize(
            imageSize: imageSize,
            borderPercent: borderPercent,
            aspectWidth: aspectWidth,
            aspectHeight: aspectHeight
        )
        let baseLongest = max(baseCanvasSize.width, baseCanvasSize.height)
        let scale = min(maxCanvasSide / baseLongest, 1.0)

        let canvasSize = CGSize(width: (baseCanvasSize.width * scale).rounded(.up),
                                height: (baseCanvasSize.height * scale).rounded(.up))
        let imageDrawSize = CGSize(width: max(imageSize.width, 1) * scale,
                                   height: max(imageSize.height, 1) * scale)
        let imageOrigin = CGPoint(x: (canvasSize.width - imageDrawSize.width) / 2,
                                  y: (canvasSize.height - imageDrawSize.height) / 2)

        return CanvasLayout(
            canvasRect: CGRect(origin: .zero, size: canvasSize),
            imageRect: CGRect(origin: imageOrigin, size: imageDrawSize)
        )
    }

    private static func baseCanvasSize(imageSize: CGSize,
                                       borderPercent: Double,
                                       aspectWidth: Double,
                                       aspectHeight: Double) -> CGSize {
        let imageWidth = max(imageSize.width, 1)
        let imageHeight = max(imageSize.height, 1)
        let longestSide = max(imageWidth, imageHeight)
        let clampedPercent = max(min(borderPercent, 100), 1)
        let borderWidth = longestSide * CGFloat(clampedPercent / 100.0)
        let aspect = CGFloat(max(aspectWidth, 0.01) / max(aspectHeight, 0.01))

        if imageWidth + 2 * borderWidth >= aspect * (imageHeight + 2 * borderWidth) {
            let canvasWidth = imageWidth + 2 * borderWidth
            return CGSize(width: canvasWidth, height: canvasWidth / aspect)
        } else {
            let canvasHeight = imageHeight + 2 * borderWidth
            return CGSize(width: aspect * canvasHeight, height: canvasHeight)
        }
    }
}
