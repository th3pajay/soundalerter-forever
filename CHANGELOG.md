# Changelog

## 0.2.88

Casting bars
- The Solid, Fog and Default bar looks now each come with their own matching cast animations. Solid has a bright edge line on the fill, a wipe-in at cast start, a white flash on finish and a red border pulse in the last 0.7 s. Fog gets a cold storm tint (with lightning flashes on High), a pop-in, corner brackets for uninterruptible casts and a grey fizzle with falling embers when a cast is cancelled. Default has a spark riding the fill edge, a fade-in and the plain green finish. The other textures keep the animations they had.
- The stamped INTERRUPTED stays the same on every look. Channelled spells now show three tick marks on the bar that dim as each tick passes, if channel pulses are on.
- The segments overlay is still its own setting and draws on top of any look. Low skips the edge line, spark, lightning, rings, glows and embers and keeps a single border pulse; High adds the extra layers. Nothing in your saved settings changes.
- The bar texture names in the picker are shorter: Default, Solid and Transparent.
- Transparent is now actually transparent: a faint fill inside a clear frame with no dark backing, so you can see the game through the bar. Before, it dimmed the whole bar but every cast reset that, so it looked the same as Solid. This applies to the resource bars too. Restart the game once (a reload is not enough) so the client picks up the new texture file.

## 0.2.87

Spell Finder
- The spell database now covers far more spells. The scan used to stop at spell ID 70,000, which left out about 15,000 spells that exist on the game client, among them the newer-style spells and many of the spells in this addon's own alert list (30 of them could not be found). It now scans IDs 1 to 520,000 and 1,150,000 to 1,400,000, skipping the stretch in between where the client has no spells, and the database holds about twice as many spells. The scan was checked on the live client first: every ID in the new range was read without a single error or crash.
- Your saved spell database is rebuilt once, automatically, the next time you open the Spell Finder or Developer Tools, because the old one only covers the old range. The scan takes about 20 to 40 seconds in the background. The range is saved with the database, so a future range change rebuilds it the same way.
- The scan is faster per ID: it no longer wraps every single ID in a protected call. If a chunk of the scan ever raises an error, that chunk is repeated one ID at a time and an ID that keeps failing is skipped, so one bad spell cannot stop the build. Spell ranks are only looked up for the old ID range, where they exist.
- Developer Tools: the Database card counts the IDs actually scanned (770,001), the density figure uses that count, and the scan range line notes that the empty stretch is skipped.

## 0.2.86

Party sharing
- New Party sharing group on Proximity Alerts, with two switches that are both off by default. Share alerts with your group tells group members who run SoundAlerter when your own stealth, proximity or watchlist alert fires. Hear alerts from your group plays theirs for you, with a Play button on the switch.
- Shared alerts follow your own settings: the stealth spell switches, the proximity zones and quiet rules, the watchlist switch and the zone gate all still apply, and an alert you already heard for the same enemy is not repeated. Proximity alerts from the group show as Spotted, with the sender's name, and use the same distance limit as enemies your group targets.
- Alerts you receive are never sent on to others or to chat, each kind is shared at most once per enemy every ten seconds, and the rows are hidden on a client without addon messages.
- Proximity Alerts zone and distance checks were moved into shared code so local and shared alerts use the same rules; nothing changes for local alerts.

Profiles
- The Profiles page now shows one profile at a time on a large card, with a strip of all your profiles under it. Click a profile in the strip to look at it; the card shows which characters use it, whether it is the active or the new-characters profile, where its spell alerts reach, which modules are switched on, and its custom alert and spell alert counts. Each profile gets its own colour and initials from its name.
- Duplicate makes a named copy of any profile in one click without switching to it. Rename changes a profile's name, including the active one, and keeps the characters that use it. Export puts a profile into a text you can copy and share, and Import text turns a pasted export into a new profile; statistics and the class cache are not exported, and an import never changes your active profile.
- Copy here, Delete and Reset still ask for a second click. The page works out each profile's summary only when you look at it, and again only after something changed.

Statistics
- The right side of the Statistics page is now a Snapshot panel with three tabs instead of only repeating the hover text (the hover text is still shown under it). Now shows this session against your average, party sharing and your most recent rival. Trends shows alerts per day for the last 14 days, the busiest hours and the spells that are rising or falling. Rivals ranks your most frequent enemies with their danger level and the classes that come back most.
- Party sharing is counted: how many alerts you shared with your group and how many you heard from them, for this session and all-time, and who helped you most. Alerts you heard from the group were already counted in their normal categories (proximity, spell alerts, watchlist) and still are.
- Daily and hourly activity is recorded from now on, as 14 daily numbers and 24 hourly numbers, so the Trends tab fills in as you play. The rising and falling spells appear once you have a few sessions with spell alerts.

