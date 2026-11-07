# Changelog

## 0.3.00

## Really?.. Venn diagrams?

Highlights
- Global sightings is out of experimental and on by default, with your opt-out under Proximity Alerts. Minimap dots are now a separate choice, off by default.
- The match debrief now shows whether you won or lost, plus your damage and healing, and Statistics has a new Visuals tab.
- New swing timer: a low-profile spark on your resource bar, off by default.
- Say when interrupt is ready learns your real cooldown, and interrupts now cover Forever's spells and every rank.
- Buffs you cast in combat stop their timer when consumed early, and toasts show the enemy's second name.
- New optional weapon swap button on the Trinket Menu that works in combat, and new Fire and Leaves bar textures.
- SoundAlerter can now tell you when a newer version is out.

Update notice
- SoundAlerter now prints one chat line when a newer version is out. Addons cannot reach the internet, so it learns this from other players' copies, and each announcement carries a proof that only a real release can have, so nobody can fake it. The notice never contains a link: update through CurseForge. It starts with this version, so older copies stay quiet. Turn it off under General, Updates; `/sa updates` shows what it knows.

Statistics
- New Visuals tab next to Now, Trends and Rivals: a Venn diagram of your spells by where they were seen. The three circles are Arena, Battlegrounds and World PvP; a spell sits in the region for every zone it has fired in, so the centre holds the spells you meet everywhere.
- Spells are drawn as round icons, bigger for more alerts, with a ring in the colour of the spell type (crowd control, defensive, interrupt, removal, other). The heaviest ones sit nearest the middle of their region; whatever does not fit collapses into a +N bubble you can hover to list.
- The circle labels show how many spells each zone holds. The legend under the diagram shows and hides a spell type.
- Hover an icon for its name, type, ID, total alerts, the split between the three zones and the class that casts it most; the zones it belongs to light up. Click it to look it up in Spell Finder.
- The icons fly in when the tab opens and slide when the filter changes. Both follow the menu animations setting.
- The match debrief now shows the damage and healing you did in each arena and battleground match, with your three biggest damage spells and their share. The numbers come from the game's damage meter and are read after each fight, because the game hides them in combat. Your own damage meter is never reset.
- New `/sa meter` command: shows what the game's damage meter reports for you, to check that match results will work.
- Busiest hours on the Trends tab now has hour labels under the bars.
- The match debrief now says whether you won, lost or drew each arena and battleground match, with your record for the kept matches at the top. Match length now comes from the game when it reports one. Solo Shuffle shows no result.
- New `/sa perf` command: shows how much frame time and memory SoundAlerter uses, from the game's own addon profiler.

Voice Alerts
- Say when interrupt is ready now learns your interrupt's real cooldown per character, so talents and Forever's own values are respected instead of a fixed table. A single odd timing, such as a cooldown reset, does not change it. The fixed value is used until something has been learned.
- Interrupts now cover Forever's spells and every rank: all Earth Shock and Shield Bash ranks, Spell Lock, Feral Charge, Skull Bash, Rebuke and Silence. They count for your own interrupt messages and the ready voice, and an enemy using one on you now plays Lockout.
- The Lockout setting now applies to every interrupt used on you. Before, it only applied to Counterspell and Kick rank 1, and the others always played.
- Enemy Shield Bash (all ranks) and the other Spell Lock rank now play their voice alert.
- The Spell Lock ready voice now waits 30 seconds, not 24, matching the game's data.
- New Say my procs setting under More options, off by default: says the spell when one of your own lights up. The voice comes from the spell's name, so a matching mp3 in your voice folder just works, and `/sa procs` lists which of your procs have a voice.
- New alert for an enemy gaining Reckless Swings. It is off by default because it can fire every 15 seconds; turn it on under Warrior.

Spell tracker
- A buff you cast in combat now stops its timer when it is consumed or removed early, such as Nature's Grasp, and the icon goes back to idle. This works where the game shows aura changes; where it hides them, such as in a duel, the timer still runs its full length.

