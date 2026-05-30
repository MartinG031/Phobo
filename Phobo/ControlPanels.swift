import SwiftUI
import UIKit

struct BorderControlsPanel: View {
    @Binding var borderPercent: Double
    @Binding var backgroundColor: Color
    @Binding var customAspectWidth: Double
    @Binding var customAspectHeight: Double

    var onTapAspectEditor: () -> Void
    var onRotateAspect: () -> Void
    var onResetAspect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            HStack(spacing: 8) {
                Text("背景颜色：")

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(backgroundColor)
                    .frame(width: 32, height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 0.6)
                    )

                Text(hexString(for: backgroundColor))

                Spacer()

                ColorPicker("", selection: $backgroundColor, supportsOpacity: true)
                    .labelsHidden()
            }

            Divider()

            HStack(spacing: 4) {
                Text("画幅比例：")
                RatioLabel(width: Int(customAspectWidth), height: Int(customAspectHeight))

                Spacer()

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

    private func hexString(for color: Color) -> String {
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
            return "#FFFFFF"
        }
    }
}

struct WatermarkControlsPanel: View {
    @Binding var watermarkScale: Double
    @Binding var watermarkFontName: String
    @Binding var watermarkColor: Color
    @Binding var watermarkText: String

    var watermarkFocus: FocusState<Bool>.Binding
    var onTapFontPicker: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            HStack {
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

                ColorPicker("", selection: $watermarkColor, supportsOpacity: true)
                    .labelsHidden()
            }

            Divider()

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

struct ImageWatermarkControlsPanel: View {
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

                    ForEach(images.indices, id: \.self) { idx in
                        let img = images[idx]
                        Button {
                            if selectedIndex == idx {
                                selectedIndex = nil
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
