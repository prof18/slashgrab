# Slashgrab Plan Index

This is the source of truth for planning and future goal-driven development. Start here before changing scope or writing code.

## Product Decision

Name: **Slashgrab**

Tagline:

> Drop files. Grab paths.

One-sentence product:

> Slashgrab is a macOS menu bar utility that lets users drop files or folders onto a menu bar icon and instantly copies their filesystem paths to the clipboard.

## Current Status

- [x] App idea selected: menu bar file path copier.
- [x] Name selected: Slashgrab.
- [x] Initial market research reviewed.
- [x] Repository folder created at `/Users/mg/Workspace/Slashgrab`.
- [x] Planning docs created.
- [x] Product scope locked.
- [x] Bundle identifier decided: `com.prof18.slashgrab`.
- [x] Distribution decided: direct notarized build, no Mac App Store for first release.
- [x] Dev/prod side-by-side strategy decided.
- [x] Phase 0 scope decisions locked.
- [ ] Technical app scaffold created.
- [ ] MVP implemented.
- [ ] MVP manually tested on macOS.
- [ ] Release packaging decided.

## Plan Files

- [Product Brief](00-product-brief.md): positioning, users, non-goals, product opinion.
- [MVP Scope](01-mvp-scope.md): exact feature list and acceptance criteria.
- [Technical Architecture](02-technical-architecture.md): macOS implementation approach.
- [UI and UX Plan](03-ui-ux-plan.md): menu bar behavior, feedback, settings, icon direction.
- [Testing and Release Plan](04-testing-release-plan.md): build gate, manual QA, packaging.
- [Open Questions](05-open-questions.md): decisions to resolve before or during implementation.
- [Packaging and Updates](06-packaging-updates.md): Shellporter-style direct distribution with Sparkle updates.

## Development Phases

### Phase 0: Scope Lock

- [x] Decide minimum macOS version: macOS 13+.
- [x] Decide whether Slashgrab is menu-bar-only or also has a Dock/window presence: menu-bar-only accessory app.
- [x] Decide exact default path format: terminal-safe shell escaped.
- [x] Decide history size: 10 recent copied outputs.
- [x] Decide duplicate behavior: move duplicate output to top.
- [x] Decide history persistence: persist copied path text across relaunch.
- [x] Decide whether launch-at-login ships in MVP: yes.
- [x] Decide direct distribution first vs Mac App Store first: direct notarized build.

### Phase 1: Project Scaffold

- [ ] Create Swift macOS project.
- [ ] Use SwiftPM as the primary project entrypoint unless implementation discovers a strong reason for Xcode project scaffolding.
- [ ] Keep app menu-bar-first.
- [ ] Add `script/build_and_run.sh` for Codex/local run loop.
- [ ] Add `.codex/environments/environment.toml` Run action.
- [ ] Add Shellporter-style `Scripts/compile_and_run.sh` wrapper only if still useful after `script/build_and_run.sh` exists.
- [ ] Add basic unit-test target for path formatting.
- [ ] Verify local build.

### Phase 2: Core Drop-to-Clipboard

- [ ] Create AppKit status item.
- [ ] Add custom drop target view for the status icon.
- [ ] Accept file/folder URLs from pasteboard.
- [ ] Convert dropped URLs to selected path format.
- [ ] Copy output to `NSPasteboard.general`.
- [ ] Show success/failure feedback.

### Phase 3: Menu Bar Popover

- [ ] Show last copied path.
- [ ] Add copy-again action.
- [ ] Add recent history list.
- [ ] Add path format picker.
- [ ] Add launch-at-login toggle.
- [ ] Add quit action.
- [ ] Add settings entry point if settings do not fit in the popover.

### Phase 4: Polish

- [ ] Drag-hover visual state.
- [ ] Multiple file behavior.
- [ ] Long path truncation that preserves full copyable text.
- [ ] Accessibility labels.
- [ ] Light/dark mode pass.
- [ ] Error state for unsupported drops.

### Phase 5: Release

- [x] Production bundle identifier: `com.prof18.slashgrab`.
- [x] Development bundle identifier: `com.prof18.slashgrab.dev`.
- [x] App IDs/signing setup source: ASC CLI when needed.
- [x] Packaging/update model: Shellporter-style zip releases + Sparkle appcast.
- [ ] Create app icon.
- [ ] Add signing configuration.
- [ ] Add Sparkle dependency and updater.
- [ ] Add `appcast.xml`.
- [ ] Notarize direct build if distributing outside Mac App Store.
- [ ] Write release notes.
- [ ] Run full gate before handoff.

## Ground Rules

- Keep the app small and sharp.
- Do not add generic file-management features.
- Use TDD for the entire app: write the failing test or acceptance check before implementation.
- Do not require Full Disk Access for the core workflow.
- Do not require Finder automation permission unless a Finder-selection feature is added.
- Prefer SwiftUI for visible UI and AppKit only for platform edges SwiftUI cannot express cleanly.
- Every feature must make path copying faster, clearer, or more reliable.
- Default output should be pasteable into a terminal command without breaking on spaces.

## TDD Rule

Every implementation task should start by adding or updating one of:

- a unit test for deterministic logic
- an integration test for platform adapters where practical
- a scripted/manual acceptance check for AppKit, menu bar, Sparkle, signing, or notarization behavior that cannot be reliably unit-tested

Do not write production code for a behavior until the expected behavior is captured first.
