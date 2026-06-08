# Releasing Slashgrab

## One-Time Setup

- Copy `.env.example` to `.env` and fill in the Developer ID identity, notarization keychain profile, and Sparkle keys.
- `SPARKLE_PUBLIC_ED_KEY` can be set directly, or `Scripts/package_app.sh --production` can derive it from `SPARKLE_PRIVATE_KEY_FILE`.
- Local production smoke runs through `Scripts/build_and_run.sh --production --release` may run without the key; they are ad-hoc signed and have Sparkle disabled.
- Install a Developer ID Application certificate locally.
- Store notarization credentials with `xcrun notarytool store-credentials`.
- `Scripts/make_appcast.sh` uses `generate_appcast` from `PATH` or from SwiftPM's `.build/artifacts/sparkle/Sparkle/bin/generate_appcast`.

## Release Flow

1. Update `version.env`.
2. Add release notes to `CHANGELOG.md` under the exact version.
3. Run `./Scripts/build_and_run.sh --verify --test`.
4. Run `./Scripts/build_and_run.sh --production --release --verify`.
5. Run `./Scripts/sign-and-notarize.sh`.
6. Create the GitHub release and upload `Slashgrab-X.Y.Z.zip`.
7. Run `./Scripts/make_appcast.sh Slashgrab-X.Y.Z.zip`.
8. Confirm `appcast.xml` contains an enclosure for `Slashgrab-X.Y.Z.zip` with `sparkle:edSignature`.
9. Commit and push `appcast.xml`.

## Validation

Run these against the final app:

```bash
codesign -dvvv --entitlements :- Slashgrab.app
codesign --verify --verbose=2 Slashgrab.app
spctl -a -t exec -vv Slashgrab.app
xcrun stapler validate Slashgrab.app
plutil -p Slashgrab.app/Contents/Info.plist
```

Dev builds default to `Slashgrab Dev.app` with `com.prof18.slashgrab.dev`, disabled Sparkle checks, separate settings/history, a `DEV` menu bar label, and a dev-badged app icon. Production package verification is explicit with `./Scripts/build_and_run.sh --production --release --verify`; release notarization uses `Slashgrab.app` with `com.prof18.slashgrab`.
