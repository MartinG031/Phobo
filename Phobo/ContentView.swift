// ContentView.swift
// 图片加边框小工具主界面
// 功能：选择照片 → 预览加“背景边框”效果 → 自定义边框宽度 / 画布比例 → 保存到相册

import SwiftUI
import PhotosUI
import Photos
import UIKit
import CoreMotion
import Combine

/// 编辑工具类型：边框 / 文字水印 / 图片水印（可以叠加使用）
enum EditingTool {
    case border
    case watermark      // 文字水印
    case imageWatermark // 图片水印
}


struct ContentView: View {
    // 设备姿态管理，用于驱动 Liquid Glass 高光方向（仿 Apple 官方动效）
    @StateObject private var motionManager = MotionManager()
    // 通用外边距：控制参数区域与屏幕边缘的间距（水平和底部共用）
    private let panelOuterPadding: CGFloat = 16
    // 参数大面板最小高度（整体比原来高约一行文字，用于所有功能面板统一增高）
    private let controlPanelMinHeight: CGFloat = 266
    
    // MARK: - 选择图片 / 原图数据
    @State private var showingImagePicker = false          // 是否显示系统图片选择器
    @State private var inputImage: UIImage?                // 当前选中的原始图片（单张）
    
    // MARK: - 画布外观配置
    // 背景色 = “边框颜色”（即最终导出的背景纯色）
    @State private var backgroundColor: Color = .white     // 默认白色背景
    
    // 画布比例（宽 : 高），默认 1 : 1（使用 @AppStorage 持久化，跨启动保留上次设置）
    @AppStorage("customAspectWidth") private var customAspectWidth: Double = 1
    @AppStorage("customAspectHeight") private var customAspectHeight: Double = 1
    
    // 边框宽度（以图片最长边的百分比表示，1% - 100%）。
    // 注意：这里的“边框”本质是背景画布与原图之间的留白，最窄处 = longestSide * 百分比。
    @State private var borderPercent: Double = 1
    
    // 当前编辑工具（边框 / 水印）
    @State private var selectedTool: EditingTool = .border
    
    // 文字水印配置
    @State private var watermarkText: String = ""
    @State private var watermarkScale: Double = 0.05    // 相对于画布最小边的比例
    @State private var watermarkColor: Color = .black   // 水印文字颜色（默认黑色）
    @State private var watermarkFontName: String = "System"   // "System" 表示系统默认字体
    // 水印在画布上的归一化位置（0~1，表示相对于画布宽高的中心点坐标）
    @State private var watermarkX: CGFloat = 0.85
    @State private var watermarkY: CGFloat = 0.9
    // 水平 / 垂直居中辅助线显示开关（用于拖动时的吸附效果提示）
    @State private var showVerticalGuide: Bool = false
    @State private var showHorizontalGuide: Bool = false
    // 拖动状态和起点（文字水印）
    @State private var isDraggingTextWatermark: Bool = false
    @State private var textDragStartX: CGFloat = 0.5
    @State private var textDragStartY: CGFloat = 0.5
    // 拖动状态和起点（图片水印）
    @State private var isDraggingImageWatermark: Bool = false
    @State private var imageDragStartX: CGFloat = 0.5
    @State private var imageDragStartY: CGFloat = 0.5

    // 图片水印配置
    @State private var imageWatermarks: [UIImage] = []        // 已添加的图片水印列表
    @State private var selectedImageWatermarkIndex: Int? = nil // 当前选中的图片水印下标
    @State private var showingImageWatermarkPicker: Bool = false
    @State private var watermarkPickerImage: UIImage? = nil
    @State private var imageWatermarkScale: Double = 0.22     // 相对于画布短边的比例
    @State private var imageWatermarkOpacity: Double = 1.0        // 不透明度（1 = 完全不透明）
    @State private var imageWatermarkX: CGFloat = 0.85        // 默认靠右下
    @State private var imageWatermarkY: CGFloat = 0.85

    // 字体选择器弹层
    @State private var showingFontPicker: Bool = false
    
    // 水印文字输入焦点，用于控制键盘收起
    @FocusState private var isWatermarkFieldFocused: Bool
    // 记录在弹出图片选择器之前是否处于文字水印编辑状态
    @State private var wasWatermarkEditingBeforeImagePicker: Bool = false

    // 根据设备姿态计算胶囊高光的起止方向（0~1 范围）
    private var capsuleHighlightStart: UnitPoint {
        let d = motionManager.lightDirection
        return UnitPoint(x: d.x, y: d.y)
    }
    
    private var capsuleHighlightEnd: UnitPoint {
        let d = motionManager.lightDirection
        return UnitPoint(x: 1 - d.x, y: 1 - d.y)
    }
    
    // MARK: - 弹窗 / 弹层状态
    // 保存结果弹窗状态
    @State private var showSaveSuccessAlert = false
    @State private var showSaveErrorAlert = false
    @State private var saveErrorMessage: String = ""
    
    // 分享相关状态（使用 item 驱动的方式，避免空白 sheet）
    @State private var sharePayload: SharePayload?
    
    // 是否显示“更多比例”编辑面板（单独弹出的底部浮层）
    @State private var showingAspectEditor = false
    
    // MARK: - 预览区域封装
    private var previewArea: some View {
        Group {
            if let image = inputImage {
                // 已选择图片时：预览仅展示效果，不再承担交互
                previewForImage(image)
            } else {
                // 未选择图片时：展示占位预览，由上方“选择”按钮触发选择
                placeholderPreview
            }
        }
    }
    
