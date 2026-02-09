# SilentStore

SilentStore is a private vault for photos, videos, and documents. Files are encrypted on-device, organized with folders, and protected by biometric unlock plus an app passcode.

## Features
- On-device encryption for all stored files
- Face ID / Touch ID unlock with app passcode fallback
- Folder organization with move, share, and delete actions
- Recent items and pinned section
- Modern media viewer with swipe navigation
- Local-only AI tagging for images
- Arabic and English localization

## Requirements
- macOS 26+
- Xcode 26.2+
- iOS 26.2+ device or simulator

## Setup
1. Open `SilentStore.xcodeproj` in Xcode.
2. Select the `SilentStore` target.
3. Configure **Signing & Capabilities** with your team and bundle ID.

## Build & Run
- From Xcode: select a device and press **Run**.
- From terminal:
  ```sh
  xcodebuild -scheme "SilentStore" -configuration Debug -destination 'generic/platform=iOS' build
  ```

## Security Model
- Files are encrypted using AES-256.
- The master key is stored in Keychain and protected by Secure Enclave.
- App passcode can unlock the vault if biometrics are unavailable.
- No data is uploaded to external servers.

## Localization
Strings are available in:
- English (`en`)
- Arabic (`ar`)

## Notes
- The app stores encrypted files in the app sandbox.
- Deleting all data removes encrypted files, metadata, and passcode.
