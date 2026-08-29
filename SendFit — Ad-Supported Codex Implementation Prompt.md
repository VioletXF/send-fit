# SendFit — Production MVP Implementation Prompt

You are working in an existing Xcode project for a production-quality consumer app named **SendFit**.

SendFit has one primary purpose:

> Let a user select a video, choose a maximum output file size such as 10 MB, 25 MB, or 50 MB, and compress the video under that limit while preserving the best practical quality.

This is intended to become a real App Store product.

The initial monetization model is:

> **Unlimited free compression supported by advertising.**

There is **NO in-app purchase in this version**.

However, the architecture MUST make it easy to add a future one-time:

> **Remove Ads Forever**

StoreKit 2 purchase without rewriting compression logic, advertising logic, or major UI flows.

Do not implement StoreKit or any purchase UI now.

---

# 1. Before coding

Inspect the entire repository and existing Xcode project.

Then:

1. Determine the current deployment targets, Swift version, targets, capabilities, and test setup.
2. Create or update `AGENTS.md`.
3. Document:
   - exact build command,
   - exact test command,
   - architecture,
   - concurrency rules,
   - monetization boundaries,
   - definition of done.
4. Write a concise implementation plan.
5. Implement the plan completely.
6. Run builds and tests.
7. Fix failures before claiming completion.

Do not stop at scaffolding.

Do not leave TODO placeholders for required MVP functionality.

---

# 2. Platforms

Required:

- iOS 18 or later
- iPadOS 18 or later

Use:

- Swift
- SwiftUI
- AVFoundation
- PhotosUI
- UniformTypeIdentifiers
- Google Mobile Ads SDK
- Google User Messaging Platform SDK

Use Swift Package Manager for Google SDK integration when supported by the current official SDK.

Do not add arbitrary third-party packages.

Do not add:

- Firebase Analytics,
- Crashlytics,
- custom analytics,
- accounts,
- a backend,
- cloud video processing.

---

# 3. Main user flow

The primary flow must remain extremely simple.

1. Open SendFit.
2. Choose a video.
3. See:
   - source size,
   - duration,
   - resolution,
   - frame rate.
4. Select a target maximum size:
   - 5 MB
   - 10 MB
   - 25 MB
   - 50 MB
   - 100 MB
   - Custom
5. Tap **Compress**.
6. Compression begins.
7. Advertising may be shown according to the ad policy described later.
8. Compression completes.
9. Show:
   - original size,
   - final size,
   - percentage reduction,
   - output resolution,
   - output frame rate.
10. Allow:
   - Save to Photos
   - Save to Files
   - Share
   - Compress Another

Compression must remain usable even when:

- no ad inventory is available,
- the network is offline,
- consent prevents personalized advertising,
- the ad SDK fails,
- an ad fails to load.

**Advertising must never be a dependency of video compression.**

---

# 4. Architecture

Keep the architecture simple but maintain clean boundaries.

Create focused components equivalent to:

## Video domain

- `VideoAsset`
- `VideoMetadataReader`
- `CompressionRequest`
- `CompressionPlan`
- `CompressionResult`
- `CompressionEstimator`
- `VideoCompressionService`
- `ExportService`

## Monetization

- `EntitlementProviding`
- `FreeEntitlementProvider`
- `AdServing`
- `AdService`
- `AdPolicy`
- `ConsentManaging`

## Application state

Use a focused Observation-based view model or equivalent modern Swift state model.

Do not put:

- AVFoundation implementation,
- Google Mobile Ads implementation,
- consent implementation

directly inside SwiftUI views.

---

# 5. Critical future-IAP architecture

No StoreKit code should exist in this release.

However, the application must already be structured around an entitlement abstraction.

Create something conceptually equivalent to:

```swift
protocol EntitlementProviding: Sendable {
    var adsEnabled: Bool { get }
}
```

The current implementation should effectively behave like:

```swift
struct FreeEntitlementProvider: EntitlementProviding {
    let adsEnabled = true
}
```

Do NOT hardcode:

```swift
showAds = true
```

throughout the application.

All ad decisions must pass through the entitlement layer.

The future desired architecture is:

```text
FreeEntitlementProvider
        |
        v
EntitlementProviding
        |
        +---- AdPolicy
        |
        +---- UI
```

Later it should be possible to replace it with:

```text
StoreKitEntitlementProvider
        |
        v
EntitlementProviding
        |
        +---- AdPolicy
        |
        +---- UI
```

without modifying:

- video compression,
- video importing,
- exporting,
- individual ad views,
- most screen code.

