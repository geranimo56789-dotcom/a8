# iOS CI/CD Overview

This document summarizes the automated iOS build and TestFlight upload setup present in this repository.

## Workflows

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| Manual Upload | `.github/workflows/upload-ipa.yml` | `workflow_dispatch` | Upload an existing signed IPA from a release asset to TestFlight using App Store Connect API key. |
| Release Auto-Upload | `.github/workflows/auto-upload-testflight.yml` | `release: published` | Automatically upload a signed IPA asset attached to a newly published GitHub Release. Captures transporter log and summary. |
| Build & Upload (Tag) | `.github/workflows/build-and-upload-ios.yml` | `push` tag `ios-*` | Build, sign, export, upload IPA, and create/update release with metadata. Validates tag vs `pubspec.yaml` version. |
| Version / Build Bump | `.github/workflows/bump-ios-build.yml` | `workflow_dispatch` | Increment build number or patch version in `pubspec.yaml` and optionally commit. |
| Validate Config | `.github/workflows/validate-ios-config.yml` | `workflow_dispatch` | Check required secrets, optionally inspect a release IPA. |

## Required Secrets

| Secret | Used In | Description |
|--------|---------|-------------|
| `APPSTORE_KEY_ID` | All upload steps | App Store Connect API key ID. |
| `APPSTORE_ISSUER_ID` | All upload steps | App Store Connect issuer ID. |
| `APPSTORE_PRIVATE_KEY` | All upload steps | Full `.p8` contents (BEGIN/END lines included). |
| `IOS_DIST_CERT_B64` | Tag build workflow | Base64 encoded distribution `.p12` file. |
| `IOS_DIST_CERT_PASSWORD` | Tag build workflow | Password for the `.p12` file. |
| `IOS_PROVISION_PROFILE_B64` | Tag build workflow | Base64 encoded `.mobileprovision` file. |
| `APPSTORE_ITC_PROVIDER` (optional) | Release auto-upload / build | Provider short name if multiple providers exist. |

## Adding Secrets
GitHub → Repository Settings → Secrets and variables → *Actions* → *New repository secret*.

For base64 generation (macOS):
```bash
base64 -i distribution.p12 > dist.p12.b64
base64 -i var6.mobileprovision > profile.mobileprovision.b64
```
PowerShell:
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\to\distribution.p12")) > dist.p12.b64
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\to\var6.mobileprovision")) > profile.mobileprovision.b64
```
Paste file contents into the relevant secrets.

## Tag Workflow Version Matching
Tags must match `ios-x.y.z`. The workflow checks that `pubspec.yaml` `version:` prefix (`x.y.z`) equals the tag’s semantic part before building.

## IPA Selection (Release Auto-Upload)
Priority order when multiple assets present:
1. `*-signed.ipa`
2. `Runner-signed.ipa`
3. First `*.ipa` found

Both the manual and release auto-upload workflows now perform a distribution signature check (verifies `Authority=Apple Distribution`) before attempting upload.

## Artifacts & Summaries
- Transporter log: `transporter-log-<tag>` artifact (release auto-upload)
- Build & upload adds structured release notes with bundle id, version, build number.
- `build-metadata-<tag>`: JSON metadata artifact.
- Optional Slack notifications (if `SLACK_WEBHOOK_URL` secret present) provide success/failure summary.

## Common Failures & Resolutions
| Issue | Cause | Fix |
|-------|-------|-----|
| API key invalid | Missing BEGIN/END or wrong key | Re-paste full `.p8` content |
| Version mismatch | Tag doesn’t match `pubspec.yaml` | Update tag or bump `pubspec.yaml` |
| No IPA found | Release lacks IPA asset | Attach IPA and re-publish |
| Transporter failure | Auth / signing / provider | Inspect transporter log artifact |
| Build rejected | Duplicate build number | Increment build number after `+` in `pubspec.yaml` |

## Manual Upload Flow
1. Sign and attach IPA to a release.
2. Run manual workflow specifying tag + IPA filename.

## Full CI Flow
1. Update `pubspec.yaml` version & build number.
2. `git tag ios-1.2.3 && git push origin ios-1.2.3`.
3. Workflow builds, signs, uploads, creates/updates release.
4. Monitor TestFlight processing in App Store Connect.

## Extensible Enhancements (Not Yet Implemented)
- Notifications (Slack/Discord/webhook).
	- Slack basic webhook is implemented (success/fail). Extend to Discord by adding another step.
- Automatic build number incrementing.
	- Basic bump workflow implemented (patch/build). Could extend to semantic minor/major.
- Poll & await App Store processing.
- Parallel test matrix before upload.
- Vulnerability / license scanning gate.

## Maintenance Tips
- Rotate distribution certificate periodically.
- Validate that your IPA is distribution-signed (`Apple Distribution`)—workflow enforces this now.
- Remove old API keys you no longer need from App Store Connect.
- Audit secrets via GitHub repository settings regularly.
- Keep Xcode version in workflows updated as macOS runners evolve.

## Troubleshooting Checklist
1. Secrets set? (Check Actions run log for early failures.)
2. Tag format correct? (`ios-x.y.z`)
3. Build number unique? (App Store Connect: TestFlight → Build metadata.)
4. Provision profile matches bundle id/team? (`nodomain.var6`, `K68A6FQABT`)
5. Transporter log errors? (Look for HTTP status / authentication lines.)

---

Feel free to extend this doc as the pipeline evolves.
