# SendFit MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a production-oriented iOS 18/iPadOS 18 video compressor with unified imports and fail-open advertising.

**Architecture:** Pure `Domain` value types calculate target-aware plans and ad eligibility. AVFoundation/Photos/Files/document-opening services feed a `@MainActor` Observation model, while SwiftUI renders the flow. Ad and UMP services sit behind protocols and depend on `EntitlementProviding`, never on compression.

**Tech Stack:** Swift 6.2, SwiftUI, Observation, AVFoundation, PhotosUI, UniformTypeIdentifiers, Google Mobile Ads and UMP via SPM.

**Spec:** `SendFit — Ad-Supported Codex Implementation Prompt.md`, `SendFit — Share Sheet - External Video Import Addendum.md`

## Global Constraints

- iOS/iPadOS 18+, no StoreKit, accounts, backend, analytics, batching, or Share Extension.
- Input is one supported movie; output is H.264/AAC MP4 generated on device.
- Ad/consent failure always fails open; only the entitlement/ad-policy layer decides whether ads are requested.
- Never delete or overwrite a user-owned source.

---

### Task 1: Project and deterministic domain

**Files:** `project.yml`, `SendFit/Domain/*.swift`, `SendFitTests/CompressionDomainTests.swift`, `SendFitTests/AdPolicyTests.swift`

- [ ] Write failing tests for bitrate planning, safety margin, resolution/frame-rate selection, impossible-target detection, reduction formatting, entitlement suppression, and interstitial interval/count policy.
- [ ] Generate an iOS 18 Xcode project with application and XCTest targets plus official Google SPM dependencies.
- [ ] Implement the pure domain value types and run the test target until green.

### Task 2: Unified video import and metadata

**Files:** `SendFit/Services/VideoImportService.swift`, `IncomingVideoRouter.swift`, `VideoMetadataReader.swift`, `TemporaryFileStore.swift`, matching XCTest files.

- [ ] Write failing tests around accepted local movie URLs, rejected/missing URLs, source recording, and temporary ownership.
- [ ] Implement security-scoped read/copy behavior, one source model, metadata reading, and cleanup.
- [ ] Add document-type declarations and app-delegate routing without an extension.

### Task 3: Compression and export

**Files:** `VideoCompressionService.swift`, `ExportService.swift`, integration tests.

- [ ] Define tests for bounded retry calculations/cancellation/error reporting.
- [ ] Implement streaming AVAssetReader/Writer H.264/AAC MP4 encoding, orientation transform, a conservative size plan, actual-size checks, and at most three attempts.
- [ ] Implement Photos, Files, and share exports.

### Task 4: Consent and ads

**Files:** `Entitlements.swift`, `AdPolicy.swift`, `AdService.swift`, `ConsentManager.swift`, `BannerAdView.swift`.

- [ ] Keep testable policy/entitlement logic independent of SDKs.
- [ ] Integrate UMP refresh/presentation/privacy options, then initialize and preload Google test banner/interstitial inventory only after consent permits requests.
- [ ] Ensure every unavailable/error path remains non-blocking.

### Task 5: App model and SwiftUI flow

**Files:** `SendFitModel.swift`, `Features/*.swift`, `SendFitApp.swift`.

- [ ] Create the empty, selected, compressing, result, settings, and import-error states with Dynamic Type/VoiceOver labels.
- [ ] Wire PhotosPicker, FileImporter, `onOpenURL`, import replacement protection during active compression, target presets/custom size, exports, and ad presentation transitions.
- [ ] Build after every screen set and correct all Swift 6 concurrency diagnostics.

### Task 6: Documentation and verification

**Files:** `README.md`, `PRIVACY.md`, `RELEASE_CHECKLIST.md`, `FUTURE_MONETIZATION.md`, `AGENTS.md`.

- [ ] Document exact commands, tested behavior, no-ATT rationale, deployment/consent configuration, physical device checks, and future StoreKit seam.
- [ ] Run `xcodegen generate`, `xcodebuild build`, and `xcodebuild test` against an installed simulator; fix errors before completing.
