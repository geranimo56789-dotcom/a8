# iOS CI (Unsigned IPA)

This repository includes a GitHub Actions workflow to build an unsigned iOS IPA on macOS runners and publish it as an artifact.

## Triggering the build

- On GitHub → Actions → "Build iOS (Unsigned)" → Run workflow.
- Optional inputs:
  - `flutter_channel`: stable (default), beta, master
  - `flutter_version`: specific version like 3.24.0 (optional)
  - `xcode_version`: e.g. 15.4 (optional)
  - `flavor`: your Flutter flavor name (optional)
  - `build_name`: semantic version (e.g., 1.0.0)
  - `build_number`: integer build (e.g., 1)

The job runs `flutter build ipa --no-codesign` and uploads:
- `ios-unsigned-ipa` (IPA file)
- `ios-xcarchive` (optional)

## Requirements

- iOS project present in `ios/` (run `flutter create .` if missing, then commit).
- If you use Firebase or other plist configs, commit `ios/Runner/GoogleService-Info.plist` or add a CI step to inject it from Secrets.

## Downloading artifacts

Open the workflow run → Artifacts section → Download `ios-unsigned-ipa`.

## Signing later

The IPA is unsigned. You can:
- Open the `.xcarchive` in Xcode and export with a development/adhoc/enterprise profile.
- Use fastlane `gym` + `match` to sign.
- Use a signing service.