    private var placeholderPreview: some View {
        ZStack {
            Color(UIColor.systemGray4)
            VStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40))
                Text("尚未选择图片")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func previewForImage(_ image: UIImage) -> some View {
        GeometryReader { geo in
            let layout = computePreviewLayout(for: image, in: geo.size)

            // 使用闭包惰性初始化的方式计算字体和文字尺寸，
            // 在没有文字水印时直接返回默认值，避免多余计算。
            let watermarkFontSize = min(layout.canvasSize.width,
                                        layout.canvasSize.height) * CGFloat(watermarkScale)

            let watermarkSwiftUIFont: Font = {
                guard !watermarkText.isEmpty else {
                    return .body
                }
                if watermarkFontName == "System" {
                    return .system(size: watermarkFontSize, weight: .semibold)
                } else {
                    return .custom(watermarkFontName, size: watermarkFontSize)
                }
            }()

            let measuredTextSize: CGSize = {
                guard !watermarkText.isEmpty else { return .zero }

                let uiFont: UIFont = {
                    if watermarkFontName == "System" {
                        return .systemFont(ofSize: watermarkFontSize, weight: .semibold)
                    } else {
                        return UIFont(name: watermarkFontName, size: watermarkFontSize)
                            ?? .systemFont(ofSize: watermarkFontSize, weight: .semibold)
                    }
                }()

                let text = watermarkText as NSString
                // 限制测量宽度，模拟多行文本在预览中的换行效果
                let maxWidth = max(layout.canvasSize.width * 0.8, 1)
                let bounding = text.boundingRect(
                    with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: uiFont],
                    context: nil
                )
                return bounding.integral.size
            }()

            // 计算底部边框区域的垂直中心（归一化坐标，nil 表示无明显边框时不吸附）
            let bottomBorderCenterY: CGFloat? = {
                let canvasHeight = layout.canvasSize.height
                let imageHeight = layout.imageSize.height
                guard canvasHeight > 0 else { return nil }
                let borderHeight = canvasHeight - imageHeight
                // 当上下边框很窄时就不做特别吸附，避免无意义的“抖动”
                guard borderHeight / canvasHeight > 0.05 else { return nil }
                let imageBottom = (canvasHeight + imageHeight) / 2
                let bottomCenter = (imageBottom + canvasHeight) / 2
                return bottomCenter / canvasHeight
            }()

            // 左右边框区域的水平中心（归一化 X），nil 表示画布基本无左右边框
            let leftBorderCenterX: CGFloat? = {
                let canvasWidth = layout.canvasSize.width
                let imageWidth = layout.imageSize.width
                guard canvasWidth > 0 else { return nil }
                let totalBorderWidth = canvasWidth - imageWidth
                guard totalBorderWidth > 0 else { return nil }
                let sideBorderWidth = totalBorderWidth / 2
                // 当左右边框过窄时不吸附，避免无意义的抖动
                guard sideBorderWidth / canvasWidth > 0.05 else { return nil }
                let center = sideBorderWidth / 2
                return center / canvasWidth
            }()

            let rightBorderCenterX: CGFloat? = {
                guard let left = leftBorderCenterX else { return nil }
                return 1 - left
            }()

            ZStack {
                // 背景纯色区域（画布）
                backgroundColor

                // 原图按几何缩放后居中放置（不裁剪）
                Image(uiImage: image)
                    .resizable()
                    .frame(width: layout.imageSize.width,
                           height: layout.imageSize.height)

                // 图片水印预览，可拖动
                if let index = selectedImageWatermarkIndex,
                   imageWatermarks.indices.contains(index) {
                    let sticker = imageWatermarks[index]
                    let baseLength = min(layout.canvasSize.width, layout.canvasSize.height)
                    let stickerSize = stickerSize(
                        for: sticker,
                        baseLength: baseLength,
                        scale: CGFloat(imageWatermarkScale)
                    )

                    Image(uiImage: sticker)
                        .resizable()
                        .frame(width: stickerSize.width,
                               height: stickerSize.height)
                        .opacity(imageWatermarkOpacity)
                        .position(
                            x: layout.canvasSize.width * imageWatermarkX,
                            y: layout.canvasSize.height * imageWatermarkY
                        )
                        .transaction { $0.animation = nil }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    // 首次记录拖动起点（归一化坐标），后续都基于 translation 做增量更新
                                    if !isDraggingImageWatermark {
                                        isDraggingImageWatermark = true
                                        imageDragStartX = imageWatermarkX
                                        imageDragStartY = imageWatermarkY
                                    }

                                    let canvasWidth = layout.canvasSize.width
                                    let canvasHeight = layout.canvasSize.height

                                    // 当前图像一半宽高换算成归一化坐标，用于保证整张贴纸始终在画布内
                                    let halfWidthNorm = (stickerSize.width / 2) / canvasWidth
                                    let halfHeightNorm = (stickerSize.height / 2) / canvasHeight

                                    // 允许的最小 / 最大中心位置（保证整张图都在画布内）
                                    let minX = halfWidthNorm
                                    let maxX = 1 - halfWidthNorm
                                    let minY = halfHeightNorm
                                    let maxY = 1 - halfHeightNorm

                                    // 将手指的 translation 转换成归一化位移（相对于画布宽高）
                                    let dx = value.translation.width / canvasWidth
                                    let dy = value.translation.height / canvasHeight

                                    var x = imageDragStartX + dx
                                    var y = imageDragStartY + dy

                                    // 先做基本的边界约束，保证图片不出画布
                                    x = min(max(x, minX), maxX)
                                    y = min(max(y, minY), maxY)

                                    let snapThreshold: CGFloat = 0.03
                                    let edgeSnapThreshold: CGFloat = 0.02

                                    // 默认关闭中心辅助线
                                    showVerticalGuide = false
                                    showHorizontalGuide = false

                                    // 中心吸附
                                    if abs(x - 0.5) < snapThreshold {
                                        x = 0.5
                                        showVerticalGuide = true
                                    }
                                    if abs(y - 0.5) < snapThreshold {
                                        y = 0.5
                                        showHorizontalGuide = true
                                    }

                                    // 底部边框中心吸附（仅当存在明显的上下边框时）
                                    if let borderCenterY = bottomBorderCenterY,
                                       abs(y - borderCenterY) < snapThreshold {
                                        y = borderCenterY
                                    }

                                    // 左右边框中心吸附（仅当存在明显的左右边框时）
                                    if let leftCenterX = leftBorderCenterX,
                                       abs(x - leftCenterX) < snapThreshold {
                                        x = leftCenterX
                                    } else if let rightCenterX = rightBorderCenterX,
                                              abs(x - rightCenterX) < snapThreshold {
                                        x = rightCenterX
                                    }

                                    // 边缘吸附：让图片边缘与画布边缘刚好重合
                                    let leftCenter = minX     // 左边缘对齐时的中心 X
                                    let rightCenter = maxX    // 右边缘对齐时的中心 X
                                    let topCenter = minY      // 上边缘对齐时的中心 Y
                                    let bottomCenter = maxY   // 下边缘对齐时的中心 Y

                                    if abs(x - leftCenter) < snapThreshold {
                                        x = leftCenter
                                    } else if abs(x - rightCenter) < snapThreshold {
                                        x = rightCenter
                                    }

                                    // 垂直方向同理（顶部 / 底部），用更小的 edgeSnapThreshold
                                    if abs(y - topCenter) < edgeSnapThreshold {
                                        y = topCenter
                                    } else if abs(y - bottomCenter) < edgeSnapThreshold {
                                        y = bottomCenter
                                    }

                                    imageWatermarkX = x
                                    imageWatermarkY = y
                                }
                                .onEnded { _ in
                                    showVerticalGuide = false
                                    showHorizontalGuide = false
                                    isDraggingImageWatermark = false
                                }
                        )
                }

