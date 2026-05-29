import Foundation

/// 编辑工具类型：边框 / 文字水印 / 图片水印（可以叠加使用）
enum EditingTool: Hashable {
    case border
    case watermark
    case imageWatermark
}
