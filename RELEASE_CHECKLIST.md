# SendFit release checklist

## Video and output size

- [ ] 4K 60 fps
- [ ] 1080p 30 fps
- [ ] 1080p 60 fps
- [ ] 120 fps
- [ ] Portrait and landscape
- [ ] HDR (verify no washed-out result)
- [ ] No-audio video
- [ ] 5-second clip
- [ ] 30-minute video
- [ ] Test 5 MB, 10 MB, 25 MB, 50 MB, 100 MB, and custom targets.
- [ ] Confirm every successful result satisfies `outputSize <= requestedMaximumSize`.
- [ ] Confirm cancel, disk-full, corrupt source, and source-disappeared errors are understandable.

## Import and sharing

- [ ] Import from Photos and Files (On My iPhone and iCloud Drive).
- [ ] From Photos, Files, and one other app: Share/Open a compatible video with SendFit, cold and warm.
- [ ] Verify the selected shared video is retained during consent initialization and uses the normal target screen.
- [ ] While compression is active, open another video and verify the safe “finish or cancel” error.
- [ ] Confirm only one external video is accepted and an unsupported file returns to the empty state.
- [ ] Save, Files export, and system Share result behavior.

## Advertising and consent

- [ ] Fresh install; consent required; consent not required; privacy-options entry point.
- [ ] Airplane Mode, unavailable inventory, banner success/failure, interstitial success/failure, and user dismissal.
- [ ] Rapid repeated compressions: no launch interstitial, none on the first two completions, and no back-to-back ads.
- [ ] Confirm no advertising failure prevents importing, compression, saving, or sharing.
- [ ] Test an entitlement fixture with `adsEnabled == false` and verify no banner/interstitial requests.

## Store review and operations

- [ ] Verify production AdMob app/ad-unit IDs and UMP configuration in `.env` / CI secrets.
- [ ] Review Google SDK version-specific privacy behavior, App Privacy answers, ATT applicability, privacy policy, and Info.plist declarations.
- [ ] Verify Fastlane Match/App Store Connect credentials; build a Firebase App Distribution ad-hoc IPA and a TestFlight archive.
- [ ] Test background/foreground behavior honestly; do not promise background compression.
