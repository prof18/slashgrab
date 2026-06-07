# Testing and Release Plan

## TDD Policy

Slashgrab is built test-first.

- Add the failing unit/integration test before production code.
- For platform behavior that cannot be unit-tested cleanly, write the acceptance checklist or script first.
- A feature is not complete until the test/check proving it passes is committed.
- Regression fixes require a failing test or documented reproduction check first.

## Automated Tests

Unit tests:

- [x] POSIX path formatting.
- [x] Shell escaping.
- [x] Shell-escaped multiple paths joined as terminal arguments.
- [x] Double quoting.
- [x] File URL formatting.
- [x] Tilde replacement.
- [x] Multiple path joining.
- [x] History size cap.
- [x] Duplicate history behavior.

Integration-level checks where possible:

- [ ] Clipboard writer writes expected string.
- [ ] Drop reader extracts file URLs from pasteboard fixtures.
- [ ] Updater wrapper exposes `canCheckForUpdates` without requiring network in tests.

## Manual QA

Core flows:

- [ ] Drop one file.
- [ ] Paste default output after a Terminal command and verify spaces are handled correctly.
- [ ] Drop one folder.
- [ ] Drop multiple files.
- [ ] Drop a file with spaces.
- [ ] Drop a file with unicode characters.
- [ ] Drop a file with quotes in the name.
- [ ] Drop unsupported content.
- [ ] Copy recent item again.
- [ ] Change format and drop again.
- [ ] Quit and relaunch; settings persist.
- [ ] Quit and relaunch; recent copied path history persists.
- [ ] Duplicate copied output moves to top rather than creating a repeated row.
- [ ] Launch-at-login toggle persists.

Visual QA:

- [ ] Light mode.
- [ ] Dark mode.
- [ ] Menu bar on notched display if available.
- [ ] Long paths.
- [ ] Small screen.

Permission QA:

- [ ] Fresh install does not request Full Disk Access.
- [ ] Fresh install does not request Finder automation.
- [ ] Fresh install does not request notification permission.
- [ ] Sandboxed build accepts user-dropped files.

## Build Gate

Before handoff or release:

- [x] Build.
- [x] Unit tests.
- [x] Local run through `./Scripts/build_and_run.sh --verify`.
- [ ] Lint/format if tooling exists.
- [ ] Manual drop test.
- [ ] Manual clipboard verification.
- [ ] Manual Sparkle "Check for Updates" smoke test when release feed exists.
- [ ] Review permissions prompt behavior.
- [ ] Verify dev build and production build can be installed/running side by side.
- [ ] Verify dev history/settings do not pollute production history/settings.

## Distribution Options

### Direct Notarized Build

Decision: use this for the first release.

Pros:

- Faster.
- Better control.
- Easier if future advanced automation exists.

Cons:

- Need signing/notarization flow.
- Users must trust direct download.

### Mac App Store

Decision: not for the first release.

Pros:

- Easier trust/discovery.
- Handles updates/payment if monetized there.

Cons:

- Review delay.
- Sandbox behavior must be tested carefully.
- App Store metadata overhead.

## Signing and Identity

Production bundle identifier:

- `com.prof18.slashgrab`

Development bundle identifier:

- `com.prof18.slashgrab.dev`

Release package requirements:

- [ ] App IDs exist or are created through `asc` CLI.
- [ ] Signing certificates exist or are created/inspected through `asc` CLI.
- [ ] Sparkle public/private EdDSA keys exist.
- [ ] Sparkle public key embedded in app Info.plist.
- [ ] Nested Sparkle frameworks, XPC services, and helper apps are signed before the outer app bundle.
- [ ] Hardened runtime is enabled for Developer ID signing.
- [ ] Signed app.
- [ ] Notarized app.
- [ ] Stapled notarization ticket.
- [ ] Zip artifact named `Slashgrab-X.Y.Z.zip`.
- [ ] GitHub release contains the zip artifact.
- [ ] `appcast.xml` updated with `edSignature`.
- [ ] Production app name: `Slashgrab`.
- [ ] Dev app name: `Slashgrab Dev`.
- [ ] Dev and production builds can run alongside each other.
- [ ] Dev and production builds keep preferences/history separate.

Validation commands to use on release artifacts:

- `codesign -dvvv --entitlements :- Slashgrab.app`
- `codesign --verify --verbose=2 Slashgrab.app`
- `spctl -a -t exec -vv Slashgrab.app`
- `xcrun stapler validate Slashgrab.app`
- `plutil -p Slashgrab.app/Contents/Info.plist`

Keep architecture App Store-compatible where practical, but do not let App Store constraints drive the MVP.