Do NOT implement `StoreKitEntitlementProvider` now.

A short documentation section may explain where it would be added in the future.

Do not create fake purchasing code.

---

# 6. Advertising model

SendFit should be:

> Unlimited free usage + advertising.

There is no compression-count limit.

There is no paywall.

There is no subscription.

There is no purchase button.

Advertising should be designed around preserving user trust.

Implement:

### A. Advertising during compression screen

While compression is running, display a non-blocking ad placement in the progress UI when an ad is available.

Use an appropriate Google Mobile Ads format such as a banner or native placement.

The ad must:

- not cover compression progress,
- not cover Cancel,
- not move controls unpredictably after loading,
- reserve appropriate layout space where practical,
- clearly appear separate from application controls.

Compression continues regardless of whether the ad loads.

---

# 7. Interstitial advertising

Interstitial advertisements may be used, but conservatively.

Do NOT show an interstitial:

- on app launch,
- immediately after opening a video,
- every time the user taps something,
- unexpectedly while the user is editing a custom size,
- on app exit.

Use a clear natural transition.

A reasonable initial policy:

```text
successful compression count 1: no interstitial
successful compression count 2: no interstitial
successful compression count 3: eligible
then:
maximum approximately one interstitial per three completed compression flows
```

Also implement:

- no back-to-back interstitials,
- one interstitial maximum in a single compression flow,
- reasonable minimum time interval between interstitials,
- no interruption if the ad is not preloaded.

The exact frequency constants should live in `AdPolicy`.

They must not be scattered through SwiftUI code.

Example:

```swift
struct AdPolicyConfiguration {
    let firstInterstitialAfterSuccessfulCompressions: Int
    let compressionsBetweenInterstitials: Int
    let minimumInterstitialInterval: Duration
}
```

Use reasonable defaults.

Make the policy deterministic and unit-testable.

---

# 8. Interstitial timing

Follow current Google Mobile Ads recommendations.

Preload an interstitial before the likely display point.

Never:

1. start showing a new application screen,
2. wait for an ad network request,
3. suddenly cover the new screen several seconds later.

If the interstitial is not ready at the intended natural transition:

> skip it.

Do not delay the user waiting for advertising.

Advertising failure must always fail open.

The application should remain fully functional.

---

# 9. Do not assume every full-screen ad is video

Do NOT build product logic around the assumption:

> The user will watch a 30-second video while compression happens.

Normal interstitial inventory may include different creative types.

Treat the advertisement as advertising inventory, not as a guaranteed video experience.

Do not add custom fake video-ad behavior.

Do not add rewarded advertising in this MVP.

Do not create artificial rewards.

---

# 10. Compression must not depend on ad lifecycle

This is critical.

The following must NOT happen:

```text
ad failed → compression rejected
```

or:

```text
ad closed early → output discarded
```

or:

```text
no internet → cannot compress
```

The relationship must instead be:

```text
Compression Flow
       |
       +------ VideoCompressionService
       |
       +------ optional AdService
```

not:

```text
AdService
   |
   v
permission to compress
```

Video compression is the product.

Advertising is monetization.

Keep them independent.

---

# 11. Ad SDK test safety

During development:

- use Google's official test ad units,
- never use production ad unit identifiers for automated/manual development testing,
- make it difficult to accidentally ship test IDs in Release builds.

Create configuration equivalent to:

```swift
struct AdConfiguration {
    let bannerAdUnitID: String
    let interstitialAdUnitID: String
}
```

Separate:

- Debug/test configuration
- Release configuration

Do not scatter ad unit IDs through source files.

Production IDs may be represented by clearly documented configuration placeholders if actual IDs are not provided in the repository.

Do not fabricate production AdMob IDs.

The project must still build before real production IDs are entered.

---

# 12. Privacy consent

Integrate Google's current User Messaging Platform SDK correctly.

At application launch:

1. request updated consent information,
2. present a consent form if required,
3. determine whether ads may be requested,
4. initialize/request advertising only when appropriate.

Use the official current UMP APIs.

Do not rely only on an old cached consent string.

Provide a privacy-options entry point when UMP indicates one is required.

This can live under:

**Settings → Privacy Options**

Do not invent custom GDPR consent logic when UMP already provides the required flow.

---

# 13. ATT

Do not automatically display the App Tracking Transparency dialog merely because the Google Mobile Ads SDK exists.

First determine whether the actual configured advertising behavior requires tracking as defined by Apple.

Favor a privacy-conscious configuration.

