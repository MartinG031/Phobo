// ContentView.swift
// 图片加边框小工具主界面
// 功能：选择照片 → 预览加“背景边框”效果 → 自定义边框宽度 / 画布比例 → 保存到相册

import SwiftUI
import UIKit


struct ContentView: View {
    // 通用外边距：控制参数区域与屏幕边缘的间距（水平和底部共用）
    private let panelOuterPadding: CGFloat = 16
    // 参数大面板最小高度（整体比原来高约一行文字，用于所有功能面板统一增高）
    private let controlPanelMinHeight: CGFloat = 266
    
    // MARK: - 选择图片 / 原图数据
    @State private var showingImagePicker = false          // 是否显示系统图片选择器
    @StateObject private var imagePipeline = ImagePipeline()
    
    // MARK: - 编辑配置
    @State private var editor = EditorState()
    
    // 画布比例（宽 : 高），默认 1 : 1（使用 @AppStorage 持久化，跨启动保留上次设置）
    @AppStorage("customAspectWidth") private var customAspectWidth: Double = 1
    @AppStorage("customAspectHeight") private var customAspectHeight: Double = 1
    
    @State private var showingImageWatermarkPicker: Bool = false
    @State private var watermarkPickerImage: UIImage? = nil

    // 字体选择器弹层
    @State private var showingFontPicker: Bool = false
    
    // 水印文字输入焦点，用于控制键盘收起
    @FocusState private var isWatermarkFieldFocused: Bool
    // 记录在弹出图片选择器之前是否处于文字水印编辑状态
    @State private var wasWatermarkEditingBeforeImagePicker: Bool = false

    // 是否显示“更多比例”编辑面板（单独弹出的底部浮层）
    @State private var showingAspectEditor = false
    
    // MARK: - 预览区域封装
    private var previewArea: some View {
        Group {
            if let image = imagePipeline.previewImage {
                // 已选择图片时：预览使用降采样版本，导出仍使用原图。
                previewForImage(image)
            } else if imagePipeline.inputImage != nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        UIKitPreviewCanvas(
            image: image,
            backgroundColor: UIColor(editor.backgroundColor),
            borderPercent: editor.borderPercent,
            aspectWidth: customAspectWidth,
            aspectHeight: customAspectHeight,
            activeTool: editor.selectedTool,
            watermarkText: editor.watermarkText,
            watermarkScale: editor.watermarkScale,
            watermarkFontName: editor.watermarkFontName,
            watermarkColor: UIColor(editor.watermarkColor),
            watermarkX: $editor.watermarkX,
            watermarkY: $editor.watermarkY,
            stickerImage: editor.selectedStickerImage,
            stickerScale: editor.imageWatermarkScale,
            stickerOpacity: editor.imageWatermarkOpacity,
            stickerX: $editor.imageWatermarkX,
            stickerY: $editor.imageWatermarkY
        )
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
                        borderPercent: $editor.borderPercent,
                        backgroundColor: $editor.backgroundColor,
                        customAspectWidth: $customAspectWidth,
                        customAspectHeight: $customAspectHeight,
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
                        watermarkScale: $editor.watermarkScale,
                        watermarkFontName: $editor.watermarkFontName,
                        watermarkColor: $editor.watermarkColor,
                        watermarkText: $editor.watermarkText,
                        watermarkFocus: $isWatermarkFieldFocused,
                        onTapFontPicker: { showingFontPicker = true }
                    )
                case .imageWatermark:
                    ImageWatermarkControlsPanel(
                        images: editor.imageWatermarks,
                        selectedIndex: $editor.selectedImageWatermarkIndex,
                        scale: $editor.imageWatermarkScale,
                        opacity: $editor.imageWatermarkOpacity,
                        onAdd: { showingImageWatermarkPicker = true },
                        onDelete: { index in
                            editor.deleteImageWatermark(at: index)
                            editor.saveImageWatermarks()
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
            TabView(selection: $editor.selectedTool) {
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
                        if editor.selectedTool == .watermark && isWatermarkFieldFocused {
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
                        .disabled(imagePipeline.inputImage == nil || imagePipeline.isRenderingOutput)

                        Button("保存") {
                            saveImageWithBackground()
                        }
                        .disabled(imagePipeline.inputImage == nil || imagePipeline.isRenderingOutput)
                    }
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $imagePipeline.inputImage)
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
            SystemFontPickerView(selectedFontName: $editor.watermarkFontName)
        }
        .sheet(item: $imagePipeline.sharePayload) { payload in
            ActivityView(activityItems: [payload.image])
        }
        .onChange(of: watermarkPickerImage) { _, newValue in
            if let img = newValue {
                editor.appendImageWatermark(img)
                watermarkPickerImage = nil
                // 每次新增图片水印后立即持久化到磁盘
                editor.saveImageWatermarks()
            }
        }
        .onChange(of: editor.selectedImageWatermarkIndex) { _, _ in
            editor.saveSelectedImageWatermarkIndex()
        }
        // 监听图片选择器的显示/隐藏，选完图后自动恢复文字编辑状态（如果之前正在编辑）
        .onChange(of: showingImagePicker) { oldValue, newValue in
            // 仅在图片选择器从显示变为隐藏时处理
            if oldValue == true && newValue == false {
                if wasWatermarkEditingBeforeImagePicker {
                    wasWatermarkEditingBeforeImagePicker = false
                    // 仍然停留在文字水印工具时才恢复焦点
                    if editor.selectedTool == .watermark {
                        // 延迟到下一轮 RunLoop，避免和收键盘动画冲突
                        DispatchQueue.main.async {
                            isWatermarkFieldFocused = true
                        }
                    }
                }
            }
        }
        .alert("保存成功", isPresented: $imagePipeline.showSaveSuccessAlert) {
            Button("好") { }
        } message: {
            Text("已保存到系统相册。")
        }
        .alert("保存失败", isPresented: $imagePipeline.showSaveErrorAlert) {
            Button("好") { }
        } message: {
            Text(imagePipeline.saveErrorMessage)
        }
        .onAppear {
            // 首帧先显示界面，再延后加载历史图片水印，减少冷启动等待感。
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                ImageWatermarkStore.load { loaded, selectedIndex in
                    editor.restoreImageWatermarks(loaded, selectedIndex: selectedIndex)
                }
            }
        }
    }

    // MARK: - 单个 Tab 页面布局（共享预览区域，不同参数面板）
    @ViewBuilder
    private func mainPage(for tool: EditingTool) -> some View {
        if editor.selectedTool == tool {
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
        } else {
            Color.clear
        }
    }
    
    // MARK: - 保存：生成纯色背景 + 不裁剪的原图（单张）
    private func saveImageWithBackground() {
        guard let originalImage = imagePipeline.inputImage else { return }

        let config = editor.renderConfig(
            for: originalImage,
            aspectWidth: customAspectWidth,
            aspectHeight: customAspectHeight
        )
        imagePipeline.save(config: config)
    }

    // MARK: - 分享：通过系统 Activity View 分享当前成品图
    private func shareImageViaActivityView() {
        guard let originalImage = imagePipeline.inputImage else { return }

        let config = editor.renderConfig(
            for: originalImage,
            aspectWidth: customAspectWidth,
            aspectHeight: customAspectHeight
        )
        imagePipeline.share(config: config)
    }
}