                // 文字水印预览：可在画布上自由拖动，支持按文字宽度自适应的边缘吸附
                if !watermarkText.isEmpty {
                    Text(watermarkText)
                        .font(watermarkSwiftUIFont)
                        .foregroundColor(watermarkColor)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: layout.canvasSize.width * 0.8)
                        .shadow(color: Color.black.opacity(0.4),
                                radius: 3, x: 1, y: 1)
                        .transaction { $0.animation = nil }
                        .position(
                            x: layout.canvasSize.width * watermarkX,
                            y: layout.canvasSize.height * watermarkY
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    // 首次记录拖动起点（归一化坐标），后续都基于 translation 做增量更新
                                    if !isDraggingTextWatermark {
                                        isDraggingTextWatermark = true
                                        textDragStartX = watermarkX
                                        textDragStartY = watermarkY
                                    }

                                    let canvasWidth = layout.canvasSize.width
                                    let canvasHeight = layout.canvasSize.height

                                    // 使用预先测量好的文字尺寸（本次 body 计算内的常量）
                                    var halfWidthNorm = (measuredTextSize.width / max(canvasWidth, 1)) / 2
                                    var halfHeightNorm = (measuredTextSize.height / max(canvasHeight, 1)) / 2

                                    // 避免极端情况下超出范围
                                    halfWidthNorm = min(max(halfWidthNorm, 0.02), 0.48)
                                    halfHeightNorm = min(max(halfHeightNorm, 0.02), 0.48)

                                    // 将手指的 translation 转换成归一化位移（相对于画布宽高）
                                    let dx = value.translation.width / canvasWidth
                                    let dy = value.translation.height / canvasHeight

                                    var x = textDragStartX + dx
                                    var y = textDragStartY + dy

                                    // 保证整段文字始终在画布内部
                                    x = min(max(x, halfWidthNorm), 1 - halfWidthNorm)
                                    y = min(max(y, halfHeightNorm), 1 - halfHeightNorm)

                                    let snapThreshold: CGFloat = 0.03
                                    let edgeSnapThreshold: CGFloat = 0.02

                                    // 默认关闭辅助线
                                    showVerticalGuide = false
                                    showHorizontalGuide = false

                                    // 中心吸附：靠近 0.5 时自动吸附并显示辅助线
                                    if abs(x - 0.5) < snapThreshold {
                                        x = 0.5
                                        showVerticalGuide = true
                                    }
                                    if abs(y - 0.5) < snapThreshold {
                                        y = 0.5
                                        showHorizontalGuide = true
                                    }

                                    // 底部边框中心吸附（仅当存在明显的上下边框时）
                                    if let borderCenterY = bottomBorderCenterY,
                                       abs(y - borderCenterY) < snapThreshold {
                                        y = borderCenterY
                                    }

                                    // 左右边框中心吸附（仅当存在明显的左右边框时）
                                    if let leftCenterX = leftBorderCenterX,
                                       abs(x - leftCenterX) < snapThreshold {
                                        x = leftCenterX
                                    } else if let rightCenterX = rightBorderCenterX,
                                              abs(x - rightCenterX) < snapThreshold {
                                        x = rightCenterX
                                    }

                                    // 水平边缘吸附：左 / 右边缘根据文字宽度计算中心位置
                                    let leftCenter = halfWidthNorm
                                    let rightCenter = 1 - halfWidthNorm
                                    if abs(x - leftCenter) < snapThreshold {
                                        x = leftCenter
                                    } else if abs(x - rightCenter) < snapThreshold {
                                        x = rightCenter
                                    }

                                    // 垂直方向同理（顶部 / 底部），用更小的 edgeSnapThreshold
                                    let topCenter = halfHeightNorm
                                    let bottomCenter = 1 - halfHeightNorm
                                    if abs(y - topCenter) < edgeSnapThreshold {
                                        y = topCenter
                                    } else if abs(y - bottomCenter) < edgeSnapThreshold {
                                        y = bottomCenter
                                    }

                                    watermarkX = x
                                    watermarkY = y
                                }
                                .onEnded { _ in
                                    // 结束拖动后隐藏辅助线并重置拖动状态
                                    showVerticalGuide = false
                                    showHorizontalGuide = false
                                    isDraggingTextWatermark = false
                                }
                        )
                }

                // 中心辅助线（仅在吸附状态下显示，画在最上层）
                if showVerticalGuide {
                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 1)
                        .frame(height: layout.canvasSize.height)
                }

                if showHorizontalGuide {
                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(height: 1)
                        .frame(width: layout.canvasSize.width)
                }
            }
            .frame(width: layout.canvasSize.width,
                   height: layout.canvasSize.height)
            .position(x: geo.size.width / 2,
                      y: geo.size.height / 2)
        }
    }
    
    
    
    /// 预览布局计算：根据原图和可用区域，计算预览画布尺寸和图片绘制尺寸
    /// 根据原始图片和目标基准长度计算贴纸尺寸，保持原始宽高比
    private func stickerSize(for sticker: UIImage,
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
    private func computePreviewLayout(for image: UIImage,
                                      in availableSize: CGSize) -> (canvasSize: CGSize, imageSize: CGSize) {
        // 1. 读取原图尺寸 & 计算目标边框宽度
        let origSize = image.size
        let origWidth = origSize.width
        let origHeight = origSize.height
        let longestOrig = max(origWidth, origHeight)
        
        // 与导出相同的边框计算：最窄边 = 图片最长边的百分比
        let clampedPercent = max(min(borderPercent, 100), 1)
        let borderWidth = longestOrig * CGFloat(clampedPercent / 100.0)
        
        // 2. 根据当前成品比例模式，计算目标画布宽高比
        let targetAspect: CGFloat = canvasAspect(for: image) // Wc / Hc
        
        // 3. 在“理论尺寸”下计算画布大小：保证某一方向留白 = borderWidth
        let baseCanvasSize: CGSize = {
            if origWidth + 2 * borderWidth >= targetAspect * (origHeight + 2 * borderWidth) {
                // 水平方向是最窄边
                let canvasWidth = origWidth + 2 * borderWidth
                let canvasHeight = canvasWidth / targetAspect
                return CGSize(width: canvasWidth, height: canvasHeight)
            } else {
                // 垂直方向是最窄边
                let canvasHeight = origHeight + 2 * borderWidth
                let canvasWidth = targetAspect * canvasHeight
                return CGSize(width: canvasWidth, height: canvasHeight)
            }
        }()
        
        let canvasWidth = baseCanvasSize.width
        let canvasHeight = baseCanvasSize.height
        
        // 4. 计算在理论画布中原图应有的尺寸（只缩小，不放大）
        let scaleToFit = min(canvasWidth / origWidth, canvasHeight / origHeight)
        let imageScale = min(scaleToFit, 1.0)
        
        let drawWidth = origWidth * imageScale
        let drawHeight = origHeight * imageScale
        
        // 5. 将理论画布整体缩放以适配预览区域大小（预览 = 导出整体等比缩小）
        let previewScale = min(availableSize.width / canvasWidth,
                               availableSize.height / canvasHeight)
        
        let previewCanvasWidth = canvasWidth * previewScale
        let previewCanvasHeight = canvasHeight * previewScale
        let previewImageWidth = drawWidth * previewScale
        let previewImageHeight = drawHeight * previewScale
        
        let canvasSize = CGSize(width: previewCanvasWidth, height: previewCanvasHeight)
        let imageSize = CGSize(width: previewImageWidth, height: previewImageHeight)
        
        return (canvasSize, imageSize)
    }
    
    // MARK: - 控制区域视图（参数卡片）

    /// 参数区域：根据不同工具显示不同参数面板，外部是矩形 Liquid Glass 大面板（高度随内容自适应，内容超出时允许滚动）
    @ViewBuilder
    private func controlPanel(for tool: EditingTool) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                switch tool {
                case .border:
                    BorderControlsPanel(
                        borderPercent: $borderPercent,
                        backgroundColor: $backgroundColor,
                        customAspectWidth: $customAspectWidth,
                        customAspectHeight: $customAspectHeight,
                        capsuleHighlightStart: capsuleHighlightStart,
                        capsuleHighlightEnd: capsuleHighlightEnd,
                        onTapAspectEditor: { showingAspectEditor = true },
                        onRotateAspect: {
                            let tmp = customAspectWidth
                            customAspectWidth = customAspectHeight
                            customAspectHeight = tmp
                        },
                        onResetAspect: {
                            customAspectWidth = 1
                            customAspectHeight = 1
                        }
                    )
                case .watermark:
                    WatermarkControlsPanel(
                        watermarkScale: $watermarkScale,
                        watermarkFontName: $watermarkFontName,
                        watermarkColor: $watermarkColor,
                        watermarkText: $watermarkText,
                        watermarkFocus: $isWatermarkFieldFocused,
                        capsuleHighlightStart: capsuleHighlightStart,
                        capsuleHighlightEnd: capsuleHighlightEnd,
                        onTapFontPicker: { showingFontPicker = true }
                    )
                case .imageWatermark:
                    ImageWatermarkControlsPanel(
                        images: imageWatermarks,
                        selectedIndex: $selectedImageWatermarkIndex,
                        scale: $imageWatermarkScale,
                        opacity: $imageWatermarkOpacity,
                        onAdd: { showingImageWatermarkPicker = true },
                        onDelete: { index in
                            guard imageWatermarks.indices.contains(index) else { return }
                            imageWatermarks.remove(at: index)
                            if let selected = selectedImageWatermarkIndex {
                                if selected == index {
                                    selectedImageWatermarkIndex = nil
                                } else if selected > index {
                                    selectedImageWatermarkIndex = selected - 1
                                }
                            }
                            savePersistedImageWatermarks()
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity,
               minHeight: controlPanelMinHeight,
               maxHeight: controlPanelMinHeight,
               alignment: .top)
        .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, panelOuterPadding)
    }
    

    // MARK: - 主界面布局
    // 结构：NavigationStack + TabView（系统 Tab Bar）+ 每个 Tab 内部包含预览区域和参数卡片
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTool) {
                mainPage(for: .border)
                    .tag(EditingTool.border)
                    .tabItem {
                        Label("边框", systemImage: "square.on.square")
                    }

                mainPage(for: .watermark)
                    .tag(EditingTool.watermark)
                    .tabItem {
                        Label("文字水印", systemImage: "textformat")
                    }

                mainPage(for: .imageWatermark)
                    .tag(EditingTool.imageWatermark)
                    .tabItem {
                        Label("图片水印", systemImage: "photo.on.rectangle")
                    }
            }
            .toolbar {
                // 左侧：选择，使用导航条文本按钮样式（Liquid Glass-text）
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("选择") {
                        // 如果当前在文字水印工具并且正在编辑，则记录状态并先收起键盘
                        if selectedTool == .watermark && isWatermarkFieldFocused {
                            wasWatermarkEditingBeforeImagePicker = true
                            isWatermarkFieldFocused = false
                        } else {
                            wasWatermarkEditingBeforeImagePicker = false
                        }
                        showingImagePicker = true
                    }
                }

                // 右侧：分享 + 保存，使用系统导航条文本按钮样式
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button("分享") {
                            shareImageViaActivityView()
                        }
                        .disabled(inputImage == nil)

                        Button("保存") {
                            saveImageWithBackground()
                        }
                        .disabled(inputImage == nil)
                    }
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $inputImage)
        }
        .sheet(isPresented: $showingImageWatermarkPicker) {
            ImagePicker(image: $watermarkPickerImage)
        }
        .sheet(isPresented: $showingAspectEditor) {
            CustomAspectRatioView(
                width: $customAspectWidth,
                height: $customAspectHeight
            )
        }
        .sheet(isPresented: $showingFontPicker) {
            SystemFontPickerView(selectedFontName: $watermarkFontName)
        }
        .sheet(item: $sharePayload) { payload in
            ActivityView(activityItems: [payload.image])
        }
        .onChange(of: watermarkPickerImage) { _, newValue in
            if let img = newValue {
                imageWatermarks.append(img)
                selectedImageWatermarkIndex = imageWatermarks.indices.last
                watermarkPickerImage = nil
                // 每次新增图片水印后立即持久化到磁盘
                savePersistedImageWatermarks()
            }
        }
        .onChange(of: selectedImageWatermarkIndex) { _, _ in
            saveSelectedImageWatermarkIndex()
        }
        // 监听图片选择器的显示/隐藏，选完图后自动恢复文字编辑状态（如果之前正在编辑）
        .onChange(of: showingImagePicker) { oldValue, newValue in
            // 仅在图片选择器从显示变为隐藏时处理
            if oldValue == true && newValue == false {
                if wasWatermarkEditingBeforeImagePicker {
                    wasWatermarkEditingBeforeImagePicker = false
                    // 仍然停留在文字水印工具时才恢复焦点
                    if selectedTool == .watermark {
                        // 延迟到下一轮 RunLoop，避免和收键盘动画冲突
                        DispatchQueue.main.async {
                            isWatermarkFieldFocused = true
                        }
                    }
                }
            }
        }
        .alert("保存成功", isPresented: $showSaveSuccessAlert) {
            Button("好") { }
        } message: {
            Text("已保存到系统相册。")
        }
        .alert("保存失败", isPresented: $showSaveErrorAlert) {
            Button("好") { }
        } message: {
            Text(saveErrorMessage)
        }
        .onAppear {
            // 启动时从磁盘加载上一次保存的图片水印
            loadPersistedImageWatermarks()
        }
    }

    // MARK: - 单个 Tab 页面布局（共享预览区域，不同参数面板）
    @ViewBuilder
    private func mainPage(for tool: EditingTool) -> some View {
        GeometryReader { proxy in
            let previewSide = proxy.size.width

            ZStack(alignment: .bottom) {
                Color(UIColor.systemGray4)
                    .ignoresSafeArea()

                // 预览区域：固定在上方，底部空间由参数面板和系统键盘自动协调
                VStack(spacing: 12) {
                    previewArea
                        .frame(width: previewSide, height: previewSide)
                        .clipped()
                        .padding(.top, 16)
                        .padding(.bottom, 9)

                    Spacer()
                }

                // 底部参数区域：浮动在底部，高度固定，系统负责键盘避让
                controlPanel(for: tool)
                    .padding(.bottom, panelOuterPadding)
            }
        }
    }
    
    // MARK: - 计算成品画布宽高比（背景+原图）
    private func canvasAspect(for image: UIImage) -> CGFloat {
        // 统一使用当前画布比例（宽 : 高），默认 1 : 1
        let w = max(customAspectWidth, 0.01)
        let h = max(customAspectHeight, 0.01)
        return CGFloat(w / h)
    }
    
    /// 当前选中的图片水印（如果有）
    private var selectedStickerImage: UIImage? {
        if let index = selectedImageWatermarkIndex,
           imageWatermarks.indices.contains(index) {
            return imageWatermarks[index]
        }
        return nil
    }

    // MARK: - 保存：生成纯色背景 + 不裁剪的原图（单张）
    private func saveImageWithBackground() {
        guard let originalImage = inputImage else { return }

        let config = makeRenderConfig(for: originalImage)
        let renderedImage = RenderService.render(config: config)

        SaveService.saveToPhotos(image: renderedImage) { result in
            switch result {
            case .success:
                showSaveSuccessAlert = true
            case .failure(let error):
                saveErrorMessage = error.localizedDescription
                showSaveErrorAlert = true
            }
        }
    }

    // MARK: - 分享：通过系统 Activity View 分享当前成品图
    private func shareImageViaActivityView() {
        guard let originalImage = inputImage else { return }

        let renderedImage = RenderService.render(config: makeRenderConfig(for: originalImage))
        sharePayload = SharePayload(image: renderedImage)
    }

    /// 组装保存和分享共用的渲染配置，避免两个导出入口发生参数漂移。
    private func makeRenderConfig(for originalImage: UIImage) -> RenderConfig {
        let config = RenderConfig(
            originalImage: originalImage,
            backgroundColor: UIColor(backgroundColor),
            borderPercent: borderPercent,
            aspectWidth: customAspectWidth,
            aspectHeight: customAspectHeight,
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

        return config
    }
// MARK: - 分享负载模型（用于 sheet(item:)）
struct SharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}
}

