# cricket_ultimate_manager

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Codemagic: Build iOS IPA

This project includes a Codemagic workflow in `codemagic.yaml`:

- Workflow ID: `ios-ipa-adhoc`
- Output: `build/ios/ipa/*.ipa`

### 1) Connect repository in Codemagic

- Add this repository in Codemagic.
- Open **Environment variables** for the app/workflow.

### 2) Add required secrets (group: `app_store_credentials`)

Create an environment variable group named `app_store_credentials` and add:

- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_IDENTIFIER`
- `APP_STORE_CONNECT_PRIVATE_KEY` (contents of `.p8` key)
- `CERTIFICATE_PRIVATE_KEY` (private key used to generate signing certificate)

### 3) Set bundle identifier

In `codemagic.yaml`, set `BUNDLE_ID` to your real iOS bundle identifier (must match Xcode project and Apple Developer App ID).

### 4) Run build

- Start workflow `ios-ipa-adhoc` from Codemagic.
- Download the generated IPA from artifacts.

If you want TestFlight/App Store upload, switch signing type from ad hoc to App Store and add publishing to App Store Connect.