Resource bars
- New swing timer, off by default: Swing spark under Resource Management. A small spark runs along the top border of the bar your form uses and reaches the end as your next swing lands, with a brief flash you can turn off. Off-hand runs along the bottom border. It shows only while you are swinging and needs a resource bar shown. It covers melee and ranged, and runs on the game's animation engine so it costs almost no script time.
- The rage bar now empties when a druid leaves Bear Form instead of showing leftover rage that slowly drains, and starts from the real value when you shift back. The bar does no work while it is out of form.
- New Fade rage bar when empty setting: the rage bar fades out of view when you have no rage or are out of Bear Form, in Bear and Dire Bear Form as well, while the bars are locked.

Bar textures
- Two new animated bar textures for the resource bars and casting bars: Fire (three layers of flames that rise and flicker while drifting sideways, with a heat glow at High) and Leaves (autumn leaves blown sideways at three depths, with gusts, and larger leaves at High). Both cost about as much as Streaks.

Global sightings
- No longer experimental: Global sightings is now on by default, also in Quick Start. It shares the enemies you see and your rough map square with other SoundAlerter users of your faction on your realm, and shows theirs on your world map. To opt out, turn it off under Proximity Alerts, Global sightings. If you already use SoundAlerter, one chat message tells you this at your next login.
- Minimap dots are now a separate choice and off by default, so if you had them, turn on Show on the minimap to get them back. The world map overlay and panels stay on.
- Its settings now have their own Global sightings section on the Proximity Alerts page, apart from Party sharing. They are separate features with separate switches.
- It now waits 15 seconds after login or a loading screen before joining its channel, so your General and Trade channel numbers are left alone. If every channel is refused it retries every 5 minutes instead of every 10 seconds.
- On a busy channel, watcher counts can no longer crowd out enemy sightings.
- The world map card has a new look: a coloured verdict pill, three tiles (enemies with a trend, nearest, watching), a class bar with the three biggest classes, and compact rows with a level chip.
- Zoomed out to a continent or the world, the card now stays and shows the world: enemies with a trend, zones reporting, watchers, the class mix and the busiest zones. Hover a zone row to enlarge its ring on the map.
- Fixed the card jumping open and shut when the pointer sat on the lower part of the slim strip.
- The strip opens when you hover it, keeps its place for a moment after you leave, and stays open when you click its title. Opening and closing ease over 0.12 seconds with the menu animations setting.
- Zone panel and World panel settings under Global sightings: Strip, Always open or Off.
- Hover the Enemies tile to see how many enemies can stealth and how many are higher level than you.
- The card shows all rows by default; click the +N more or show less row to switch.
- Ages read now, <1m, 2m. The card no longer polls the pointer and only rewrites text that changed.

Proximity toasts
- Toasts now show the enemy's second name after the first, smaller and behind a thin divider. When both do not fit, the second name is cut first and hidden if too little room is left. Alerts shared by party members still show one name.
- Long names no longer run under the enemy's latest spell on the Intel card, and the Threat card gives the name row more room.
- On the Threat card, the enemy's latest spell moved down beside the aura icons, so a long threat reason no longer runs under it. A title too long for its line now ends in dots instead of wrapping into the row below.
- Showing a toast does less work: the buff and debuff scan stops once it has 3 icons.

Trinket Menu
- New optional weapon button, off by default, for swapping between damage and healing weapons mid-fight. Unlike the other swaps it works at once, also in combat. It changes the main hand and the off-hand, and has its own keybind under Key Bindings > AddOns > SoundAlerter.
- To set it up, turn on Weapon swap button in the new Weapons group. Wear your DPS weapons and shift-click the button, then wear your healing weapons and shift-click it again. The options page has Save buttons for each pair too. Pairs can only change out of combat.
- The button shows your worn weapon, a coloured border and label (amber DPS, green HEAL) and a corner badge with what a click equips. A red mark warns when the next weapon is not in your bags. Hover it out of combat to equip weapons from your bags, right-click to use the main-hand effect.

## 0.2.94

## Looks and glances

