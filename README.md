# Slashgrab

Slashgrab is a small macOS menu bar utility for copying file paths.

Core promise:

> Drop files on the menu bar. Grab their paths instantly.

The project is currently in planning. Start with [plans/INDEX.md](plans/INDEX.md).

## Development Build

Build and verify the side-by-side dev app:

```bash
./script/build_and_run.sh --verify --test
```

Run it locally:

```bash
./script/build_and_run.sh
```

The dev build packages as `Slashgrab Dev.app` with bundle identifier `com.prof18.slashgrab.dev`, separate settings/history, disabled Sparkle checks, a `DEV` menu bar label, and a dev-badged app icon.