The application must work with:

- tracking denied,
- tracking unavailable,
- no IDFA.

If ATT is not actually needed for the initial configuration, do not request it.

Document the reasoning in `README.md`.

If a later production AdMob configuration changes this requirement, clearly document where the developer must reassess:

- ATT,
- App Privacy disclosures,
- personalized advertising configuration.

---

# 14. Privacy copy

The application's strongest privacy statement should be specifically about the user's video.

Use:

> **Your videos never leave your device.**

Also use:

> Video compression happens entirely on your iPhone or iPad.

Do NOT claim:

> This app never uses the internet.

That would be false because advertising requires network communication.

Create `PRIVACY.md` accurately describing:

- videos remain on-device,
- SendFit does not upload videos,
- advertising is provided by Google Mobile Ads,
- the advertising SDK may process information according to Google's SDK behavior and user consent,
- SendFit itself does not operate a video-processing backend.

Do not invent claims about Google's data collection.

Document that App Store privacy disclosures must be reviewed against the exact SDK/version and production advertising configuration before submission.

---

# 15. Video import

Support:

- Photos
- Files

Correctly handle:

- portrait video,
- landscape video,
- video with audio,
- video without audio,
- different frame rates,
- high-frame-rate iPhone video,
- HDR input where technically feasible.

After selection display:

- filename when available,
- duration,
- source resolution,
- frame rate,
- source file size.

Do not permanently retain source videos.

Use temporary storage only when required.

Clean temporary files.

---

# 16. Core compression requirement

The user specifies a maximum output file size.

Example:

> 25 MB

A successful compression must normally produce:

```text
actualOutputSize <= requestedMaximumSize
```

Do not implement only generic:

- Low
- Medium
- High

presets.

Implement target-size-aware compression.

---

# 17. Bitrate calculation

Start from:

```text
targetTotalBits =
    targetSizeBytes * 8

targetTotalBitrate =
    targetTotalBits / durationSeconds
```

Reserve bitrate for:

- audio,
- MP4/container overhead,
- safety margin.

Conceptually:

```text
availableVideoBitrate =
    targetTotalBitrate
    - audioBitrate
    - safetyMargin
```

Use a documented configurable safety margin.

Start with a conservative value around several percent.

Keep bitrate calculations in deterministic pure logic suitable for unit testing.

---

# 18. Video encoding

Use AVFoundation.

Where necessary for bitrate control, use:

- `AVAssetReader`
- `AVAssetWriter`

Output:

- MP4
- H.264 video
- AAC audio

H.264 should be the MVP default for compatibility.

Do not use a simple export preset if doing so prevents target-size control.

---

# 19. Audio bitrate selection

Choose audio bitrate based on total available bitrate.

Reasonable conceptual options:

- 128 kbps
- 96 kbps
- 64 kbps

For extremely constrained outputs, gracefully reduce audio bitrate.

Do not let audio consume most of the available bitrate.

Do not completely remove audio without clearly telling the user.

---

# 20. Adaptive resolution

Automatically reduce video resolution when required.

Conceptual ladder:

- source
- 1920×1080
- 1280×720
- 960×540
- 640×360

Preserve aspect ratio.

Handle portrait equivalents correctly.

Never stretch the video.

Never accidentally rotate portrait videos.

---

# 21. Frame-rate adaptation

Prefer source frame rate when practical.

When necessary:

```text
120 fps → 60 fps
60 fps → 30 fps
```

Avoid unnecessary frame-rate conversion.

Do not convert normal 30 fps footage to 24 fps merely to save space.

Display resulting frame rate.

---

# 22. Output correction

Predicted encoded size will not always be exact.

After encoding:

1. inspect actual output size,
2. succeed if it fits,
3. otherwise calculate a corrected bitrate,
4. retry.

Use bounded retries.

Maximum:

> 3 total encoding attempts.

Conceptually:

```text
correctedBitrate =
    previousBitrate
    * targetSize
    / actualSize
    * safetyFactor
```

Do not use an infinite loop.

---

# 23. Impossible targets

Detect absurd targets.

Example:

- 3-hour 4K source
- 1 MB target

Do not produce useless output simply to satisfy the byte limit.

Define sensible minimum:

- video bitrate,
- resolution,
- audio bitrate.

Show:

> This video is too long to fit into 5 MB at a usable quality. Try a larger target size.

Keep this determination deterministic where possible.

---

# 24. Main UI

Use native SwiftUI.

Design:

- simple,
- polished,
- consumer-friendly,
- one obvious action per state.

