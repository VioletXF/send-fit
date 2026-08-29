# SendFit contributor guide

## Toolchain and commands

- Xcode 26 / Swift 6.2; iOS and iPadOS deployment target: 18.0.
- Generate the Xcode project after editing `project.yml`: `xcodegen generate`.
- Build for an available iOS Simulator: `xcodebuild -project SendFit.xcodeproj -scheme SendFit -sdk iphonesimulator -configuration Debug build`.
- Run unit tests: `xcodebuild test -project SendFit.xcodeproj -scheme SendFit -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`.

## Architecture

- `Domain` holds deterministic video and advertising policy types. It has no SwiftUI, AVFoundation, Google Ads, or UMP dependency.
- `Services` owns importing, AVFoundation metadata/export/compression, consent, and Google ads integrations.
- `Features` owns focused SwiftUI screens. `SendFitModel` coordinates state only; views never perform AVFoundation or SDK work.
- Every source (Photos, Files, and external document opening) enters `VideoImportService` and yields one `VideoAsset`.

## Concurrency

- UI state is `@MainActor` and uses Observation.
- AVFoundation reader/writer work executes off the main actor and reports typed progress/results back to the model.
- Ads and consent are optional side effects. They must never determine compression state or block imports.
- Every import and export has explicit ownership. Only SendFit-managed temporary files are deleted.

## Monetization boundary

- All ad decisions go through `EntitlementProviding` and `AdPolicy`.
- This release uses only `FreeEntitlementProvider`; do not add StoreKit, paywalls, or purchase UI.
- Debug uses Google test IDs. Release requires IDs supplied through build settings; do not fabricate production IDs.

## Definition of done

- The app builds and its unit tests pass.
- A supported video can be imported from Photos, Files, or document opening; metadata, target-size compression, results, save/share, cancellation, and safe cleanup work.
- Compression is on-device, bounded to three attempts, and remains available with no network, consent, or ad inventory.
- Documentation, privacy copy, release checklist, and future monetization notes are present.
