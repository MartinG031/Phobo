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

        // 1. 原图尺寸与边框宽度（以原图最长边为基准的百分比）
        let origSize = originalImage.size
        let origWidth = origSize.width
        let origHeight = origSize.height
        let longestOrig = max(origWidth, origHeight)

        let clampedPercent = max(min(config.borderPercent, 100), 1)
        let borderWidth = longestOrig * CGFloat(clampedPercent / 100.0)

        // 2. 画布宽高比（背景 + 原图）
        let aspectW = max(config.aspectWidth, 0.01)
        let aspectH = max(config.aspectHeight, 0.01)
        let targetAspect: CGFloat = CGFloat(aspectW / aspectH)    // Wc / Hc

        // 3. 理论画布尺寸：保证某一方向的留白恰好 = borderWidth
        let baseCanvasSize: CGSize
        if origWidth + 2 * borderWidth >= targetAspect * (origHeight + 2 * borderWidth) {
            // 水平方向是最窄边
            let canvasWidth = origWidth + 2 * borderWidth
            let canvasHeight = canvasWidth / targetAspect
            baseCanvasSize = CGSize(width: canvasWidth, height: canvasHeight)
        } else {
            // 垂直方向是最窄边
            let canvasHeight = origHeight + 2 * borderWidth
            let canvasWidth = targetAspect * canvasHeight
            baseCanvasSize = CGSize(width: canvasWidth, height: canvasHeight)
        }

        // 4. 整体等比缩放，限制最大输出分辨率（最长边 ≤ 4000px）
        let baseLongest = max(baseCanvasSize.width, baseCanvasSize.height)
        let maxCanvasSide: CGFloat = 4000
        let globalScale: CGFloat = min(maxCanvasSide / baseLongest, 1.0)

        // 整体等比例缩放（画布和图片一起缩小），保持边框相对宽度不变
        let imageScale = globalScale

        // 画布尺寸：向上取整到像素，避免右侧/底部 1 像素黑边
        var canvasWidth = baseCanvasSize.width * imageScale
        var canvasHeight = baseCanvasSize.height * imageScale
        canvasWidth = canvasWidth.rounded(.up)
        canvasHeight = canvasHeight.rounded(.up)
        let canvasSize = CGSize(width: canvasWidth, height: canvasHeight)

        // 原图缩放尺寸（不额外取整，避免比例失真）
        let drawWidth = origWidth * imageScale
        let drawHeight = origHeight * imageScale

        // 居中放置原图
        let drawRect = CGRect(
            x: (canvasWidth - drawWidth) / 2,
            y: (canvasHeight - drawHeight) / 2,
            width: drawWidth,
            height: drawHeight
        )

        let uiColor = config.backgroundColor

        // 5. 用 UIGraphicsImageRenderer 合成成品图
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0          // 让 canvasSize 对应实际像素
        format.opaque = true        // 不需要透明通道

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        let renderedImage = renderer.image { _ in
            // 背景纯色
            uiColor.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: canvasSize)).fill()

            // 原图
            originalImage.draw(in: drawRect)

            // 图片水印（如果有）
            if let sticker = config.stickerImage {
                let baseLength = min(canvasWidth, canvasHeight)
                let stickerSize = stickerSize(for: sticker,
                                              baseLength: baseLength,
                                              scale: CGFloat(config.stickerScale))

                let origin = CGPoint(
                    x: canvasWidth * config.stickerX - stickerSize.width / 2,
                    y: canvasHeight * config.stickerY - stickerSize.height / 2
                )
                let rect = CGRect(origin: origin, size: stickerSize)
                sticker.draw(in: rect,
                             blendMode: .normal,
                             alpha: CGFloat(config.stickerOpacity))
            }

            // 文字水印
            if !config.watermarkText.isEmpty {
                let text = config.watermarkText as NSString
                let fontSize = min(canvasWidth, canvasHeight) * CGFloat(config.watermarkScale)

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

                let centerX = canvasWidth * config.watermarkX
                let centerY = canvasHeight * config.watermarkY
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
