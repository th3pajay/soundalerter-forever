# Changelog

## 0.2.91

## Broom and sweeps - 

Global sightings
- The zone panel is now a slim strip on the right edge of the map: a verdict-coloured edge, the enemy count, the change against the 5 minutes before and a vertical class bar. It slides open into the full list while the mouse is over it and collapses when you move away, so it no longer covers the map. Click the open panel's title to switch between 3 and 8 rows; your choice is still saved.
- Continent and world view: the zone badges are replaced by one small ring per zone. Its 12 segments are split by class share, the enemy count sits in the middle, a red mark shows when higher-level enemies are present, and rings with 5 or more enemies pulse (Normal and High detail). Rings that would overlap merge into one with the combined class mix, and hovering it lists the zones inside.
- The zone panel reads the sightings once per refresh instead of twice.

Quick Start
- Quick Start is now a six-step setup wizard in place of the long checklist: Style (the Arena, Battleground and Everything presets, zones and who triggers alerts), What to hear (the seven alert types with master volume and a test sound), On-screen helpers (Casting Bars, Spell Tracker, Cast Feed, Resource Bar), Awareness (proximity toasts, battleground flag alerts, stealth alert, global sightings), Party sharing and a summary. A progress bar shows where you are; Back and Next move between steps, and every switch applies at once.
- On a new install the wizard opens by itself in its own window a few seconds after login. Skip setup, the close button or Escape ends it for good, and existing installs are never asked. Run it again any time from the Quick Start page, which is the same wizard filled with your current settings, or with `/sa setup`.
- Party sharing, global sightings and the Spell Tracker step only appear where they apply: sharing needs a client that supports it, and the tracker needs tracked spells. Proximity toasts turn on for the zones you picked.

Cast Feed
- Icons have rounded frames with a soft glow in the status colour, a clock sweep while the cast is in progress and a small badge once it ends: a check for a cast, a cross for an interrupt and a waiting mark for a cancelled one.
- Casts by your target, focus, party and nearby enemies carry a class-coloured dot, and the same spell cast again within 3 seconds stacks into one icon with a count such as x2.
- A faint baseline runs under the icons while a row has casts, and the time between casts reads short, such as 1.4s.
- Icons fade in, and fade out over the last stretch of the row instead of vanishing. A new Animation quality setting scales this: Low turns every icon animation off, Normal adds the fade-in, the sweep and the end fade, and High adds a settle on arrival, a pulse on success and a shake on interrupt. Baseline and Class marker have their own switches.

Trinket Menu
- New experimental Trinket Menu page under Displays, off by default. Your two trinkets sit on a small bar with rounded, softly glowing frames, a cooldown sweep and the seconds left in the corner. Click a trinket to use it, or bind keys under Key Bindings > AddOns > SoundAlerter.
- Hover a trinket to open the trinkets in your bags and click one to equip it into that slot. Right-click a trinket to swap top and bottom.
- A third button in its own colour holds three saved trinket sets: click to equip the selected set, right-click or scroll to pick another, Shift-click to save the pair you are wearing.
- Swaps and set changes made in combat wait and glow orange until combat ends, then run by themselves. Moving the bar and layout changes also wait for the end of combat, so the menu never touches protected frames in combat.
- A new gear set button, off by default, switches between two equipment sets you made in the character panel, for example damage and healing gear. Pick a main and an alternate set on the page, then click to swap to the one you are not wearing, or right-click for a list of all your sets. It has its own key binding.
- Gear swaps made in combat wait and glow orange like trinket swaps and equip in one go once combat ends. Click again in combat to cancel. The newest request wins, so a trinket swap replaces a waiting gear set and the other way round.
- Vertical or horizontal, bottom trinket first, icon size and spacing, fade when idle, and collapse into a small diamond that opens the bar on hover, also in combat.

Fixes
- Enemy toasts no longer raise a Lua error when the enemy's buffs are hidden by the game, for example in a duel. The buff icons still show; only the time left is left out.
- The arena drinking alert now finds the drink buff on this client. Its lookup also no longer errors when buff names are hidden.
- Changing the nameplate range setting in combat now waits until combat ends instead of being blocked by the game.
- Clicking an enemy toast that was shown during combat now just closes it, instead of trying a target change the game blocks.
- Enemy and flag toasts now show up after a reload during combat. Before, they stayed missing until the fight ended.
- Flag toast target macros now strip line breaks from names, like enemy toasts already did.

## 0.2.90

## Hammers and nails - brace for live

Global sightings
- Shared sightings now also show on the minimap: a class-coloured dot for each enemy reported around you, fading with age and dimmer while only one player has reported it. Enemies just beyond the minimap's edge sit on the rim as smaller, fainter dots, so you can see which way they are. The dots turn with a rotating minimap, and hovering one shows the same details as on the world map. New "Show on the minimap" switch under Global sightings, on by default. World map detail sets how many dots: 15, 30 or 60.
- A confirmation now belongs to a place. If one player moves an enemy more than two map squares from where it was confirmed, or onto another map, it shows dimmed again until a second player or you see it there. Moving it a little at a time does not get around this.
- A report that gives a known enemy a different class or name is refused and counts against the sender. Your own sighting can still correct it.
- `/sa global mute <name>` is now saved and applies to all your characters, up to 200 (oldest dropped first). `/sa global` lists who you muted.
- When the list of automatically ignored senders is full, the oldest entry now makes room instead of new offenders getting through.
- When the game slows down addon messages, sightings wait a few seconds instead of counting it as a failure. After repeated real send failures they pause, say so once in chat, and try again every minute instead of staying off until you reload.

