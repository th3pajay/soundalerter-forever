# Changelog

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
S