// MARK: - 图片水印持久化（跨启动保存）
extension ContentView {
    /// 从磁盘加载已保存的图片水印列表，在 App 启动或视图出现时调用
    private func loadPersistedImageWatermarks() {
        ImageWatermarkStore.load { loaded, selectedIndex in
            self.imageWatermarks = loaded
            self.selectedImageWatermarkIndex = selectedIndex
        }
    }

    /// 将当前图片水印数组保存到磁盘，并记录当前选中的索引
    private func savePersistedImageWatermarks() {
        ImageWatermarkStore.save(
            images: imageWatermarks,
            selectedIndex: selectedImageWatermarkIndex
        )
    }

    private func saveSelectedImageWatermarkIndex() {
        ImageWatermarkStore.persistSelectedIndex(
            selectedImageWatermarkIndex,
            imageCount: imageWatermarks.count
        )
    }
}

// MARK: - 比例显示组件（让冒号在视觉上居中）

/// 用于显示类似 "1 : 1"、"3 : 2" 的比例文字，通过对冒号做轻微 baselineOffset，让冒号在数字中间更居中。
struct RatioLabel: View {
    let width: Int
    let height: Int

    var body: some View {
        HStack(spacing: 2) {
            Text("\(width)")
            Text(":")
                .baselineOffset(2)   // 可以按视觉效果微调 0~2
            Text("\(height)")
        }
        .font(.system(.body, design: .rounded).monospacedDigit())
    }
}