Do not create a dashboard.

Do not add unnecessary tabs.

---

# 25. Empty state

Show:

**SendFit**

> Make videos fit any upload limit.

Primary:

**Choose Video**

Secondary:

**Open from Files**

Privacy text:

> Your videos never leave your device.

---

# 26. Selected-video state

Show:

- thumbnail,
- original file size,
- duration,
- resolution.

Prominent control:

**Target Size**

Presets:

- 5 MB
- 10 MB
- 25 MB
- 50 MB
- 100 MB
- Custom

Show predicted:

- output resolution,
- quality category.

CTA:

**Compress Video**

---

# 27. Compression screen

Show:

- progress,
- percentage when accurately available,
- current stage,
- Cancel button.

Possible stages:

- Preparing…
- Compressing…
- Optimizing size…
- Finishing…

Include a reserved advertising region appropriate for a banner/native placement.

The compression UX must remain understandable even if no ad is returned.

Do not let a late-loading ad cause major layout shifts.

---

# 28. Result screen

Clearly show:

**Before**

243.8 MB

**After**

24.6 MB

**90% smaller**

Also show:

- resulting resolution,
- resulting frame rate,
- duration.

Buttons:

- Save Video
- Share
- Compress Another

Interstitial eligibility may be evaluated only at an appropriate natural transition according to `AdPolicy`.

Never make saving the result dependent on viewing an ad.

---

# 29. Local preferences

Persist only lightweight settings such as:

- most recent target size,
- successful compression count,
- last interstitial display timestamp,
- other strictly necessary advertising-frequency state.

Do not create an account.

Do not create a device fingerprint.

Do not implement custom tracking.

---

# 30. Failure handling

Gracefully handle:

- unsupported video,
- corrupted video,
- Photos permission failure,
- source file disappearing,
- insufficient disk space,
- encoding error,
- cancellation,
- export failure,
- ad load failure,
- ad presentation failure,
- consent SDK failure.

Ad-related errors should normally remain invisible to the user unless user action is actually required.

A failed advertisement is not a product error.

---

# 31. Concurrency and performance

Video encoding must not block the main actor.

Avoid reading entire video files into memory.

Use streaming processing.

Keep memory use bounded.

Ad callbacks and compression callbacks must not create races in application state.

Avoid having advertising events directly mutate compression-engine state.

---

# 32. Background behavior

Use only officially supported iOS behavior.

Do not promise unlimited background video encoding.

If compression cannot reliably continue when suspended, communicate that honestly.

Do not use background-mode tricks solely to keep the app alive.

---

# 33. HDR and color correctness

Inspect source color properties.

Do not produce obviously washed-out output from HDR input.

If full HDR preservation is outside MVP scope:

- perform a correct SDR conversion when practical,
- document limitations.

Color correctness is more important than pretending every format is preserved.

---

# 34. Accessibility

Support:

- Dynamic Type,
- VoiceOver,
- light mode,
- dark mode,
- reasonable tap targets.

Do not communicate quality only by color.

---

# 35. Localization

Use String Catalogs.

Initial UI language:

- English

Structure localization cleanly for later:

- Korean
- Japanese
- additional App Store markets.

Do not scatter raw user-facing strings throughout implementation code.

---

# 36. Advertising abstraction tests

Unit-test `AdPolicy`.

At minimum test:

- first launch does not show interstitial,
- first compression does not show interstitial,
- second compression does not show interstitial,
- configured eligible compression does,
- minimum interval is enforced,
- no consecutive interstitials,
- entitlement with `adsEnabled == false` suppresses every ad,
- offline/ad-unavailable state never blocks compression.

The last entitlement test is critical even though the app currently ships only with:

```text
adsEnabled == true
```

This ensures future StoreKit integration has already been architecturally validated.

---

# 37. Compression logic tests

At minimum test:

- target bitrate calculation,
- safety margin,
- audio bitrate selection,
- resolution selection,
- frame-rate selection,
- impossible target detection,
- retry bitrate calculation,
- reduction percentage,
- file-size formatting.

Include examples:

- 60 sec → 10 MB
- 60 sec → 25 MB
- 10 min → 25 MB
- 30 sec → 5 MB
- extreme long-video/tiny-target case.

---

# 38. Manual QA document

Create `RELEASE_CHECKLIST.md`.

Include:

## Video

- 4K 60 fps
- 1080p 30 fps
- 1080p 60 fps
- 120 fps
- portrait
- landscape
- HDR
- video without audio
- 5-second clip
- 30-minute video

