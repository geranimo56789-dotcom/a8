## iOS signing + TestFlight upload setup

This repo includes a GitHub Actions workflow that builds a signed iOS IPA and uploads it to TestFlight. To use it, add the required secrets/variables and then run the workflow.

### What you need
- Apple Developer Program account (Team ID available in developer.apple.com)
- App Store Connect access to create an API Key
- An Apple Distribution certificate exported as a .p12 file (with password)

### Repository Variables (Settings → Variables → Actions)
Set these as repository-scoped Variables (or Environment Variables if you prefer):
- IOS_BUNDLE_ID: e.g. com.yourcompany.myapp
- IOS_DEVELOPMENT_TEAM: your 10-character Team ID (e.g. ABCDE12345)

You can also pass these as workflow inputs when dispatching, but variables are simpler.

### Repository Secrets (Settings → Secrets and variables → Actions → Secrets)
Add these secrets:
- IOS_CERT_P12_BASE64: Base64 of your Apple Distribution .p12
- IOS_CERT_PASSWORD: Password for the .p12 export
- APPSTORE_ISSUER_ID: Issuer ID from App Store Connect API Keys page
- APPSTORE_KEY_ID: Key ID from App Store Connect API Keys page
- APPSTORE_PRIVATE_KEY: The full contents of the downloaded .p8 file (begin/end PRIVATE KEY)

Notes:
- The workflow automatically downloads the App Store (distribution) provisioning profile using your API key and bundle ID. You do NOT need to upload a profile.
- The .p12 must be the Distribution (not Development) cert that matches your team.

### How to create/export the .p12 certificate
1) On a Mac, open Keychain Access → Certificates
2) Locate your “Apple Distribution: Your Name (TeamName)” certificate
3) Right-click → Export… → format: Personal Information Exchange (.p12)
4) Choose a password and save the file

If you need to create a new Distribution cert, use Certificates, Identifiers & Profiles on developer.apple.com, download, and import into Keychain, then export as .p12.

### Base64-encode .p12 on Windows (PowerShell)
Replace the path with your .p12 path. The output file cert.p12.b64 contains the base64 text you will paste into the secret:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\\path\\to\\distribution.p12")) | Set-Content -Path cert.p12.b64
Get-Content cert.p12.b64
```

Copy the entire text output into the secret IOS_CERT_P12_BASE64. Add the chosen export password into IOS_CERT_PASSWORD.

### App Store Connect API Key
- In App Store Connect → Users and Access → Keys → Generate API Key
- Download the .p8 and note the Key ID and Issuer ID
- Paste the .p8 contents (including the BEGIN/END lines) into the secret APPSTORE_PRIVATE_KEY
- Set APPSTORE_KEY_ID and APPSTORE_ISSUER_ID secrets accordingly

### Run the workflow
Once variables and secrets are set, start the workflow “Build and Upload iOS (TestFlight)” from the Actions tab. You can provide optional inputs:
- bundle_id, team_id, flavor, build_name, build_number

If not provided, bundle_id/team_id fall back to the repository variables IOS_BUNDLE_ID and IOS_DEVELOPMENT_TEAM.

### Outputs
- The job uploads your signed IPA to TestFlight
- Artifacts (IPA and XCArchive) are also attached to the run for debugging/download

### Troubleshooting
- Codesign errors: check that the .p12 is a Distribution cert, password is correct, and the Team ID matches
- Provisioning: ensure the bundle ID exists in your Apple Developer account; the workflow downloads the App Store profile automatically
- Missing secrets: the run will fail fast with a message indicating the missing item
