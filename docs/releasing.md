# Releasing Slashgrab

## One-Time Setup

- Copy `.env.example` to `.env` and fill in Apple Developer ID, Team ID, notarization profile, and Sparkle keys.
- Install a Developer ID Application certificate locally.
- Store notarization credentials with `xcrun notarytool store-credentials`.
- Install Sparkle command line tools so `generate_appcast` is available.

## Release Flow

1. Update `version.env`.
2. Add release notes to `CHANGELOG.md` under the exact version.
3. Run `./script/build_and_run.sh --verify --test`.
4. Run `./Scripts/sign-and-notarize.sh`.
5. Create the GitHub release and upload `Slashgrab-X.Y.Z.zip`.
6. Run `./Scripts/make_appcast.sh Slashgrab-X.Y.Z.zip`.
7. Commit and push `appcast.xml`.

## Validation

Run these against the final app:

```bash
codesign -dvvv --entitlements :- Slashgrab.app
codesign --verify --verbose=2 Slashgrab.app
spctl -a -t exec -vv Slashgrab.app
xcrun stapler validate Slashgrab.app
plutil -p Slashgrab.app/Contents/Info.plist
```

Dev builds default to `Slashgrab Dev.app` with `com.prof18.slashgrab.dev` and disabled Sparkle checks. Production release scripts default to `Slashgrab.app` with `com.prof18.slashgrab`.
