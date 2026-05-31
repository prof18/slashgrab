# Product Brief

## Product

Slashgrab is a tiny macOS utility that turns a dropped file or folder into copied path text.

Primary interaction:

1. User drags one or more files/folders.
2. User drops them onto the Slashgrab menu bar icon.
3. Slashgrab copies the path output to the clipboard.
4. Slashgrab shows confirmation and stores recent output.

## Positioning

Slashgrab should feel like a focused Mac utility, not a broad automation platform.

It competes against:

- Finder context menu path copy flows.
- Terminal drag/drop path insertion.
- Raycast/Alfred commands.
- Dropover/Dropzone-style drag-and-drop tools.
- PathSnagger-style Finder services.

The wedge is narrower:

> No command palette, no context menu, no intermediate action. Drop onto menu bar and paste.

## Target Users

- Developers pasting file paths into terminals, config files, bug reports, logs, scripts, docs, and prompts.
- Designers/support/QA people sending exact local file references.
- Power users who want path formatting without opening a larger launcher.

## Product Opinion

The app wins by being immediate and predictable.

Default behavior should be:

- Drop file.
- Copy POSIX path.
- Confirm quickly.
- Get out of the way.

## Non-Goals

- File shelf or temporary file holding.
- File transfer, upload, sharing, or cloud links.
- Finder replacement.
- Raycast/Alfred replacement.
- Script runner or automation platform in the first version.
- Persistent favorites or pinning.

## Naming

Chosen name: **Slashgrab**

Rationale:

- "Slash" hints at filesystem paths without using the crowded word "path".
- "Grab" describes the action.
- It is more distinctive than PathGrab.
- It avoids direct collision with PathSnagger, GrabPath, and Pathy.

Known caveat:

- `slashgrab.com` appears occupied by a GoDaddy landing page.

