# MVP Scope

## MVP Promise

Slashgrab copies file paths from a menu bar drop with no extra click.

## Development Rule

Build the MVP with TDD.

- Path formatting, history, settings, clipboard service boundaries, and drop parsing need tests before implementation.
- UI/platform behavior needs acceptance checks before implementation when unit tests are not practical.
- Bug fixes need a failing test or reproducible acceptance check first.

## Required Features

- [x] Menu bar icon is always available while app is running.
- [x] User can drop one file onto the menu bar icon.
- [x] User can drop one folder onto the menu bar icon.
- [x] User can drop multiple files/folders onto the menu bar icon.
- [x] Paths are copied to the clipboard immediately.
- [x] Multiple paths in the default shell-escaped format are copied as space-separated terminal arguments.
- [x] Multiple paths in list-style formats are copied as newline-separated text.
- [x] App shows visible success feedback after copying.
- [x] App shows visible failure feedback for unsupported drops.
- [x] App stores recent copied outputs.
- [x] App menu/popover lets user copy recent output again.
- [x] App menu/popover lets user toggle launch at login.
- [x] App menu/popover exposes quit.

## MVP Path Formats

Recommended MVP formats:

- [x] POSIX path: `/Users/mg/Desktop/file name.txt`
- [x] Shell escaped path: `/Users/mg/Desktop/file\ name.txt`
- [x] Double-quoted path: `"/Users/mg/Desktop/file name.txt"`
- [x] File URL: `file:///Users/mg/Desktop/file%20name.txt`
- [x] Tilde path: `~/Desktop/file name.txt`

Minimum viable subset if we want to ship fast:

- [ ] Shell escaped path.
- [ ] POSIX path.
- [ ] Double-quoted path.

## Suggested Defaults

- Default path format: shell escaped.
- Multiple-item separator for the default format: spaces, so multiple dropped files paste as terminal arguments.
- Multiple-item separator for text/list formats: newline.
- Recent history size: 10.
- Duplicate history behavior: move existing output to top.
- History persistence: persist copied path text across relaunch.
- Confirm feedback duration: 1.5 seconds.
- Menu bar-only app by default.
- Minimum macOS version: macOS 13+.
- Launch at login: ship in MVP.

## Acceptance Criteria

- [ ] Dropping `/Users/mg/Desktop/Test File.txt` copies exactly the selected format.
- [ ] Default copied output for `/Users/mg/Desktop/Test File.txt` is `/Users/mg/Desktop/Test\ File.txt`.
- [ ] Dropping a folder copies the folder path, not its contents.
- [ ] Dropping multiple items preserves item order when the pasteboard provides stable order.
- [ ] Default copied output for multiple dropped files can be pasted after a terminal command as arguments.
- [ ] Paths with spaces copy correctly in every supported format.
- [ ] Paths with quotes, apostrophes, and non-ASCII characters copy correctly.
- [ ] App never asks for Full Disk Access for the basic drop workflow.
- [ ] App remains useful without a main window.

## Out of MVP

- Finder selection copy.
- Global keyboard shortcuts.
- Custom prefix/suffix rules.
- Custom separators.
- iCloud sync.
- App Store-specific metadata.
- Advanced automation.
- Favorites/pinning.
- Notifications by default.
