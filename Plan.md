# Phobo Project Plan

## 1. Project Overview

Phobo is an iOS SwiftUI app for quickly creating framed photo exports with optional text and image watermarks. The core workflow is:

1. Pick a photo from the system photo picker.
2. Preview the output canvas with a configurable background border.
3. Adjust aspect ratio, border width, color, text watermark, and image watermark.
4. Export by saving to Photos or sharing through the system share sheet.

The current app targets iOS 26.2 and uses iOS 26 visual APIs such as `glassEffect`.

## 2. Current Status

### Working

- Single Xcode target: `Phobo`.
- SwiftUI main interface with three tools:
  - Border controls.
  - Text watermark controls.
  - Image watermark controls.
- Photo picking through `PHPickerViewController`.
- Preview layout for canvas, image, text watermark, and image watermark.
- Export rendering through `RenderService`.
- Share sheet export.
- Photo library save flow uses `SaveService` with PNG-first / JPEG-fallback size control.
- Image watermark file persistence is isolated in `ImageWatermarkStore`.
- Previously selected image watermark is restored when still valid.
- Debug simulator build succeeds with Xcode 26.5.
- Baseline before plan execution was clean on `main`.

### Known Gaps

- `ContentView.swift` owns too much state and UI logic, making future changes harder.
- There are no unit tests or UI tests for rendering, persistence, or export behavior.
- App icon asset metadata exists, but the standard asset catalog entries do not reference image filenames.
- iOS 26.2 deployment target limits install base by design.

## 3. Product Goals

### Short Term

- Make photo export reliable and predictable.
- Keep the app simple: one image in, one polished image out.
- Preserve current visual style while reducing implementation risk.
- Add enough tests to catch rendering and persistence regressions.

### Medium Term

- Improve editing ergonomics for watermark placement.
- Add reusable presets for aspect ratios, border styles, and watermark styles.
- Make saved output behavior transparent to users.
- Prepare the codebase for adding more editing tools without bloating `ContentView`.

### Long Term

- Support a small batch workflow.
- Add export presets for social platforms.
- Consider broader iOS compatibility if `glassEffect` is not a hard product requirement.

## 4. Roadmap

### Phase 1: Stabilize Core Export

- Status: Complete for the current scope.
- Save now uses `SaveService.saveToPhotos`.
- Export preserves PNG when it is below the size cap, then falls back to JPEG compression.
- Add clear error messages for photo library permission failures.
- Verify save, share, and render output on simulator and device.

Acceptance criteria:

- Save and share use the same rendered output path.
- Failed saves display a useful message.
- No duplicate save implementations remain.

### Phase 2: Fix Persistence

- Status: Complete for the current scope.
- Restore the persisted image watermark selected index after loading saved watermark images.
- Store enough metadata to support future per-watermark settings.
- Add guards for missing or corrupted persisted image files.

Acceptance criteria:

- Previously added image watermarks reload after relaunch.
- Previously selected watermark reloads when still valid.
- Invalid persisted files do not crash or block app launch.

### Phase 3: Split Large UI Code

- Status: Started.
- Image watermark persistence has been extracted to `ImageWatermarkStore`.
- Move major panels into separate files:
  - `BorderControlsPanel.swift`
  - `WatermarkControlsPanel.swift`
  - `ImageWatermarkControlsPanel.swift`
  - `SystemFontPickerView.swift`
  - `CustomAspectRatioView.swift`
- Extract shared render configuration creation into a helper.
- Keep `ContentView` focused on screen composition and app state coordination.

Acceptance criteria:

- `ContentView.swift` becomes easier to scan.
- No behavior changes from the refactor.
- Build remains green after each extraction.

### Phase 4: Add Tests

- Add unit tests for `RenderService` canvas sizing.
- Add tests for aspect ratio and border percent clamping.
- Add tests for image watermark persistence logic after it is extracted from `ContentView`.
- Add basic UI tests for selecting tabs and opening primary sheets.

Acceptance criteria:

- Rendering math has deterministic tests.
- Persistence can be verified without launching the full app UI.
- Tests run through Xcode or `xcodebuild test`.

### Phase 5: Improve Editing Experience

- Add text watermark alignment controls.
- Add image watermark duplicate and reset-position actions.
- Add optional opacity control for text watermark.
- Add preset watermark positions: center, bottom center, bottom right, top right.
- Consider per-watermark settings if multiple image watermarks become selectable at once.

Acceptance criteria:

- Common watermark placement tasks require fewer drag operations.
- Controls remain compact on iPhone.
- Exported output matches preview closely.

### Phase 6: Release Preparation

- Confirm bundle identifier, signing team, version, and build number.
- Audit privacy strings.
- Verify app icons and accent color assets.
- Test on physical iPhone and iPad.
- Archive Release build.

Acceptance criteria:

- Release build archives successfully.
- App has correct icon, launch behavior, and photo permission messaging.
- Core workflow passes on real devices.

## 5. Technical Tasks

### Rendering

- Keep `RenderService` independent from SwiftUI state.
- Ensure preview layout and final render use matching math.
- Decide whether final output should cap longest side at 4000 px or make this configurable.

### Saving

- Use one save path.
- Prefer explicit `PHPhotoLibrary.performChanges` for better control.
- Keep callbacks on the main thread.

### Persistence

- Move image watermark file management into a small service type.
- Avoid force unwrapping the Documents directory.
- Store metadata in a small JSON file if per-watermark settings are added.

### UI

- Keep the three-tool tab model.
- Avoid adding new controls directly into `ContentView` unless they are screen-level state.
- Use system controls where possible.

### Compatibility

- Keep iOS 26.2 if Liquid Glass is central to the app identity.
- If broader compatibility matters, wrap `glassEffect` usage behind availability checks and lower the deployment target.

## 6. Risks

- The preview and export render paths can drift if layout math changes in only one place.
- Large PNG exports may create memory pressure or slow saves.
- Multiple image watermarks are partially supported as a library, but only one selected sticker is exported.
- SwiftUI state in `ContentView` is dense enough that small changes can cause unintended UI interactions.

## 7. Verification Checklist

- Build Debug simulator:
  - `xcodebuild -project Phobo.xcodeproj -scheme Phobo -configuration Debug -destination 'generic/platform=iOS Simulator' build`
- Build Release:
  - `xcodebuild -project Phobo.xcodeproj -scheme Phobo -configuration Release -destination 'generic/platform=iOS' build`
- Manual test:
  - Pick photo.
  - Change border width.
  - Change aspect ratio.
  - Change background color.
  - Add text watermark.
  - Drag text watermark.
  - Add image watermark.
  - Drag image watermark.
  - Share output.
  - Save output to Photos.
  - Relaunch and confirm persisted image watermarks.

## 8. Suggested Next Step

Start with Phase 1. The highest-value cleanup is to unify saving around one implementation, because export is the core promise of the app and `SaveService` already contains more deliberate file-size behavior than the current button path.