Party sharing
- After repeated send failures, sharing now pauses, says so once in chat, and tries again every minute instead of staying off until you reload. Messages the game slowed down no longer count as failures.
- An enemy a group member reports now plays a soft two-note tone instead of the class voice and "detected", so you can tell a teammate's sighting from your own. The toast still says who spotted them. The play button next to "Hear alerts from your group" plays the new tone.
- A watched player reported by a group member now only alerts when that name is on your own watchlist. Before, a teammate's watchlist could set off your watchlist sound.

Voice alerts
- The Spell Alerts list is now a compact grid of spell tiles: tick a tile to switch all its alerts, or click its number badge to open the single events with their sounds and play buttons. Hover a tile for the game's spell tooltip. A row of filters on top (All, Gained, Faded, Cast, On you and so on) shows only the spells with that event, and then a click, All on and All off work on that event alone. A tile with only some events on shows a green edge.
- "Interrupts on you" in the Other list now only covers you being interrupted. The "friend countered" voice, for Counterspell landing on a friend, was mixed into it under the same switch; it is now the On friend event on Mage > Counterspell, with its own switch. If you had switched it off, both start off.
- Eight new spells, each checked against the Forever spell database. When an enemy gains Divine Favor, Cheat Death or Fade, and Thorns or Aspect of the Wild (these two are off by default, enemies keep them up all the time); when Vampiric Embrace, Riposte's disarm or Garrote lands on you.

Casting bars
- New padlock on the bar while a cast cannot be interrupted, including enemy casts on your target and focus. The game itself decides whether the lock shows for enemies, since addons cannot read that flag, and it follows a cast that gains or loses its shield midway. On by default; "Show a lock on casts you cannot interrupt" under Casting Bars turns it off.

Chat alerts
- In a battleground, chat alerts are no longer posted twice when both Party and Battleground are ticked. Battleground chat already reaches your party, so Party and Raid are skipped there.

## 0.2.89

## Soundalerter Goes Global

Global sightings (Experimental, off by default, but hey World PVP here we come)
- New switch on Proximity Alerts, next to Party sharing, on a dark blue row to mark it as experimental. When it is on, the enemy players you see in the open world (nameplates, target, focus and your group's targets) are shared with every SoundAlerter user of your faction on your realm, and theirs are collected for you. It shares your rough location as a map square, never your exact position, and only outside instances, battlegrounds, arenas and cities.
- The world map shows them. Zoomed into a zone: one small dot per enemy at the map square where they were seen, in class colour, full strength for 2 minutes and fading out until they disappear at 10 minutes, plus a small zone panel. The panel leads with a verdict (Quiet, Active or Hot), the enemy count for the last 5 minutes with the change against the 5 minutes before, and one line of facts: the nearest enemy's distance and direction when you are in that zone, how many can stealth, how many are 3 or more levels above you, and how many SoundAlerter users are watching. Below are the class mix and the enemies, with enemies in the same or touching map squares shown as one group (hover for the members), levels coloured against yours, a skull for unknown, a heading arrow when they moved, "seen by" when two or more players reported them, and times like 45 s or 1 m 20 s. Click the panel title to switch between compact (3 rows) and expanded (8 rows, with distance and direction per row); your choice is saved. Dots on the map also get a small arrow showing which way the enemy was moving. Names in any alphabet now display correctly. Continent or world view: one badge per zone with its enemy count; busy zones glow. Hover a dot or badge for details. No sounds or toasts. `/sa global` reports the channel, messages and tracked enemies.
- Works with OpenMap's seamless map: the overlay switches to dots when you zoom in far enough to see zone detail and back to badges when you zoom out, dots show in every zone in view, and the panel follows the zone in the middle of the view.
- New World map detail setting (Low, Normal, High). Low redraws every 3 s, shows at most 50 enemies, fades in steps and hides markers while you zoom or pan; Normal redraws every second with up to 150; High shows all of them, pulses fresh sightings and adds detail to tooltips and badges. The overlay does no work while the map is closed, and while it is open it only redraws when a sighting is new, moved, comes back after fading, or the view changes, with a slow refresh for fading; unchanged markers are left alone.
- Protected against griefers: the hidden channel changes name every day (agreed by every client from the server date, with backup names if joining fails or someone takes it over), each player counts once in "seen by" however they word their messages, a sighting from a single other player shows dimmer and does not make a zone Hot until someone else or you see it too, and players who keep sending broken messages or flooding are ignored for the session. `/sa global mute <name>` and `unmute <name>` do it by hand, and `/sa global` lists who is ignored and why.
- Built to cost almost nothing: switched off it does no work at all; switched on it sends at most one message every 2 seconds on average, handles at most 8 incoming messages a second, keeps at most 500 enemies and forgets them after 10 minutes. The channel is hidden from your chat windows.

Footsteps
- Trail dots on the world map now draw above OpenMap's map art instead of underneath it.

Party sharing
- Your own shared alerts are now recognized when they come back to you. Characters here have a second name, and the sender shows as both names with a space, which was not matched before.

Statistics
- The Export box on the Statistics page no longer spills over the Reset buttons below it. It keeps its size, scrolls with the mouse wheel when the export is longer than the box and shows a scrollbar; select all and copy still copies the whole export.

Proximity Alerts
- The World PvP switch now applies in the open world. This client reports no PvP type for outdoor zones, so every zone was treated as a sanctuary and only the Sanctuary switch mattered. Outdoor zones now count as World PvP; cities and inns (while resting) and real sanctuaries still use the Sanctuary switch. If you only had Sanctuary on to get alerts outdoors, turn World PvP on.
