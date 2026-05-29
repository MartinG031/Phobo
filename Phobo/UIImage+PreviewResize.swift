import UIKit

extension UIImage {
    func resizedForPreview(maxPixelLength: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxPixelLength else { return self }

        let scale = maxPixelLength / longestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
