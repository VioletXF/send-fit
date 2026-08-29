# SendFit privacy overview

For the store-facing policy, see [APP_STORE_PRIVACY_POLICY.md](docs/APP_STORE_PRIVACY_POLICY.md).

## Your video

**Your videos never leave your device.** Video compression happens entirely on your iPhone or iPad. SendFit does not upload videos and does not operate a video-processing backend.

Videos chosen from Photos, Files, or a compatible external open request may be copied temporarily into SendFit-managed storage so AVFoundation can read them reliably. SendFit never overwrites or deletes a user-owned source. It deletes only its own temporary working files and outputs when safe to do so.

## Advertising and consent

SendFit includes Google Mobile Ads. Advertising network requests may use the network and process information under Google’s SDK behavior and the user’s consent choices. Google User Messaging Platform (UMP) obtains and updates consent information, presents required forms, and exposes privacy options when UMP requires them.

SendFit does not claim that it never uses the internet. The app’s video-processing feature remains available offline and when advertising is unavailable.

## Before App Store submission

Review App Privacy disclosures, UMP message configuration, Google SDK release notes, production ad configuration, SKAdNetwork requirements, and ATT applicability against the exact archived build. This document is product guidance, not legal advice.