Memory
- The spell database now uses about 2.3 MB less memory at rest (measured on a 16,544 spell database). Each spell used to be its own small table; they are now two plain lists, which also makes the saved file smaller and searches about 15 to 30 percent faster. Your existing database is converted the first time you log in with this version, with no rebuild.
- The lowercase name list (about 0.6 MB) and the build-time name index (about 0.5 MB) are no longer kept while the Spell Finder is closed; the finder rebuilds the lowercase names in a few milliseconds when you open it.
- Search results no longer carry duplicate fields, which makes each result row about 40 percent smaller, and the search cache is limited to 4,000 rows in total (it was ten searches of any size, which for a short search term could be several MB). A result too large to keep is simply searched again.

Spell Finder
- The Spell Finder window now opens beside the options window instead of behind it. It sat in a lower layer than the options window, so any overlap hid it, and a position saved from an earlier drag could put it right on top of the options. With the options window open it now always opens on its right side, on the left side when there is not enough room on the right, and you can still drag it anywhere afterwards. Your saved position is used when the options window is closed.
- Developer tools: the window no longer jitters while the database rebuilds. A timer redrew the whole options window twice a second during a rebuild, which made the page slide in again each time; it is gone, because the page already updates itself once a second. The same redraw ran every few batches while the spell description index was built and is gone too. A page that is redrawn and re-shown at once no longer slides in. The page now refreshes with the addon's own timer, like the rebuild itself, and keeps running through a redraw, so the progress keeps moving. The status strip under the title also kept moving as the percentage, spell count and memory changed width; the items now keep their widest width while a rebuild runs and the strip is only laid out again when something actually changed.
- Developer tools: a progress bar now appears under the status line while the database rebuilds and disappears when it finishes. It replaces the bar that used to sit, hidden, inside the Database card, so that card is shorter.
- Developer tools: Open Spell Finder is now a full-width tile at the top of the Spell Finder card, with a book icon, a one-line description and an arrow. Its left edge lights up in the accent colour when you hover it. Clicking it again closes the window: while the Spell Finder is open the tile reads Close Spell Finder, and it follows the window if you close it another way.

## 0.2.85

Stealth alerts, and a round of fixes.

Stealth alerts
- Enemy Stealth, Prowl, Vanish and Shadowmeld are now announced when the aura appears, which works even though the client hides the cast. Until now these call-outs never fired for enemy players because their spell ID is hidden. They use the same per-spell switches and voice files on the Voice Alerts page, and the chat announcement uses the same Stealth, Prowl and Vanish switches.
- One alert per enemy: the target and its nameplate no longer play the call-out twice, and an enemy that was already stealthed when you first saw it stays silent.
- Proximity Alerts, new Stealth group: Alert for stealthed enemies already in view plays one alert when an enemy comes into view already stealthed. Keep watch on a stealthed enemy closing in repeats the alert each time that enemy gets closer, with a Keep watch within band and a Time between alerts. Both are off by default. Nameplates need All enemies in range under Who triggers alerts on Quick Start.
- Rogue Stealth and the druid stealth are confirmed in game. The other ranks and Prowl, Vanish and Shadowmeld use the IDs from the game's spell list and may need adjusting.
- The distance bands no longer call a protected game function in combat, which could log a blocked-action error; in combat the Close and Nearby bands are skipped, so a distance reads Medium or Detected.

Fixes
- Spell Finder: with Autocomplete on, the suggestion list no longer closes about a tenth of a second after you type. It now stays open while the results update and closes when you press Enter. Clicking a suggestion with the mouse now completes it.
- Statistics: the Top Spells percentages are now each spell's share of the listed spell alerts, matching the Enemies and Classes lists. They were measured against every alert of any kind, so they read 0% to 1% for nearly everything.
- Notices: the page is grouped into Requests (duel, summon, resurrection, group invite), Queues (queue ready, ready check) and Warnings (low durability, with its threshold right under it). Each notice has its own Play button next to its switch, which replaces the seven separate Test rows. A notice with no voice file shows "No file" on its button instead of staying silent. A new Play all button plays every notice once. Each description is now one short line about when it fires, without the voice file name.
- Battleground Alerts: each flag event (pickups, drops, captures, returns) has its own Play button beside its switch, which plays the class voice and then the event phrase. A Preview class choice sets which class voice the buttons use, and Play all runs every event once. The three linked team switches (only enemy, only friendly, all actions) are now one Alert for choice: Enemy team, Friendly team or Both teams; your saved settings carry over. The Test flag toasts row is gone: the Show toast notifications row has its own Play button instead.

- Proximity Alerts: the Show toast notifications switch has its own Play button, which replaces the Test toast row. The Enemy targets you, Enemy casts while targeting you, Enable watchlist and the two new stealth switches have a Play button too, like the Notices and Battleground Alerts pages. A voice file that is missing shows No file on the button.
- Proximity toasts: Shift+click now sets the enemy as your focus without changing your target. It used to leave the enemy targeted. Your previous target is put back, or cleared if you had none.

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
