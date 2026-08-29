# Share Sheet and External Video Opening

Add first-class support for launching SendFit directly from the iOS share sheet with a video.

This feature must integrate with the existing video-import, compression, advertising, consent, and future-entitlement architecture.

The desired user experience is:

```text
Photos / Files / another app
        ↓
Share
        ↓
SendFit
        ↓
SendFit launches
        ↓
Shared video is already selected
        ↓
Choose target size
        ↓
Compress
        ↓
Normal advertising pipeline applies
        ↓
Save / Share result
```

---

# 1. Prefer document-type opening over a Share Extension

Do NOT add a Share Extension target merely to transfer a video into SendFit unless platform investigation proves it is genuinely necessary.

Prefer the standard iOS document-opening mechanism.

Register SendFit as an application capable of opening supported movie content types using the appropriate modern configuration, including `CFBundleDocumentTypes` / supported UTTypes as necessary.

Support at minimum generic movie/video types equivalent to:

```text
public.movie
```

and ensure common compatible formats such as:

- MP4
- MOV
- M4V where supported by AVFoundation

are accepted through the generic movie declaration or additional type declarations where technically required.

Do not claim support for formats the compression engine cannot actually decode.

---

# 2. Share-sheet behavior

When a user is viewing a compatible video in:

- Photos,
- Files,
- or another application exposing the video through the system activity/share interface,

SendFit should be eligible as an application capable of receiving/opening that video where iOS permits.

Selecting SendFit should launch or activate the main SendFit application with the selected video.

The user should NOT need to:

1. share the video,
2. manually reopen SendFit,
3. select the same video again.

The incoming video must automatically become the currently selected source asset.

---

# 3. Do not compress inside an app extension

Video compression is resource-intensive and potentially long-running.

The actual compression operation must run in the normal SendFit application process.

Do not perform AVAssetReader / AVAssetWriter compression inside:

- a Share Extension,
- an Action Extension,
- a widget,
- another constrained extension process.

Do not initialize Google Mobile Ads merely to display advertising inside a Share Extension.

The main app is responsible for:

- compression,
- advertising,
- consent handling,
- exporting,
- result presentation.

---

# 4. Unified import architecture

Manual imports and externally opened videos must converge into exactly the same application model.

Conceptually:

```text
Photos Picker ───────┐
                     │
Files Picker ────────┼──> VideoImportService
                     │          ↓
External Open ───────┘      VideoAsset
                                ↓
                         Compression Flow
```

Do not create a separate compression implementation for shared videos.

Create or adapt a focused abstraction equivalent to:

```swift
enum VideoImportSource {
    case photos
    case files
    case externalOpen
}
```

and a component equivalent to:

```swift
VideoImportService
```

The downstream compression code should not care how the video arrived.

---

# 5. External URL routing

Implement a focused component equivalent to:

```swift
IncomingVideoRouter
```

Its responsibility is only to:

1. receive external file URLs passed to SendFit,
2. validate that they represent supported video content,
3. obtain safe access to the file,
4. coordinate/copy the file if necessary,
5. create a normal `VideoAsset`,
6. route the application to the selected-video state.

Do not put this logic directly in a SwiftUI root view.

Use the correct UIKit / SwiftUI application lifecycle mechanism for receiving externally opened documents.

If SwiftUI's normal URL-handling path is insufficient for file-document opening, bridge the required UIApplicationDelegate functionality cleanly rather than using unsupported hacks.

---

# 6. Security-scoped and provider-backed files

External videos may originate from:

- iCloud Drive,
- third-party File Provider extensions,
- local Files storage,
- another application's exported temporary file.

Handle file access correctly.

Where applicable:

- use security-scoped resource access correctly,
- coordinate reads when required,
- do not retain access longer than necessary,
- copy the source into a SendFit-managed temporary working location when necessary for reliable AVFoundation processing.

Never modify or overwrite the original shared video.

Compression must always create a separate output.

---

# 7. Temporary-file ownership

The import architecture must clearly distinguish:

```text
user-owned source
SendFit temporary working copy
SendFit compressed output
```

Never delete a user-owned source URL.

Only automatically delete files SendFit itself created.

Use explicit ownership metadata or types rather than guessing based on URL paths.

Temporary working files should be cleaned:

