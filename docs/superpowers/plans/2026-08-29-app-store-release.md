# SendFit App Store Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to execute these checked tasks in order.

**Goal:** Prepare SendFit for App Store review, publish `VioletXF/send-fit`, archive/upload the production build, and submit when Store validation allows it.

**Architecture:** Store policy, support, and reviewer guidance live in public repository documents. The icon lives in an Xcode asset catalog. Fastlane reads ignored release credentials and Match configuration; App Store Connect UI supplies account-specific metadata.

**Tech Stack:** Swift 6, XcodeGen, Xcode 26, Fastlane, Match, App Store Connect, GitHub CLI, Google Mobile Ads and UMP.

**Spec:** User request of 2026-08-29.

## Global Constraints

- Bundle ID: `com.sendfit.app`; deployment target: iOS/iPadOS 18.0.
- Videos remain on-device; ads and consent never block compression.
- Debug uses Google test IDs; release values remain in ignored configuration.
- Do not commit `.env`, signing assets, API keys, or Match passwords.

### Task 1: Store policy and support content

**Files:** Create `docs/APP_STORE_PRIVACY_POLICY.md`, `docs/APP_STORE_SUPPORT.md`, `docs/APP_STORE_REVIEW_NOTES.md`, and `scripts/verify_store_documents.sh`; modify `PRIVACY.md`.

- [ ] Write `scripts/verify_store_documents.sh` to require each of the three documents and verify it fails before those files exist.
- [ ] Add privacy copy covering on-device video processing, temporary local files, Photos/Files input, Google Mobile Ads, UMP consent, and no IDFA authorization request.
- [ ] Add support and reviewer paths for importing, compressing, saving/sharing, consent, banner, and interstitial behavior.
- [ ] Run `zsh scripts/verify_store_documents.sh` and require exit 0.

### Task 2: App icon asset

**Files:** Create `SendFit/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`, `SendFit/Assets.xcassets/AppIcon.appiconset/Contents.json`, and `scripts/verify_app_icon.sh`; modify `project.yml`.

- [ ] Write the icon verifier and confirm it fails before an icon exists.
- [ ] Generate a text-free opaque 1024×1024 SendFit icon with an abstract compressed-video and send/fit motif.
- [ ] Configure `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`.
- [ ] Run `zsh scripts/verify_app_icon.sh`, `xcodegen generate`, and the simulator build.

### Task 3: Fastlane release validation

**Files:** Create `scripts/verify_release_configuration.sh`; modify `fastlane/Fastfile` and `.env.example`.

- [ ] Require non-empty production AdMob, team, App Store Connect API-key, Match URL/password, and signing values without echoing secrets.
- [ ] Add an explicit `release` lane that creates/reuses the app, syncs Match, builds with production IDs, and uploads to TestFlight.
- [ ] Run `bundle exec fastlane ios lanes` and configuration validation; do not archive until required credentials exist.

### Task 4: GitHub publication

**Files:** Modify `README.md` and `.gitignore` only if needed.

- [ ] Verify `git check-ignore .env` before staging.
- [ ] Commit release-ready source and documents with no secret material.
- [ ] Create/push public `VioletXF/send-fit` through the authenticated GitHub CLI account.

### Task 5: App Store Connect and review submission

- [ ] Create/reuse `SendFit` with bundle ID `com.sendfit.app`, SKU `sendfit-ios`, English (U.S.), and current developer team.
- [ ] Upload the signed archive through Fastlane and wait for the TestFlight build to process.
- [ ] Use public GitHub privacy/support URLs, accurate ad/consent privacy responses, mandatory screenshots, review contact, export compliance, and the processed build.
- [ ] Submit only when App Store Connect reports no metadata, compliance, legal, or review blocker.
