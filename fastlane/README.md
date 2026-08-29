fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios test

```sh
[bundle exec] fastlane ios test
```

Run the full SendFit simulator test suite

### ios create_app

```sh
[bundle exec] fastlane ios create_app
```

Create the SendFit identifier and App Store Connect app record

### ios firebase

```sh
[bundle exec] fastlane ios firebase
```

Build an ad-hoc IPA and distribute it with Firebase App Distribution

### ios testflight

```sh
[bundle exec] fastlane ios testflight
```

Archive and upload a signed production build to TestFlight

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
