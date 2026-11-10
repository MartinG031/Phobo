# Phobo Optimization Log

记录每次性能或架构优化，后续改动继续追加到本文件。

## 2026-09-05

### Preview Updates and Watermark Persistence

- Skip redraws for identical preview configurations, including SwiftUI updates unrelated to the canvas.
- Mutate only the dragged coordinates and skip redundant position callbacks while snapped in place.
- Preserve redraws when alignment guides change without a position change.
- Resize previews using actual pixel dimensions, including 2x/3x UIImage inputs, with invalid-limit guards.
- Serialize watermark file reads, writes, and selection persistence to prevent overlapping saves and stale selection callbacks.
- Load numbered watermark files in numeric order so wm_10.png follows wm_9.png.

Verification:

- iOS 27 Debug simulator build succeeded; only the existing AppIntents metadata warning remained.
- `Scripts/verify_preview.swift` passed on the iOS 27 simulator: 3x pixel resize, invalid limits, image reuse, configuration equality, opacity changes, and position changes.
- Device interaction and persistence stress testing were not performed.

Run the preview regression checks on a booted Apple Silicon simulator:

```sh
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
xcrun swiftc -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -target arm64-apple-ios27.0-simulator Phobo/EditingTool.swift Phobo/CanvasLayoutEngine.swift Phobo/UIKitPreviewCanvas.swift Phobo/UIImage+PreviewResize.swift Scripts/verify_preview.swift -o /tmp/phobo-preview-checks
xcrun simctl spawn booted /tmp/phobo-preview-checks
```

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