## Target sizes

- 5 MB
- 10 MB
- 25 MB
- 50 MB
- custom

Verify:

```text
outputSize <= requestedMaximumSize
```

for every successful result.

## Advertising

Test:

- fresh install,
- consent required,
- consent not required,
- privacy options,
- airplane mode,
- ad inventory unavailable,
- banner load success,
- banner load failure,
- interstitial success,
- interstitial failure,
- user closes interstitial,
- rapid repeated compressions,
- app background/foreground transitions.

Confirm:

> No advertising failure prevents compression, saving, or sharing.

---

# 39. Future StoreKit integration document

Create:

`FUTURE_MONETIZATION.md`

Do NOT implement StoreKit.

Document a future plan for:

> SendFit Pro / Remove Ads Forever

Explain that future work should:

1. add a StoreKit 2 product,
2. implement `StoreKitEntitlementProvider`,
3. replace/inject the current `FreeEntitlementProvider`,
4. have `adsEnabled == false` for entitled users,
5. cause `AdPolicy` to suppress:
   - banners,
   - native ads,
   - interstitials,
6. avoid loading unnecessary ads for paid users when practical.

The future implementation should NOT require changes to:

- `VideoCompressionService`,
- video importing,
- compression calculations,
- output exporting.

Do not add fake StoreKit types today.

The goal is architectural readiness, not speculative code.

---

# 40. Documentation

Create:

## `README.md`

Include:

- product purpose,
- architecture,
- build instructions,
- test instructions,
- compression design,
- advertising architecture,
- consent architecture,
- privacy overview,
- future monetization boundary.

## `PRIVACY.md`

Include accurate current behavior.

## `RELEASE_CHECKLIST.md`

As specified.

## `FUTURE_MONETIZATION.md`

As specified.

---

# 41. App Store review preparation

Review current Apple and Google requirements before release.

Ensure the developer manually verifies:

- App Privacy answers,
- advertising SDK disclosures,
- consent configuration,
- production AdMob identifiers,
- ATT applicability,
- privacy policy,
- required Info.plist entries.

Do not automatically generate legal conclusions.

Flag uncertain items in `RELEASE_CHECKLIST.md` for developer verification.

---

# 42. Explicitly excluded from MVP

Do not add:

- StoreKit,
- subscriptions,
- lifetime purchase UI,
- paywalls,
- rewarded ads,
- rewarded interstitials,
- custom ad mediation,
- Firebase Analytics,
- user accounts,
- backend processing,
- image compression,
- GIF compression,
- PDF compression,
- cloud storage,
- batch compression,
- trimming,
- cropping,
- filters,
- captions,
- AI features.

YAGNI.

---

# 43. Definition of done

The task is complete only when:

- project builds successfully,
- tests pass,
- a real video can be imported,
- source metadata is shown,
- target size can be selected,
- target-size-aware compression works,
- supported successful outputs stay below the requested limit,
- portrait orientation survives,
- audio survives,
- result can be saved/shared,
- compression runs independently of advertising,
- banner/native advertising integration works with test inventory,
- interstitial integration works with test inventory,
- UMP consent integration works,
- privacy options are exposed when required,
- airplane mode still allows full compression,
- ad load failure still allows full compression,
- `EntitlementProviding` isolates future paid status,
- setting a test entitlement to `adsEnabled == false` suppresses advertisements,
- StoreKit is NOT implemented,
- temporary files are cleaned,
- documentation is complete.

---

# 44. Verification before completion

Run:

1. all unit tests,
2. simulator tests where practical,
3. `xcodebuild` for the appropriate scheme.

Fix:

- compiler errors,
- failing tests,
- relevant Swift concurrency warnings.

Then manually inspect code for:

- accidental StoreKit implementation,
- hardcoded production ad IDs,
- force unwraps,
- unsafe casts,
- compression on main actor,
- ad callbacks controlling compression,
- accidental source-video upload,
- misleading privacy claims,
- temporary-file leaks,
- incorrect orientation handling,
- unbounded encoding retries,
- repeated/interruption-heavy ads.

Do not claim success without actual successful build/test output.

---

# 45. Final response

When finished, report:

1. files created,
2. files modified,
3. architecture implemented,
4. compression algorithm used,
5. advertising formats implemented,
6. UMP/consent behavior,
7. how future StoreKit integration is isolated,
8. exact build command and result,
9. exact test command and result,
10. known limitations,
11. physical-iPhone QA still required before App Store submission.

Implement the app.

Do not merely describe how to implement it.