Trinket menu
- Ready glow: when a trinket comes off a cooldown longer than 30 seconds, a soft spark runs twice round its border. The 30 second lock after equipping a trinket never triggers it, and it stays off while the bar is faded or collapsed. On by default, switch under Look. The animation runs in the game client, with no addon code running per frame.
- Icons sit behind a thin black inset and dim while their trinket is on cooldown.
- Cooldown numbers turn gold under 10 seconds and red under 3.
- A dark backplate sits behind the bar.
- Button edges brighten on hover.
- The set button shows a split line between its two trinkets, and the set and gear labels sit on a dark pill. Keybind text is a softer grey.
- An empty trinket slot gets a grey edge and a dimmed icon.
- The bag flyout points at the trinket it belongs to.
- Collapsed to a diamond: opening the bar unfolds the buttons out of the diamond one after another, and the diamond spins back in when the bar closes. Both take 0.15 seconds and also work in combat.
- When a trinket comes ready while the bar is collapsed, one soft ring ripples out of the diamond instead.

Spell tracker
- Target nameplate: spells tracked on your target can sit in a row above its nameplate, with the same countdown, sweep, borders and effects as on screen. The one ending soonest is drawn larger in front. When the game shows its own aura icons on the plate, the row sits on top of them instead of over them. Off by default; turn it on under Target nameplate, and choose per spell under Selected spell (target spells go to the plate by default, your own spells always stay on screen).
- Options: icon size, spacing, distance from the plate, follow the plate's scale, show idle icons, most icons at once, and what to do when there is no plate (use the screen spot or hide).
- Works in combat. Only the addon's own icons are moved; the nameplate itself is never changed, and icons on a plate cannot be dragged.
- The nameplate settings travel in the Display block of a tracker export, and each spell's choice travels with the spell.

Diminishing returns (new, experimental)
- One row of icons for the target and one for the focus, one icon per crowd control category: stun, opener stun, incapacitate, fear and disorient, silence, root, horror, cyclone and banish. Each category can be switched off.
- Each icon shows the last spell that landed, with the category letters in the corner. The border shows how long the next one in that category lasts: green half, yellow a quarter, red immune.
- While the crowd control is up the icon counts it down; when it ends the icon dims and counts down the 18 second reset, then goes away.
- Crowd control from anyone counts, but only what lands on your target or focus can be seen. Effects in a duel are hidden by the game and skipped.
- Each row can be dragged anywhere: untick Lock position, drag, lock again. There is a button to put both rows back.
- Options: track target, track focus, icon size, spacing, countdown numbers, category tag, lock position, and a test button.
- Off by default; turn it on under Displays, Diminishing Returns. Only the addon's own icons are drawn.

Fixes
- Options: every page that has a lock now calls it "Lock position" and puts it first in General, with "Reset position" right under it. Casting Bars, Resource Bars and Spell Tracker used "Lock bars" or "Lock icons", and Resource Bars and Spell Tracker had no reset. New profiles start locked on those three pages too; your saved choice is kept. Casting Bars keeps "Apply pyramid layout" as its reset.
- Diminishing Returns: fixed a Lua error on some units. When the game hides what changed on a unit's auras, the tracker now re-reads that unit's auras instead of reading the hidden fields.
- Speed: when the game hides what changed on a unit's auras, the alert engine and the Diminishing Returns tracker now re-read that unit once per frame instead of once per event. Bursts of aura changes cost one pass. The speed meter also stops rebuilding its text when the number has not changed.
- Find Spell: inserting a spell into chat now finds the chat box you opened with Enter. Before, it could miss it and print the text in your own chat instead.
- Spell tracker: locking the icons now hides idle icons that have "Show when inactive" turned off. Before, they stayed faded on screen until another setting was changed.
- Spell tracker: the live preview lines no longer overlap when a line is long.

## 0.2.93

