# Changelog

## 0.2.83

Bar textures, a texture quality setting and a round of fixes. This also includes the unreleased 0.2.82 changes.

Bar textures
- New Liquid bar texture with a bevelled border: slow caustic light, a rippling surface and bubbles that float up.
- Motes is softer, with a gentler glow and a slower drift.
- Animated textures now run on vertical bars too (casting bars set to vertical). Waves still show a plain fill when vertical.
- New Texture quality setting (Low, Normal, High) on the Resource Bars and Casting Bars pages, under More options. Low drops the farthest layer and animates about 15 times a second. High adds a small glint that runs around the bar border.

Fixes
- Increase nameplate distance no longer resets your own nameplate distance to the game default at every login. Your value is remembered when you turn the option on and restored when you turn it off.
- Enemy statistics: at the 100-enemy cap a new enemy is no longer dropped the moment it is added.
- Minimap tracking: switching the feature off now restores the tracking you had before.
- A new enemy on a reused nameplate no longer inherits the old one's cast state, which could skip a "casting at you" alert or name the previous target's spell on an interrupt.
- The PvP zone type now refreshes when you walk into a sub-zone, such as a sanctuary.
- Custom alerts: the Summon and Damage events, which nothing ever raised, are no longer offered in the editor. Saved alerts and export strings are unchanged.
- Flag alerts: the 30-day expiry of the saved class cache now works, and the short-term duplicate filter no longer grows over a long session.
- Importing custom alerts no longer rebuilds every options page.
- Removed an unused learned-class cache and its old settings.

Performance
- The spell tracker only updates every frame while it has a timer or cooldown to show, and listens to combo point changes only when a finisher is tracked.
- Proximity and flag toasts, the watchlist, enemy targeting alerts, ally vision and the statistics cap do less work and create less garbage per event.
- The options window does less work while the spell database builds.

New
- /sa stats now shows alert diagnostics: the same spell alerted twice, aura resyncs and proximity checks skipped just after loading a zone. /sa stats reset clears them.

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
