import UIKit

extension UIImage {
    func resizedForPreview(maxPixelLength: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height) * self.scale
        guard maxPixelLength.isFinite, maxPixelLength > 0,
              longestSide.isFinite, longestSide > maxPixelLength else { return self }

        let scale = maxPixelLength / longestSide
        let targetSize = CGSize(width: max(1, (size.width * self.scale * scale).rounded(.down)),
                                height: max(1, (size.height * self.scale * scale).rounded(.down)))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