- after successful completion when no longer needed,
- after cancellation,
- after failures,
- on a later safe cleanup pass if the app was terminated unexpectedly.

---

# 8. Cold launch from Share Sheet

Test the case where SendFit is not running.

Expected behavior:

```text
User shares video
        ↓
SendFit cold launches
        ↓
normal app initialization begins
        ↓
incoming URL is retained safely
        ↓
video metadata is loaded
        ↓
selected-video screen appears
```

The incoming URL must not be lost because:

- consent initialization is still running,
- ad initialization is still running,
- SwiftUI root state has not finished initializing.

Advertising initialization and external-video routing must remain independent.

---

# 9. Warm launch from Share Sheet

Test the case where SendFit is already:

- idle,
- displaying another selected video,
- showing a previous compression result.

When another video is opened through the system:

1. safely cancel or resolve incompatible transient UI state,
2. replace the current source with the newly shared video,
3. return to the selected-video state.

Do not automatically destroy an actively running compression.

If a compression is currently active, do not silently replace its source.

Use a safe UX such as:

> A compression is currently running. Finish or cancel it before opening another video.

or queue the incoming video if the implementation can do so simply and reliably.

Prefer simplicity for the MVP.

---

# 10. Target-size behavior for shared videos

Do NOT immediately begin compression merely because a video was shared.

After receiving a shared video, show the normal selected-video screen.

Display:

- thumbnail,
- duration,
- original file size,
- resolution,
- frame rate,
- target size.

Reuse the user's most recently selected target size if available.

The user must still explicitly tap:

**Compress Video**

This preserves user control and creates a clean transition point for advertising.

---

# 11. Advertising behavior for Share Sheet launches

Videos received through the share sheet must use the exact same monetization pipeline as videos selected inside SendFit.

Do NOT create special:

```text
sharedVideoAds
```

or separate ad-frequency counters.

All routes converge into the existing:

```text
EntitlementProviding
        ↓
AdPolicy
        ↓
AdService
```

architecture.

---

# 12. Do not show an interstitial immediately on external launch

When SendFit is launched because the user selected it from a share/activity sheet:

Do NOT immediately cover the application with an interstitial advertisement.

The user has just explicitly requested SendFit to perform a task.

First:

1. receive the video,
2. load its metadata,
3. display the selected-video interface.

Advertising should follow the normal policy at an appropriate later transition.

---

# 13. Compression-start advertising

When the user taps:

**Compress Video**

for a video received through the share sheet, the normal advertising pipeline applies exactly as it does for an internally selected video.

Conceptually:

```text
User taps Compress
        ↓
CompressionFlowController
        ├── ask AdPolicy about eligible advertising
        └── prepare/start VideoCompressionService
```

The imported-video source must not affect ad eligibility.

For example:

```text
Photos Picker compression
Files Picker compression
Share Sheet compression
```

must all count as the same type of successful compression for ad-frequency purposes.

---

# 14. Compression-screen advertising

The normal compression-screen banner/native advertising placement should also appear when the compression originated from a shared video.

Example:

```text
Share Sheet
    ↓
SendFit
    ↓
25 MB
    ↓
Compress
    ↓
┌──────────────────────────────┐
│ Compressing…           42%   │
│                              │
│ ███████████░░░░░░░░░░        │
│                              │
│ Sponsored advertisement      │
│ [       ad content       ]   │
│                              │
│          Cancel              │
└──────────────────────────────┘
```

If no advertisement is available:

```text
compression continues normally
```

Do not leave an ugly empty gap if the ad cannot load.

Use a layout that can gracefully collapse or substitute neutral spacing without causing disruptive UI movement.

---

# 15. Ad frequency must be global

Persist successful-compression/ad-frequency state globally for SendFit.

Do not maintain separate counters for:

- manual imports,
- Files imports,
- share-sheet imports.

For example:

```text
Compression 1 — Photos
Compression 2 — Share Sheet
Compression 3 — Files
```

should be treated as:

```text
successfulCompressionCount == 3
```

for `AdPolicy`.

This prevents users from accidentally or intentionally bypassing monetization by entering through another import path.

---

# 16. Consent pipeline on Share Sheet launch

A cold launch caused by opening a shared video must still run the normal:

```text
UMP consent
        ↓
canRequestAds
        ↓
Mobile Ads initialization / ad requests
```

