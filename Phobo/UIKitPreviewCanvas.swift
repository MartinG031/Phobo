import SwiftUI
import UIKit

// MARK: - UIKit 预览画布

struct UIKitPreviewCanvas: UIViewRepresentable {
    let image: UIImage
    let backgroundColor: UIColor
    let borderPercent: Double
    let aspectWidth: Double
    let aspectHeight: Double
    let activeTool: EditingTool

    let watermarkText: String
    let watermarkScale: Double
    let watermarkFontName: String
    let watermarkColor: UIColor
    @Binding var watermarkX: CGFloat
    @Binding var watermarkY: CGFloat

    let stickerImage: UIImage?
    let stickerScale: Double
    let stickerOpacity: Double
    @Binding var stickerX: CGFloat
    @Binding var stickerY: CGFloat

    func makeUIView(context: Context) -> PreviewCanvasUIView {
        let view = PreviewCanvasUIView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.contentMode = .redraw
        view.onWatermarkPositionChanged = { x, y in
            watermarkX = x
            watermarkY = y
        }
        view.onStickerPositionChanged = { x, y in
            stickerX = x
            stickerY = y
        }
        return view
    }

    func updateUIView(_ uiView: PreviewCanvasUIView, context: Context) {
        uiView.configuration = PreviewCanvasUIView.Configuration(
            image: image,
            backgroundColor: backgroundColor,
            borderPercent: borderPercent,
            aspectWidth: aspectWidth,
            aspectHeight: aspectHeight,
            activeTool: activeTool,
            watermarkText: watermarkText,
            watermarkScale: watermarkScale,
            watermarkFontName: watermarkFontName,
            watermarkColor: watermarkColor,
            watermarkX: watermarkX,
            watermarkY: watermarkY,
            stickerImage: stickerImage,
            stickerScale: stickerScale,
            stickerOpacity: stickerOpacity,
            stickerX: stickerX,
            stickerY: stickerY
        )
        uiView.onWatermarkPositionChanged = { x, y in
            watermarkX = x
            watermarkY = y
        }
        uiView.onStickerPositionChanged = { x, y in
            stickerX = x
            stickerY = y
        }
    }
}

final class PreviewCanvasUIView: UIView {
    struct Configuration {
        let image: UIImage
        let backgroundColor: UIColor
        let borderPercent: Double
        let aspectWidth: Double
        let aspectHeight: Double
        let activeTool: EditingTool
        let watermarkText: String
        let watermarkScale: Double
        let watermarkFontName: String
        let watermarkColor: UIColor
        let watermarkX: CGFloat
        let watermarkY: CGFloat
        let stickerImage: UIImage?
        let stickerScale: Double
        let stickerOpacity: Double
        let stickerX: CGFloat
        let stickerY: CGFloat
    }

    var configuration: Configuration? {
        didSet { setNeedsDisplay() }
    }

    var onWatermarkPositionChanged: ((CGFloat, CGFloat) -> Void)?
    var onStickerPositionChanged: ((CGFloat, CGFloat) -> Void)?

    private enum DragTarget {
        case watermark
        case sticker
    }

    private var dragTarget: DragTarget?
    private var dragStart = CGPoint.zero
    private var dragStartLocation = CGPoint.zero
    private var showVerticalGuide = false
    private var showHorizontalGuide = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let config = configuration,
              let layout = makeLayout(for: config, in: bounds.size),
              let context = UIGraphicsGetCurrentContext() else { return }

        config.backgroundColor.setFill()
        UIBezierPath(rect: layout.canvasRect).fill()

        config.image.draw(in: layout.imageRect)

        if let sticker = config.stickerImage {
            let stickerRect = stickerRect(for: sticker, config: config, layout: layout)
            context.saveGState()
            context.setAlpha(CGFloat(config.stickerOpacity))
            sticker.draw(in: stickerRect)
            context.restoreGState()
        }

        if !config.watermarkText.isEmpty {
            let textRect = watermarkTextRect(config: config, layout: layout)
            let attributes = watermarkTextAttributes(config: config, layout: layout)
            context.saveGState()
            NSAttributedString(string: config.watermarkText, attributes: attributes)
                .draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            context.restoreGState()
        }

        if showVerticalGuide {
            UIColor.white.withAlphaComponent(0.4).setFill()
            UIRectFill(CGRect(x: layout.canvasRect.midX - 0.5,
                              y: layout.canvasRect.minY,
                              width: 1,
                              height: layout.canvasRect.height))
        }

        if showHorizontalGuide {
            UIColor.white.withAlphaComponent(0.4).setFill()
            UIRectFill(CGRect(x: layout.canvasRect.minX,
                              y: layout.canvasRect.midY - 0.5,
                              width: layout.canvasRect.width,
                              height: 1))
        }
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard var config = configuration,
              let layout = makeLayout(for: config, in: bounds.size) else { return }

        let location = recognizer.location(in: self)