Voice alerts
- Templar's Bulwark: protection paladins can now have it purged or dispelled, so you hear it when an enemy gains it.
- Death Mark: you hear it when a subtlety rogue marks you, so you can decurse it or use a defensive before the stored damage lands 6 seconds later.
- Chain Lightning: a new cast alert now that it is a 2.5 second cast. Every rank is covered.
- Wild Growth now has a 3 second cast and plays the Big heals alert, so it follows your existing Big heals switch.
- Turn Undead is now called Turn Undead / Turn Evil, because the Turn Evil talent lets it hit demons, warlocks in Metamorphosis included. All three ranks are covered now, not only the highest. Your on or off choice is kept.
- Skysight now plays for the speed buff the spell actually leaves on the enemy, not only for the cast.

Spell tracker
- New "Add Death Mark on you" action under Add a spell. It adds a red debuff icon that counts down the 6 seconds and follows every rank of Death Mark. The action is hidden once Death Mark is tracked.

Resource bars
- Poised marker: a gold edge and a Poised tag on the energy bar while Poised is up, so you can see that your next energy ability costs less. It is on by default for rogues from level 18 and druids from level 32, and can be turned off under Energy bar. Other classes never see the option or run its code.

Proximity alerts
- When an enemy hunter places a trap or traps you, their toast's spell line reads "Traps down 30s", because all hunter traps now share one 30 second cooldown. It follows the latest spell line switch.

Statistics
- Each recorded match now notes the game build it was played on, and the export shows it. Matches recorded before this version show "unknown build". This keeps matches from before and after Blizzard's tuning passes apart.

## 0.2.92

Breaking changes
- The Combat timer is removed. Its page under Displays, its lock on the minimap button, its chip on the profile cards and the `/sa ctprobe` command are gone, and its saved settings are cleared from every profile once, on the first login with this version.

Profiles
- New Spell Tracker blocks section on the Profiles page, between New profile and More options. Your tracked spells are grouped into blocks by class, plus a Display block (timer, border, cooldown and ready text, animation quality) and a Layout block (icon sizes and positions), shown as one bar of clickable segments.
- Export: pick blocks from the profile chosen above and copy the text. Nothing else from the profile goes along.
- Import: paste a blocks text and it lists what would change in your active profile, spell by spell: new spells, changed spells and display settings, each with Take or Keep mine (Add or Skip for new ones) plus Take all and Keep all. Merge applies your choices; Replace picked blocks swaps whole classes and asks for a second click. Layout on its own only moves spells you already track.
- Imported texts are checked entry by entry; invalid spells or values are skipped and counted, at most 60 spells are read, and the tracker never grows past its 20 icons. A full profile export pasted here, or a blocks text pasted into Import text, is refused with a pointer to the right place.

Statistics
- New "Last 20 matches" card on the Statistics page. Each arena or battleground match is recorded from entering the instance until you leave it: how long it lasted, the alerts it fired, how many enemies set one off, your top three alerted spells and your time in crowd control. A match in progress shows at the top as Live.
- Time in CC counts stuns, fears, incapacitates and silences, not roots, disarms or school lockouts. Overlapping effects are counted once, and breaking free early stops the clock. When the game hides an effect's duration it is still counted, and the time is marked with a + as a lower bound.
- A `/reload` inside a match keeps the match going. Short visits with no alerts are not kept, and a match left open for hours, for example after a disconnect, ends at its last alert.
- Recent matches are added to the export text. Reset all-time also clears them, and switching profile closes the running match into the profile it started in.
- The match card follows the Statistics switch: with tracking off, nothing is recorded.

Voice Alerts
- Loss of control voice now plays on this client. It stayed silent before because the game names the affected unit before the effect, so the effect was never found. Only control effects on you are spoken; effects on your target, focus or other players are ignored, and the same rule applies to the match card's CC time.

Custom alerts
- The "Source of the spell" and "Spell destination" pickers on the custom alert page list their choices again (Any, Friendly, Hostile player and so on). Since 0.2.81 both lists were empty.

## 0.2.91

## Broom and sweeps

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
- Stealth keep watch now waits 4 seconds between repeat alerts for the same enemy (was 5), so a rogue who restealths quickly with Camouflage is still called. If you picked a different time on the Proximity Alerts page, it is kept.

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
