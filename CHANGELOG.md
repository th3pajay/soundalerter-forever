# Changelog

## 0.2.81 (beta)

First public beta on CurseForge. The options window was rebuilt in the dark flat look, page by page.

- New look and motion for every options page: Voice Alerts, Spell Finder, Developer Tools, Profiles and Advanced (custom alerts). Pages slide in, rows tint on hover, switches glide, a changed setting flashes its row.
- Voice Alerts: class list with counts, spell rows with event pills and a play button on every sound, presets with undo, silence-by-category cards and a Chat Alerts tab with a live message preview.
- Spell Finder: a draggable window with filter chips, keyboard control (Up, Down, Enter, Tab, Esc), a scrolling result list and a detail pane with Copy ID and insert-in-chat.
- Developer Tools: a health verdict for the spell database, a live rebuild progress bar, timing bars and a copy-diagnostics report.
- Profiles: every profile in one list with a summary, Use, Copy here and Delete (with a second-click confirm), New profile, Reset, and a "use for new characters" switch.
- Advanced: a custom alert list with a sectioned editor, spell ID lookup, Test sound, event chips and the source and destination filters under More options.
- Draggable flat scrollbars replace the old Ace3 slider; pages now fit the window.
- Options window badge reads BETA with the version and author.
- Fewer widgets per custom alert and quicker page building; 88 small Lua files folded into 72 with no change in behaviour.

## 0.2.77

- Options window motion: pages slide in, rows tint on hover, switches glide, a changed setting flashes its row, buttons dip when pressed, a failed import shakes. One setting in General turns it all off.
- Show hidden enemy spells: casts the client hides can show their real name and icon, drawn by the client.
- README credits Forever Simple GCD by tarolg (MIT) for the idea behind the hidden-spell display.

## 0.2.75

- Nine combo point celebration styles with their own exits for a spent and a lost combo, with Low, Normal and High animation quality.
- Casting bars: segmented look, fade-in, bloom on a finished cast, stamped INTERRUPTED, steel look for uninterruptible casts, a red timer flip and channel pulses.
- Spell tracker icons: pop-in, a border timer that shifts green, amber, red, a throb in the last 3 seconds, and a shine when a cooldown is ready.
- Configurable minimap button with a click matrix and 12 icons.
- Reordered options pages. /sa fxstats shows how often bars and icons update.

## 0.2.74

- Fixed the nearby count in proximity alerts when only your target or mouseover was around.