// MARK: - 系统字体选择视图（从系统字库中选择水印字体）

    struct SystemFontPickerView: View {
        @Binding var selectedFontName: String
        @Environment(\.dismiss) private var dismiss

        // 最近使用字体存储（用一个简单的分隔字符串存储在 UserDefaults 中）
        @AppStorage("recentWatermarkFonts") private var recentFontsRaw: String = ""

        // 使用系统字库列出所有可用字体名称
        private let fontNames: [String] = {
            var names: [String] = []
            for family in UIFont.familyNames.sorted() {
                let fonts = UIFont.fontNames(forFamilyName: family).sorted()
                names.append(contentsOf: fonts)
            }
            return names
        }()

        /// 解析后的最近使用字体列表（只保留当前系统仍然可用的字体）
        private var recentFonts: [String] {
            recentFontsRaw
                .split(separator: "|")
                .map(String.init)
                .filter { fontNames.contains($0) }
        }

        /// 将选中的字体加入“最近使用”列表（最多保留 5 个，最新在前）
        private func addRecentFont(_ name: String) {
            guard fontNames.contains(name) else { return }
            var current = recentFonts
            // 去重：先移除，再插入到最前
            current.removeAll { $0 == name }
            current.insert(name, at: 0)
            // 限制最多 5 个
            if current.count > 5 {
                current = Array(current.prefix(5))
            }
            recentFontsRaw = current.joined(separator: "|")
        }

        var body: some View {
            NavigationView {
                List {
                    // 系统默认字体
                    Section {
                        Button {
                            selectedFontName = "System"
                            dismiss()
                        } label: {
                            HStack {
                                Text("系统默认")
                                Spacer()
                                Text("System")
                                    .foregroundColor(.secondary)
                                    .font(.footnote)
                            }
                        }
                    }

                    // 最近使用字体（如果有）
                    if !recentFonts.isEmpty {
                        Section(header: Text("最近使用")) {
                            ForEach(recentFonts, id: \.self) { name in
                                Button {
                                    selectedFontName = name
                                    addRecentFont(name)
                                    dismiss()
                                } label: {
                                    HStack {
                                        Text(name)
                                            .font(.custom(name, size: 18))
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }

                    // 全部系统字体列表
                    Section(header: Text("系统字体")) {
                        ForEach(fontNames, id: \.self) { name in
                            Button {
                                selectedFontName = name
                                addRecentFont(name)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(name)
                                        .font(.custom(name, size: 18))
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .navigationTitle("选择字体")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    

// MARK: - Liquid Glass 通用背景（优先使用系统 glassEffect）

extension View {
    /// 为任意视图添加 Liquid Glass 风格背景：
    /// 仅针对 iOS 26 及以上，直接使用系统提供的 `glassEffect`。
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat = 10) -> some View {
        self
            .padding(0)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.clear)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .glassEffect()
    }
}


// MARK: - 设备姿态管理，用于 Liquid Glass 高光方向（仿 Apple 官方动态高光）

final class MotionManager: ObservableObject {
    @Published var lightDirection: CGPoint = CGPoint(x: 0.4, y: 0.2)

    private let manager = CMMotionManager()
    private let queue = OperationQueue()
    
    init() {
        // 约 10fps 更新一次，进一步降低刷新频率，减少对 SwiftUI 重绘的压力
        manager.deviceMotionUpdateInterval = 1.0 / 10.0
        queue.qualityOfService = .userInteractive

        if manager.isDeviceMotionAvailable {
            manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
                guard let self = self,
                      let attitude = motion?.attitude else { return }

                // 将 roll / pitch 映射到 -1...1 范围
                let rollNorm = max(min(attitude.roll / (.pi / 2), 1), -1)
                let pitchNorm = max(min(attitude.pitch / (.pi / 2), 1), -1)

                // 计算新的高光方向（0~1）
                let x = 0.5 + CGFloat(rollNorm) * 0.35
                let y = 0.3 - CGFloat(pitchNorm) * 0.25

                let clampedX = min(max(x, 0.0), 1.0)
                let clampedY = min(max(y, 0.0), 1.0)
                let newDirection = CGPoint(x: clampedX, y: clampedY)

                // 简单阈值过滤：只有变化明显时才触发 UI 更新，减少 SwiftUI 重绘
                let dx = newDirection.x - self.lightDirection.x
                let dy = newDirection.y - self.lightDirection.y
                let distanceSquared = dx * dx + dy * dy

                // 阈值越大，高光移动越“稳”，UI 更新越少；这里适当调大，进一步减少不必要的 UI 更新
                if distanceSquared < 0.006 {
                    return
                }

                DispatchQueue.main.async {
                    self.lightDirection = newDirection
                }
            }
        }
    }

    deinit {
        manager.stopDeviceMotionUpdates()
    }
}


/// 自定义画幅比例界面（标准表单样式）
struct CustomAspectRatioView: View {
    @Binding var width: Double
    @Binding var height: Double

    @Environment(\.dismiss) private var dismiss

    @State private var tempWidth: String = ""
    @State private var tempHeight: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text("请输入大于 0 的整数。").font(.footnote).foregroundColor(.secondary)) {
                    HStack {
                        Text("宽")
                        Spacer()
                        TextField("宽", text: $tempWidth)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.leading)
                    }

                    HStack {
                        Text("高")
                        Spacer()
                        TextField("高", text: $tempHeight)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .navigationTitle("自定义比例")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        commitValues()
                    }
                }
            }
            .onAppear {
                tempWidth = String(Int(max(width, 1)))
                tempHeight = String(Int(max(height, 1)))
            }
        }
    }

    /// 校验并回写绑定值
    private func commitValues() {
        let w = max(Double(tempWidth) ?? width, 1)
        let h = max(Double(tempHeight) ?? height, 1)
        width = w
        height = h
        dismiss()
    }
}

// MARK: - 边框参数面板（子 View）

private struct BorderControlsPanel: View {
    @Binding var borderPercent: Double
    @Binding var backgroundColor: Color
    @Binding var customAspectWidth: Double
    @Binding var customAspectHeight: Double
    
    var capsuleHighlightStart: UnitPoint
    var capsuleHighlightEnd: UnitPoint
    
    var onTapAspectEditor: () -> Void
    var onRotateAspect: () -> Void
    var onResetAspect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 第一行：边框宽度（标题 + 当前值）+ 下一行滑块
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("边框宽度")
                    Spacer()
                    Text("\(Int(borderPercent))%")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $borderPercent, in: 1...100)
            }
            
            Divider()
            
            // 第二行：背景颜色（带标签 + 当前颜色预览 + HEX 文本 + 系统 ColorPicker）
            HStack(spacing: 8) {
                Text("背景颜色：")

                // 当前颜色小预览 chip
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(backgroundColor)
                    .frame(width: 32, height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 0.6)
                    )
                
                // 当前颜色的 HEX 表示，字体风格与“边框宽度：1%”一致
                Text(hexString(for: backgroundColor))

                Spacer()

                ColorPicker("", selection: $backgroundColor, supportsOpacity: true)
                    .labelsHidden()
            }
            
            Divider()
            
            // 第三块：画幅比例显示行 + 右侧三个胶囊按钮（左侧显示当前比例，右侧是控制按钮）
            HStack(spacing: 4) {
                // 左侧：画幅比例文字 + 当前比例（格式与“边框宽度”一致）
                Text("画幅比例：")
                RatioLabel(width: Int(customAspectWidth), height: Int(customAspectHeight))
                
                Spacer()
                
                // 右侧：更多比例 / 旋转 / 复位 三个胶囊按钮
                Menu {
                    Button("2 : 3") {
                        customAspectWidth = 2
                        customAspectHeight = 3
                    }
                    Button("3 : 5") {
                        customAspectWidth = 3
                        customAspectHeight = 5
                    }
                    Button("3 : 4") {
                        customAspectWidth = 3
                        customAspectHeight = 4
                    }
                    Button("5 : 7") {
                        customAspectWidth = 5
                        customAspectHeight = 7
                    }
                    Button("4 : 5") {
                        customAspectWidth = 4
                        customAspectHeight = 5
                    }
                    Button("16 : 9") {
                        customAspectWidth = 16
                        customAspectHeight = 9
                    }
                    
                    Divider()
                    Button("自定义") {
                        onTapAspectEditor()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("更多比例")
                        Image(systemName: "chevron.down")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassEffect(in: Capsule(style: .continuous))
                }
                .menuStyle(.borderlessButton)
                
                Button {
                    onRotateAspect()
                } label: {
                    Text("旋转")
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .glassEffect(in: Capsule(style: .continuous))
                
                Button {
                    onResetAspect()
                } label: {
                    Text("1 : 1")
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .glassEffect(in: Capsule(style: .continuous))
            }
        }
    }
    /// 将 Color 转为 #RRGGBB 形式的 HEX 字符串
    private func hexString(for color: Color) -> String {
        // 先将 SwiftUI.Color 转成 UIColor
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
            let ri = Int(round(r * 255))
            let gi = Int(round(g * 255))
            let bi = Int(round(b * 255))
            return String(format: "#%02X%02X%02X", ri, gi, bi)
        } else {
            // 回退：无法解析时返回白色 HEX
            return "#FFFFFF"
        }
    }
}
// MARK: - 水印参数面板（子 View）

