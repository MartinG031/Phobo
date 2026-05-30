# Phobo Optimization Log

记录每次性能或架构优化，后续改动继续追加到本文件。

## 2026-05-29

### Performance: Preview and Export Responsiveness

- Removed unused device-motion driven state updates from the root SwiftUI view.
- Moved save/share output rendering off the main thread.
- Added a downsampled preview image path so interactive preview does not use full-resolution photo data.
- Reduced redundant state writes during watermark dragging.

Verification:

- `xcodebuild -scheme Phobo -project Phobo.xcodeproj -configuration Debug -destination 'generic/platform=iOS Simulator' build`

### Performance: UIKit Preview Canvas

- Replaced the SwiftUI preview composition path with a UIKit-backed preview canvas.
- Moved image, text watermark, sticker watermark, guide line drawing, and drag hit-testing into `PreviewCanvasUIView`.
- Kept final export on `RenderService` so output quality and file generation remain unchanged.

Verification:

- `xcodebuild -scheme Phobo -project Phobo.xcodeproj -configuration Debug -destination 'generic/platform=iOS Simulator' build`

### Architecture: Split Preview Layer

- Extracted `EditingTool` from `ContentView.swift` into `EditingTool.swift`.
- Extracted the UIKit preview bridge and drawing view into `UIKitPreviewCanvas.swift`.
- Extracted the share sheet bridge into `ActivityView.swift`.
- Extracted preview-image resizing into `UIImage+PreviewResize.swift`.

Verification:

- `xcodebuild -scheme Phobo -project Phobo.xcodeproj -configuration Debug -destination 'generic/platform=iOS Simulator' build`

## 2026-05-30

### Architecture: Shared Canvas Layout Engine

- Added `CanvasLayoutEngine` as the single source of truth for base canvas, preview layout, and export layout geometry.
- Updated `UIKitPreviewCanvas` to use `CanvasLayoutEngine.previewLayout`.
- Updated `RenderService` to use `CanvasLayoutEngine.renderLayout`.
- Reduced preview/export drift risk by removing duplicate canvas sizing math.

Verification:

- `xcodebuild -scheme Phobo -project Phobo.xcodeproj -configuration Debug -destination 'generic/platform=iOS Simulator' build`

### Architecture: Editor State Extraction

- Added `EditorState` to group canvas, text watermark, image watermark, and selected tool state.
- Moved selected sticker lookup, image watermark insertion/deletion, and render config assembly out of `ContentView`.
- Kept transient UI state such as sheets, alerts, focus, and rendering progress in `ContentView`.
- Reduced `ContentView` responsibility so the next architecture pass can target image loading/output orchestration separately.

Verification:

- `xcodebuild -scheme Phobo -project Phobo.xcodeproj -configuration Debug -destination 'generic/platform=iOS Simulator' build`

### Architecture: Image Pipeline Extraction

- Added `ImagePipeline` as the owner of selected original image, downsampled preview image, rendering progress, save alerts, and share payload.
- Moved preview downsampling cancellation and save/share rendering orchestration out of `ContentView`.
- Kept render configuration creation in `EditorState` so output parameters remain centralized.
- Removed direct background rendering and preview generation state from `ContentView`.

Verification:

- `xcodebuild -scheme Phobo -project Phobo.xcodeproj -configuration Debug -destination 'generic/platform=iOS Simulator' build`

### Architecture: Control Panel Component Split

- Moved border, text watermark, and image watermark control panels into `ControlPanels.swift`.
- Moved shared UI helpers, custom aspect ratio editing, and system font picker into `SharedUI.swift`.
- Reduced `ContentView.swift` from 968 lines to 350 lines, leaving it focused on screen composition and interaction routing.

Verification:

- `xcodebuild -scheme Phobo -project Phobo.xcodeproj -configuration Debug -destination 'generic/platform=iOS Simulator' build`

### Architecture: Image Watermark Persistence Boundary

- Added image watermark restore/save helpers to `EditorState`.
- Removed the `ContentView` persistence extension so the view no longer knows how selected watermark indexes are persisted.
- Kept delayed loading after first frame to preserve the previous cold-start responsiveness improvement.

Verification:

- `xcodebuild -scheme Phobo -project Phobo.xcodeproj -configuration Debug -destination 'generic/platform=iOS Simulator' build`
