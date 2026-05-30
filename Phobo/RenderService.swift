// RenderService.swift
// 负责将原图 + 边框 + 文字水印 + 图片水印渲染成一张 UIImage

import SwiftUI
import UIKit

/// 渲染配置：把 ContentView 里所有和成品相关的参数打包
struct RenderConfig {
    let originalImage: UIImage

    // 画布外观
    let backgroundColor: UIColor
    let borderPercent: Double           // 1...100
    let aspectWidth: Double             // 画布宽比
    let aspectHeight: Double            // 画布高比

    // 文字水印
    let watermarkText: String
    let watermarkScale: Double          // 相对于画布短边的比例
    let watermarkFontName: String       // "System" 或具体字体名
    let watermarkColor: UIColor
    let watermarkX: CGFloat             // 归一化中心点 (0...1)
    let watermarkY: CGFloat

    // 图片水印
    let stickerImage: UIImage?
    let stickerScale: Double            // 相对于画布短边的比例
    let stickerOpacity: Double
    let stickerX: CGFloat               // 归一化中心点 (0...1)
    let stickerY: CGFloat
}

enum RenderService {

    /// 根据配置渲染出一张成品图（不负责保存）
    static func render(config: RenderConfig) -> UIImage {
        let originalImage = config.originalImage

        let layout = CanvasLayoutEngine.renderLayout(
            imageSize: originalImage.size,
            borderPercent: config.borderPercent,
            aspectWidth: config.aspectWidth,
            aspectHeight: config.aspectHeight
        )
        let canvasSize = layout.canvasSize

        let uiColor = config.backgroundColor

        // 用 UIGraphicsImageRenderer 合成成品图
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0          // 让 canvasSize 对应实际像素
        format.opaque = true        // 不需要透明通道

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        let renderedImage = renderer.image { _ in
            // 背景纯色
            uiColor.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: canvasSize)).fill()

            // 原图
            originalImage.draw(in: layout.imageRect)

            // 图片水印（如果有）
            if let sticker = config.stickerImage {
                let baseLength = min(canvasSize.width, canvasSize.height)
                let stickerSize = stickerSize(for: sticker,
                                              baseLength: baseLength,
                                              scale: CGFloat(config.stickerScale))

                let origin = CGPoint(
                    x: canvasSize.width * config.stickerX - stickerSize.width / 2,
                    y: canvasSize.height * config.stickerY - stickerSize.height / 2
                )
                let rect = CGRect(origin: origin, size: stickerSize)
                sticker.draw(in: rect,
                             blendMode: .normal,
                             alpha: CGFloat(config.stickerOpacity))
            }

            // 文字水印
            if !config.watermarkText.isEmpty {
                let text = config.watermarkText as NSString
                let fontSize = min(canvasSize.width, canvasSize.height) * CGFloat(config.watermarkScale)

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

                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: config.watermarkColor,
                    .shadow: shadow
                ]

                let textSize = text.size(withAttributes: attributes)

                let centerX = canvasSize.width * config.watermarkX
                let centerY = canvasSize.height * config.watermarkY
                let origin = CGPoint(
                    x: centerX - textSize.width / 2,
                    y: centerY - textSize.height / 2
                )

                text.draw(at: origin, withAttributes: attributes)
            }
        }

        return renderedImage
    }

    /// 贴纸尺寸计算：保持宽高比，沿短边缩放
    private static func stickerSize(for sticker: UIImage,
                                    baseLength: CGFloat,
                                    scale: CGFloat) -> CGSize {
        let target = baseLength * scale
        let originalSize = sticker.size
        let ratio = originalSize.width / max(originalSize.height, 0.1)

        if ratio >= 1 {
            return CGSize(width: target,
                          height: target / max(ratio, 0.1))
        } else {
            return CGSize(width: target * ratio,
                          height: target)
        }
    }
}
