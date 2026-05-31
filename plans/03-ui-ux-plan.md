# UI and UX Plan

## Product Feel

Slashgrab should feel fast, quiet, and specific.

Avoid:

- Landing-page style screens.
- Big onboarding.
- Decorative UI that slows the utility down.
- Generic file-manager language.

## Menu Bar Icon

Icon direction:

- A forward slash `/` as the primary mark.
- Optional small grab/cursor/drop cue.
- Must work in monochrome template mode.
- Must read at menu bar size.

States:

- Idle.
- Drag hovering valid file.
- Drop success.
- Drop rejected.

## Drop Feedback

Required feedback:

- brief visual change on hover
- visible copied confirmation
- sound should be off by default

Possible feedback surfaces:

- temporary popover near the menu bar icon
- menu bar icon flash
- macOS notification only if user enables it

Recommendation:

- Use popover/inline feedback first.
- Avoid default notifications for every drop; that gets noisy.

## Popover Contents

MVP popover:

- Current format selector.
- Last copied output.
- Recent outputs list.
- Copy-again button per recent output.
- Clear history.
- Launch at login toggle.
- Settings.
- Quit.

Text behavior:

- Long paths should truncate visually in the middle.
- Full path should remain copyable.
- Use monospaced text for path display.

## Settings

Likely settings:

- Default path format.
- History size.
- Clear history.
- Launch at login.
- Show notification after copy, later and off by default.
- Include folders in same way as files.

Avoid in MVP:

- Custom transformation DSL.
- Complex templates.
- Cloud sync.
- Default macOS notifications on every copy.

## Accessibility

- Menu bar item has descriptive accessibility label.
- Drop target announces supported action.
- Buttons have clear labels.
- Visual feedback does not rely on color alone.