private struct WatermarkControlsPanel: View {
    @Binding var watermarkScale: Double
    @Binding var watermarkFontName: String
    @Binding var watermarkColor: Color
    @Binding var watermarkText: String
    
    /// 来自父级的 FocusState 绑定，用于控制键盘焦点
    var watermarkFocus: FocusState<Bool>.Binding
    
    var capsuleHighlightStart: UnitPoint
    var capsuleHighlightEnd: UnitPoint
    
    var onTapFontPicker: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 第一行：文字大小（标题 + 当前值）+ 下一行滑块
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("文字大小")
                    Spacer()
                    Text("\(Int(watermarkScale * 100))%")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $watermarkScale, in: 0.02...0.15)
            }
            
            Divider()
            
            // 字体（从系统字库中选择） + 颜色选择器（无文字标签）
            HStack {
                // 左侧：字体
                Text("字体：")

                Button {
                    onTapFontPicker()
                } label: {
                    Text(watermarkFontName == "System" ? "系统默认" : watermarkFontName)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .glassEffect(in: Capsule(style: .continuous))

                Spacer()

                // 右侧：颜色（使用系统 ColorPicker）
                ColorPicker("", selection: $watermarkColor, supportsOpacity: true)
                    .labelsHidden()
            }

            Divider()

            // 文字内容输入区和内嵌“完成”按钮（按钮位于输入框内部右下角）
            VStack(alignment: .leading, spacing: 4) {
                Text("水印文字内容：")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 0.8)
                    
                    TextEditor(text: $watermarkText)
                        .font(.body)
                        .frame(height: 56)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .focused(watermarkFocus)
                        .scrollContentBackground(.hidden)
                    
                    if watermarkText.isEmpty {
                        Text("此处输入水印文字")
                            .font(.body)
                            .foregroundStyle(.secondary.opacity(0.6))
                            .padding(.horizontal, 17)
                            .padding(.vertical, 15)
                    }
                    
                    // 将“完成”按钮叠加在输入框内部右下角
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button("完成") {
                                watermarkFocus.wrappedValue = false
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .controlSize(.regular)
                        }
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
    }
}

