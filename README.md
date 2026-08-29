# SendFit

SendFit compresses one video on-device to a user-selected maximum file size (5 MB, 10 MB, 25 MB, 50 MB, 100 MB, or a custom amount). It supports Photos, Files, and compatible videos opened by SendFit from the system share/open flow.

## Build and test

```sh
xcodegen generate
xcodebuild build -project SendFit.xcodeproj -scheme SendFit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test -project SendFit.xcodeproj -scheme SendFit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Architecture

- `Domain` contains the deterministic target-size estimator and entitlement-aware `AdPolicy`.
- `Services` imports a file once, keeps ownership explicit, reads metadata, streams AVFoundation reader/writer compression, and exports the result.
- `Features` contains the Observation-backed app model and small SwiftUI views for empty, selected, progress, result, and settings states.
- Photos, Files, and external document opening converge on `VideoImportService` and a `VideoAsset`; no Share Extension exists.

## Compression design

SendFit calculates total bitrate from target bytes and duration, reserves audio and a 15.2% container/safety margin, selects an aspect-preserving resolution/frame-rate plan, and encodes MP4 using H.264 video and AAC audio. The actual output size is inspected; oversized output is retried at a corrected bitrate, up to three total attempts.

The encoder streams media with `AVAssetReader` / `AVAssetWriter` outside the main actor. It does not upload video or read complete files into memory. Verify HDR tone mapping and every supported camera format on physical hardware before release.

## Advertising and consent

`FreeEntitlementProvider` supplies `adsEnabled`. `AdPolicy` decides eligibility; the compression service neither knows about nor waits for advertising. Google Mobile Ads uses official debug test IDs by default, displays a non-blocking banner in the progress state, and preloads a conservative interstitial for a later natural transition.

Google UMP refreshes consent each launch, presents a required form, then permits ads only when `canRequestAds` is true. Privacy options are exposed in Settings when required. Failed or unavailable consent/ads always fail open for video import and compression.

This configuration does not call `ATTrackingManager.requestTrackingAuthorization`; it does not require IDFA functionality. Before enabling a production advertising configuration, reassess ATT applicability, App Store privacy disclosures, SKAdNetwork entries, and consent messaging with the exact SDK versions and ad configuration in use.

## Release configuration and distribution

Copy `.env.example` to `.env` and supply signing, App Store Connect, Match, Google Ads, and Firebase App Distribution values. `.env` is intentionally ignored by git.

To provision AdMob resources without using the AdMob UI, enable the AdMob API in a Google Cloud project, create a **Desktop OAuth client**, then set `ADMOB_OAUTH_CLIENT_ID` and `ADMOB_OAUTH_CLIENT_SECRET` in `.env`. The local script uses a loopback OAuth callback to obtain a refresh token and is idempotent: it reuses the exact SendFit iOS app and matching ad units when they already exist.

```sh
bundle exec ruby scripts/provision_admob.rb authorize
bundle exec ruby scripts/provision_admob.rb provision
```

`apps.create` and `adUnits.create` are limited-access AdMob v1beta endpoints. If the provisioning command returns HTTP 403, your AdMob account must be enabled for these endpoints by its Google account manager; the script will not create duplicate resources or fall back to browser automation.

```sh
bundle install
bundle exec fastlane ios test
bundle exec fastlane ios firebase
bundle exec fastlane ios testflight_release
```

The Firebase lane distributes an ad-hoc build through Firebase App Distribution; SendFit does not include Firebase Analytics, Crashlytics, or a Firebase runtime SDK. The TestFlight lane uses Fastlane Match plus App Store Connect API-key credentials.

Before an archive, run `zsh scripts/verify_release_configuration.sh` (or append `firebase`) to list missing values without exposing any secret. If `bundle` unexpectedly runs `/System/Library/.../ruby/2.6`, initialize asdf in the current shell and run `asdf reshim ruby 3.3.7`; `command -v bundle` should then resolve to the asdf shim rather than `/usr/local/bin/bundle`.

Before final submission, run `asdf exec bundle exec ruby scripts/verify_app_store_submission_readiness.rb`. It uses the App Store Connect API key from `.env` to report missing App Store fields without revealing their values.

The public App Store policy, support instructions, and reviewer notes are in [docs/](docs/). The App Store record should use the GitHub-hosted privacy-policy file after this repository is published.

## Future monetization

No StoreKit code ships in this version. See [FUTURE_MONETIZATION.md](FUTURE_MONETIZATION.md) for the narrow future insertion point.
