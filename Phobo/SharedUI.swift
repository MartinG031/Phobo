import SwiftUI
import UIKit

struct RatioLabel: View {
    let width: Int
    let height: Int

    var body: some View {
        HStack(spacing: 2) {
            Text("\(width)")
            Text(":")
                .baselineOffset(2)
            Text("\(height)")
        }
        .font(.system(.body, design: .rounded).monospacedDigit())
    }
}

struct SystemFontPickerView: View {
    @Binding var selectedFontName: String
    @Environment(\.dismiss) private var dismiss

    @AppStorage("recentWatermarkFonts") private var recentFontsRaw: String = ""

    private let fontNames: [String] = {
        var names: [String] = []
        for family in UIFont.familyNames.sorted() {
            let fonts = UIFont.fontNames(forFamilyName: family).sorted()
            names.append(contentsOf: fonts)
        }
        return names
    }()

    private var recentFonts: [String] {
        recentFontsRaw
            .split(separator: "|")
            .map(String.init)
            .filter { fontNames.contains($0) }
    }

    var body: some View {
        NavigationView {
            List {
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

                if !recentFonts.isEmpty {
                    Section(header: Text("最近使用")) {
                        ForEach(recentFonts, id: \.self) { name in
                            fontButton(name)
                        }
                    }
                }

                Section(header: Text("系统字体")) {
                    ForEach(fontNames, id: \.self) { name in
                        fontButton(name)
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

    private func fontButton(_ name: String) -> some View {
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

    private func addRecentFont(_ name: String) {
        guard fontNames.contains(name) else { return }
        var current = recentFonts
        current.removeAll { $0 == name }
        current.insert(name, at: 0)
        if current.count > 5 {
            current = Array(current.prefix(5))
        }
        recentFontsRaw = current.joined(separator: "|")
    }
}

extension View {
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

    private func commitValues() {
        let w = max(Double(tempWidth) ?? width, 1)
        let h = max(Double(tempHeight) ?? height, 1)
        width = w
        height = h
        dismiss()
    }
}
