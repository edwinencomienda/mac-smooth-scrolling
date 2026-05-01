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
APPLE_TEAM_ID=TEAMID
```

Values come from your Apple Developer account:

- `SIGN_IDENTITY` — the full string from `security find-identity -v -p codesigning`
- `APPLE_API_KEY*` — an App Store Connect API key (Users and Access → Integrations → App Store Connect API)
- `APPLE_TEAM_ID` — from developer.apple.com → Membership

Then:

```bash
make sign   # build, sign with Developer ID, notarize, staple
make dmg    # package the signed .app into a distributable DMG
```