pipeline.

However:

**consent must not block video import.**

These operations should proceed independently where possible:

```text
                   ┌──> receive and inspect video
App launched ──────┤
                   └──> update advertising consent
```

The selected video screen should appear even if:

- consent is still being resolved,
- ads cannot yet be requested,
- UMP fails,
- the device is offline.

When advertising becomes available later, the normal ad pipeline may use it at an appropriate future placement.

Do not suddenly display an interstitial simply because consent finished.

---

# 17. Future Remove Ads entitlement

Share-sheet usage must already respect the common entitlement architecture.

Every advertising decision must ultimately depend on:

```swift
entitlementProvider.adsEnabled
```

or the equivalent abstraction.

When a future StoreKit implementation changes the entitlement to:

```text
adsEnabled == false
```

then BOTH:

- ordinary in-app compression,
- share-sheet initiated compression

must become ad-free automatically.

Adding StoreKit later must not require modification of:

- IncomingVideoRouter,
- VideoImportService,
- external document handling,
- VideoCompressionService.

---

# 18. Result sharing must not create recursion bugs

SendFit already allows the compressed output to be shared through the system share sheet.

Because SendFit itself is now an eligible video-opening target, ensure this does not create confusing internal behavior.

If the user opens SendFit's own compressed result back into SendFit from the share sheet, treat it as a normal new source video.

Do not automatically re-import a file merely because SendFit presented a `UIActivityViewController`.

Only react when the system actually sends a new external-open request to SendFit.

---

# 19. Multiple-video input

For the MVP, support exactly:

> one video per external-open operation.

If the activity provider attempts to send multiple videos:

- do not crash,
- clearly explain that SendFit currently compresses one video at a time.

Do NOT implement batch compression yet.

---

# 20. Unsupported shared content

SendFit should not appear as a generic handler for unrelated content.

Do not register:

- images,
- PDFs,
- arbitrary files,
- URLs,
- text.

Register only video/movie content that SendFit can meaningfully process.

If an unexpected incompatible file reaches the application anyway, show:

> SendFit couldn't open this video.

with a simple way to return to the normal empty state.

---

# 21. Tests

Add deterministic tests for external-video routing where practical.

At minimum test:

- valid supported movie URL,
- unsupported file,
- missing file,
- incoming video becomes current `VideoAsset`,
- import source is recorded as external,
- external import and manual import use the same compression path,
- external imports increment the same successful-compression counter,
- ad eligibility is identical regardless of import source,
- `adsEnabled == false` suppresses advertising for external imports,
- ad failure does not prevent external-import compression.

---

# 22. Manual physical-device QA

Add these cases to `RELEASE_CHECKLIST.md`.

## Photos

- open a normal iPhone video,
- tap Share,
- select SendFit,
- confirm SendFit launches,
- confirm video is already selected,
- compress,
- verify advertising pipeline,
- save result.

## Files

Repeat using:

- On My iPhone,
- iCloud Drive.

## Other apps

Test at least one other application capable of sharing/exporting a movie file.

## Cold start

- force quit SendFit,
- share a video to SendFit,
- verify incoming video survives cold launch.

## Warm start

- leave SendFit open,
- share another video,
- verify it is imported correctly.

## Offline

- enable Airplane Mode,
- share a video,
- verify SendFit launches,
- verify compression works,
- verify advertising failure does not interfere.

## Consent

Test a cold share-sheet launch while UMP consent UI is required.

Verify that:

- the shared video is not lost,
- consent handling works,
- compression remains usable.

---

# 23. Definition of done

External video opening is complete only when:

- SendFit appears as an appropriate target for compatible shared/opened videos where supported by iOS,
- selecting SendFit launches the main app,
- the video is automatically imported,
- no Share Extension is required merely for handoff,
- the same `VideoAsset` pipeline is used,
- the same compression engine is used,
- the same global `AdPolicy` is used,
- the same consent pipeline is used,
- no immediate launch interstitial is shown,
- compression-screen advertising works,
- offline share-sheet usage still works,
- future `adsEnabled == false` suppresses ads without modifying this feature,
- original files are never overwritten,
- temporary-file ownership is correct,
- cold and warm launches work.

Do not implement a parallel share-extension-specific version of SendFit.

The feature should feel like a native alternate entry point into the exact same SendFit product.