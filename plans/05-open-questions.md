# Open Questions

Resolve these before or during Phase 0.

## Product Scope

1. Minimum macOS version?
   - Decision: macOS 13+.

2. Menu-bar-only or regular Dock app too?
   - Decision: menu-bar-only accessory app.
   - Dev build can show a visible dev indicator, but should keep the same core app behavior.

3. History size?
   - Decision: 10 recent copied outputs.

4. Should duplicate paths be moved to the top or repeated?
   - Decision: move existing duplicate to top.

5. Should history persist across relaunch?
   - Decision: yes, but only copied path text.

## Path Behavior

6. Default format?
   - Decision: shell escaped, because default output should paste cleanly into Terminal.

7. Should dropped multiple files use newlines or spaces?
   - Decision for default format: spaces, so dropped files paste as shell arguments.
   - Recommendation for list-style formats: newlines.

8. Should shell-escaped multi-file output be space-separated for terminal commands?
   - Decision: yes for the default format.

9. Should symlinks resolve?
   - Decision: no by default; copy the path the user dropped.

10. Should app support file URLs in MVP?
   - Decision: yes.

## UX

11. What should the icon be?
   - Decision: crisp slash mark with subtle document/drop cue.

12. Should successful copy trigger a macOS notification?
   - Decision: no by default; optional setting later.

13. Should clicking the menu bar icon open a popover or menu?
   - Decision: popover/window-style menu because recent history and format controls need more room than a plain menu.

## Release

14. Bundle identifier?
   - Decision: production uses `com.prof18.slashgrab`.
   - Decision: development uses `com.prof18.slashgrab.dev`.
   - Dev/prod should be installable and runnable side by side.

15. Distribution first?
   - Decision: direct notarized build first, no Mac App Store for first release.

16. Monetization?
   - Decision: defer. Build MVP first; do not add licensing/payment code now.

17. Launch at login in MVP?
   - Decision: yes.

18. App IDs and signing setup?
   - Decision: use `asc` CLI when needed.
   - Assumption: certificates likely already exist.
   - If App IDs or signing assets are missing, inspect/create them with `asc`.

19. Sandbox?
   - Decision: direct notarized distribution is the release target.
   - Implementation preference: keep the app compatible with sandboxing if low cost, but do not let App Store-specific constraints drive the MVP.

## Later Feature Candidates

- Finder selection copy.
- Global shortcut.
- Custom templates.
- Short path aliases.
- Copy basename/dirname.
- Drag into opened popover as alternative to icon drop.
- Share extension.
- Raycast extension companion.