// MARK: - 图片水印参数面板（微信表情栏风格）
private struct ImageWatermarkControlsPanel: View {
    let images: [UIImage]
    @Binding var selectedIndex: Int?
    @Binding var scale: Double
    @Binding var opacity: Double
    var onAdd: () -> Void
    var onDelete: (Int) -> Void
        
    private let itemSize: CGFloat = 56
        
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("图片大小")
                    Spacer()
                    Text("\(Int(scale * 100))%")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $scale, in: 0.05...0.5)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("不透明度")
                    Spacer()
                    Text("\(Int(opacity * 100))%")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $opacity, in: 0.1...1.0)
            }
            
            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // “添加”按钮
                    Button {
                        onAdd()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: itemSize, height: itemSize)
                    }
                    .buttonStyle(.plain)
                    
                    // 已添加的图片水印缩略图
                    ForEach(images.indices, id: \.self) { idx in
                        let img = images[idx]
                        Button {
                            // 轻点：选择 / 取消选择当前图片水印
                            if selectedIndex == idx {
                                selectedIndex = nil   // 再次点击可取消选中
                            } else {
                                selectedIndex = idx
                            }
                        } label: {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: itemSize, height: itemSize)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(
                                            selectedIndex == idx ? Color.accentColor : Color.clear,
                                            lineWidth: 3
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                onDelete(idx)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

// MARK: - ActivityView：封装 UIActivityViewController 供 SwiftUI 调用
struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // 无需更新
    }
}