        switch recognizer.state {
        case .began:
            dragTarget = target(at: location, config: config, layout: layout)
            dragStartLocation = location
            switch dragTarget {
            case .watermark:
                dragStart = CGPoint(x: config.watermarkX, y: config.watermarkY)
            case .sticker:
                dragStart = CGPoint(x: config.stickerX, y: config.stickerY)
            case nil:
                dragStart = .zero
            }

        case .changed:
            guard let dragTarget else { return }
            let dx = (location.x - dragStartLocation.x) / max(layout.canvasRect.width, 1)
            let dy = (location.y - dragStartLocation.y) / max(layout.canvasRect.height, 1)
            let itemSize = dragItemSize(for: dragTarget, config: config, layout: layout)
            let snapped = snappedPosition(
                x: dragStart.x + dx,
                y: dragStart.y + dy,
                itemSize: itemSize,
                layout: layout
            )

            showVerticalGuide = snapped.showVerticalGuide
            showHorizontalGuide = snapped.showHorizontalGuide

            switch dragTarget {
            case .watermark:
                config = updated(config, watermarkX: snapped.x, watermarkY: snapped.y)
                configuration = config
                onWatermarkPositionChanged?(snapped.x, snapped.y)
            case .sticker:
                config = updated(config, stickerX: snapped.x, stickerY: snapped.y)
                configuration = config
                onStickerPositionChanged?(snapped.x, snapped.y)
            }

        case .ended, .cancelled, .failed:
            dragTarget = nil
            showVerticalGuide = false
            showHorizontalGuide = false
            setNeedsDisplay()

        default:
            break
        }
    }

    private func target(at point: CGPoint, config: Configuration, layout: CanvasLayout) -> DragTarget? {
        switch config.activeTool {
        case .watermark:
            guard !config.watermarkText.isEmpty else { return nil }
            return watermarkTextRect(config: config, layout: layout).insetBy(dx: -18, dy: -18).contains(point) ? .watermark : nil
        case .imageWatermark:
            guard let sticker = config.stickerImage else { return nil }
            return stickerRect(for: sticker, config: config, layout: layout).insetBy(dx: -18, dy: -18).contains(point) ? .sticker : nil
        case .border:
            return nil
        }
    }

    private func makeLayout(for config: Configuration, in availableSize: CGSize) -> CanvasLayout? {
        CanvasLayoutEngine.previewLayout(
            imageSize: config.image.size,
            availableSize: availableSize,
            borderPercent: config.borderPercent,
            aspectWidth: config.aspectWidth,
            aspectHeight: config.aspectHeight
        )
    }

    private func stickerRect(for sticker: UIImage, config: Configuration, layout: CanvasLayout) -> CGRect {
        let size = stickerSize(for: sticker,
                               baseLength: min(layout.canvasRect.width, layout.canvasRect.height),
                               scale: CGFloat(config.stickerScale))
        let center = CGPoint(x: layout.canvasRect.minX + layout.canvasRect.width * config.stickerX,
                             y: layout.canvasRect.minY + layout.canvasRect.height * config.stickerY)
        return CGRect(x: center.x - size.width / 2,
                      y: center.y - size.height / 2,
                      width: size.width,
                      height: size.height)
    }

    private func watermarkTextRect(config: Configuration, layout: CanvasLayout) -> CGRect {
        let maxWidth = max(layout.canvasRect.width * 0.8, 1)
        let attributes = watermarkTextAttributes(config: config, layout: layout)
        let text = config.watermarkText as NSString
        let size = text.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        ).integral.size
        let center = CGPoint(x: layout.canvasRect.minX + layout.canvasRect.width * config.watermarkX,
                             y: layout.canvasRect.minY + layout.canvasRect.height * config.watermarkY)
        return CGRect(x: center.x - size.width / 2,
                      y: center.y - size.height / 2,
                      width: min(size.width, maxWidth),
                      height: size.height)
    }

    private func watermarkTextAttributes(config: Configuration, layout: CanvasLayout) -> [NSAttributedString.Key: Any] {
        let fontSize = min(layout.canvasRect.width, layout.canvasRect.height) * CGFloat(config.watermarkScale)
        let font: UIFont
        if config.watermarkFontName == "System" {
            font = .systemFont(ofSize: fontSize, weight: .semibold)
        } else {
            font = UIFont(name: config.watermarkFontName, size: fontSize)
                ?? .systemFont(ofSize: fontSize, weight: .semibold)
        }

        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black.withAlphaComponent(0.4)
        shadow.shadowOffset = CGSize(width: 1, height: 1)
        shadow.shadowBlurRadius = 3

        return [
            .font: font,
            .foregroundColor: config.watermarkColor,
            .shadow: shadow
        ]
    }

    private func dragItemSize(for target: DragTarget, config: Configuration, layout: CanvasLayout) -> CGSize {
        switch target {
        case .watermark:
            return watermarkTextRect(config: config, layout: layout).size
        case .sticker:
            guard let sticker = config.stickerImage else { return .zero }
            return stickerRect(for: sticker, config: config, layout: layout).size
        }
    }

    private func snappedPosition(x: CGFloat,
                                 y: CGFloat,
                                 itemSize: CGSize,
                                 layout: CanvasLayout) -> (x: CGFloat, y: CGFloat, showVerticalGuide: Bool, showHorizontalGuide: Bool) {
        var x = x
        var y = y

        let halfWidth = min(max((itemSize.width / max(layout.canvasRect.width, 1)) / 2, 0.02), 0.48)
        let halfHeight = min(max((itemSize.height / max(layout.canvasRect.height, 1)) / 2, 0.02), 0.48)

        x = min(max(x, halfWidth), 1 - halfWidth)
        y = min(max(y, halfHeight), 1 - halfHeight)

        let snapThreshold: CGFloat = 0.03
        let edgeSnapThreshold: CGFloat = 0.02
        var showVerticalGuide = false
        var showHorizontalGuide = false

        if abs(x - 0.5) < snapThreshold {
            x = 0.5
            showVerticalGuide = true
        }
        if abs(y - 0.5) < snapThreshold {
            y = 0.5
            showHorizontalGuide = true
        }

        if let borderCenterY = bottomBorderCenterY(layout: layout),
           abs(y - borderCenterY) < snapThreshold {
            y = borderCenterY
        }

        if let leftCenterX = leftBorderCenterX(layout: layout),
           abs(x - leftCenterX) < snapThreshold {
            x = leftCenterX
        } else if let rightCenterX = rightBorderCenterX(layout: layout),
                  abs(x - rightCenterX) < snapThreshold {
            x = rightCenterX
        }

        if abs(x - halfWidth) < snapThreshold {
            x = halfWidth
        } else if abs(x - (1 - halfWidth)) < snapThreshold {
            x = 1 - halfWidth
        }

        if abs(y - halfHeight) < edgeSnapThreshold {
            y = halfHeight
        } else if abs(y - (1 - halfHeight)) < edgeSnapThreshold {
            y = 1 - halfHeight
        }

        return (x, y, showVerticalGuide, showHorizontalGuide)
    }

    private func bottomBorderCenterY(layout: CanvasLayout) -> CGFloat? {
        let borderHeight = layout.canvasRect.height - layout.imageRect.height
        guard borderHeight / max(layout.canvasRect.height, 1) > 0.05 else { return nil }
        let imageBottom = (layout.canvasRect.height + layout.imageRect.height) / 2
        let bottomCenter = (imageBottom + layout.canvasRect.height) / 2
        return bottomCenter / layout.canvasRect.height
    }

    private func leftBorderCenterX(layout: CanvasLayout) -> CGFloat? {
        let totalBorderWidth = layout.canvasRect.width - layout.imageRect.width
        guard totalBorderWidth > 0 else { return nil }
        let sideBorderWidth = totalBorderWidth / 2
        guard sideBorderWidth / max(layout.canvasRect.width, 1) > 0.05 else { return nil }
        return (sideBorderWidth / 2) / layout.canvasRect.width
    }

    private func rightBorderCenterX(layout: CanvasLayout) -> CGFloat? {
        guard let left = leftBorderCenterX(layout: layout) else { return nil }
        return 1 - left
    }

    private func stickerSize(for sticker: UIImage, baseLength: CGFloat, scale: CGFloat) -> CGSize {
        let target = baseLength * scale
        let originalSize = sticker.size
        let ratio = originalSize.width / max(originalSize.height, 0.1)

        if ratio >= 1 {
            return CGSize(width: target, height: target / max(ratio, 0.1))
        } else {
            return CGSize(width: target * ratio, height: target)
        }
    }

    private func updated(_ config: Configuration, watermarkX: CGFloat, watermarkY: CGFloat) -> Configuration {
        Configuration(
            image: config.image,
            backgroundColor: config.backgroundColor,
            borderPercent: config.borderPercent,
            aspectWidth: config.aspectWidth,
            aspectHeight: config.aspectHeight,
            activeTool: config.activeTool,
            watermarkText: config.watermarkText,
            watermarkScale: config.watermarkScale,
            watermarkFontName: config.watermarkFontName,
            watermarkColor: config.watermarkColor,
            watermarkX: watermarkX,
            watermarkY: watermarkY,
            stickerImage: config.stickerImage,
            stickerScale: config.stickerScale,
            stickerOpacity: config.stickerOpacity,
            stickerX: config.stickerX,
            stickerY: config.stickerY
        )
    }

    private func updated(_ config: Configuration, stickerX: CGFloat, stickerY: CGFloat) -> Configuration {
        Configuration(
            image: config.image,
            backgroundColor: config.backgroundColor,
            borderPercent: config.borderPercent,
            aspectWidth: config.aspectWidth,
            aspectHeight: config.aspectHeight,
            activeTool: config.activeTool,
            watermarkText: config.watermarkText,
            watermarkScale: config.watermarkScale,
            watermarkFontName: config.watermarkFontName,
            watermarkColor: config.watermarkColor,
            watermarkX: config.watermarkX,
            watermarkY: config.watermarkY,
            stickerImage: config.stickerImage,
            stickerScale: config.stickerScale,
            stickerOpacity: config.stickerOpacity,
            stickerX: stickerX,
            stickerY: stickerY
        )
    }
}
