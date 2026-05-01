# Code Signing & Distribution

This guide covers how to code-sign and notarize MacSmoothScroll for local development and public distribution. Most contributors do **not** need to read this — `make run` works without any signing setup.

Signing identities are loaded from `.env` (dev) and `.env.prod` (distribution). See `.env.example` for the full template.

## Development signing (`.env`)

Used by `make bundle` and `make install`. A stable self-signed identity lets macOS remember the Accessibility permission across rebuilds (ad-hoc signatures change every build and force you to re-grant).

```env
# Any name works — this is the Common Name of a self-signed cert in your Keychain.
# Defaults to "MacSmoothScroll Dev" if unset.
# Use "-" for ad-hoc (permission will reset every rebuild).
CODESIGN_IDENTITY=Your Name Local Dev
```

To create a reusable self-signed cert:

1. Open **Keychain Access → Certificate Assistant → Create a Certificate…**
2. Name: your chosen `CODESIGN_IDENTITY` value
3. Identity Type: Self Signed Root
4. Certificate Type: Code Signing
5. Save it in the **login** keychain

## Production signing & notarization (`.env.prod`)

Used by `make sign` to produce a Developer ID–signed, notarized bundle ready for public distribution.

```env
SIGN_IDENTITY=Developer ID Application: Your Name (TEAMID)
APPLE_API_KEY=/absolute/path/to/AuthKey_XXXXXXXXXX.p8
APPLE_API_KEY_ID=XXXXXXXXXX
APPLE_API_ISSUER=00000000-0000-0000-0000-000000000000
```

Values come from your Apple Developer account:

- `SIGN_IDENTITY` — the full string from `security find-identity -v -p codesigning`
- `APPLE_API_KEY*` — an App Store Connect API key (Users and Access → Integrations → App Store Connect API)

Then:

```bash
make sign   # build, sign with Developer ID, notarize, staple
make dmg    # package the signed .app into a distributable DMG
```

## Automated releases via GitHub Actions

The repo ships a workflow at `.github/workflows/release.yml` that signs, notarizes, and publishes a DMG whenever you push a tag like `v0.1.0`. You can also trigger it manually from the Actions tab (workflow_dispatch).

### Required GitHub Secrets

Add these 5 under **Settings → Secrets and variables → Actions** (Repository secrets):

| Secret | What to put in it |
| --- | --- |
| `CERTIFICATE_BASE64` | Base64 of your **Developer ID Application** `.p12` export. Generate with `base64 -i cert.p12 \| pbcopy`. |
| `CERTIFICATE_PASSWORD` | Password you set when exporting the `.p12` from Keychain Access. |
| `APPLE_API_KEY_BASE64` | Base64 of your App Store Connect API key `.p8`. Generate with `base64 -i AuthKey_XXXX.p8 \| pbcopy`. |
| `APPLE_API_KEY_ID` | The 10-character key ID. |
| `APPLE_API_ISSUER` | Issuer UUID from App Store Connect → Users and Access → Integrations. |

The signing identity name is auto-detected from the imported certificate, so you don't need to maintain it as a separate secret.

### Exporting the `.p12`

1. Open **Keychain Access** → find your "Developer ID Application: …" cert.
2. Right-click → **Export…** → choose `.p12`, set a password (this becomes `CERTIFICATE_PASSWORD`).
3. `base64 -i cert.p12 | pbcopy` and paste into the `CERTIFICATE_BASE64` secret.

### Cutting a release

```bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow will:

1. Import your cert into a temp keychain on the runner.
2. Run `make sign` (build → codesign with Developer ID → notarize → staple).
3. Run `make dmg`.
4. Upload `.dmg` + `.zip` as workflow artifacts.
5. Attach them to the GitHub Release matching the tag (auto-generated release notes).

The temp keychain and API key file are destroyed in the cleanup step regardless of outcome.
