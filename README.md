<p align="center">
<img src="Media/banner.svg" alt="SoundAlerter Forever" width="100%"/>
</p>

<p align="center">
<b>Hear the fight before you see it.</b><br/>
Voiced PvP alerts, bars and trackers for WoW Forever.
</p>

<p align="center">
<img alt="Version" src="https://img.shields.io/badge/version-0.2.69-blue.svg"/>
<img alt="License" src="https://img.shields.io/badge/license-MIT-green.svg"/>
<img alt="WoW" src="https://img.shields.io/badge/WoW-Retail%20%7C%20Forever%20%7C%20Anniversary-orange.svg"/>
<img alt="Status" src="https://img.shields.io/badge/status-beta-yellow.svg"/>
</p>

<p align="center">
<img src="Media/feature-grid.svg" alt="Feature overview" width="100%"/>
</p>

<p align="center">
<img src="Media/toast_sticky.gif?raw=true" width="256"/>
<img src="Media/resource_mgt.gif?raw=true" width="256"/>
<img src="Media/spell_tracker.gif?raw=true" width="256"/>
</p>

## Get it

Extract `SoundAlerter` to `World of Warcraft/Interface/AddOns/`, type `/sa`, open **Quick Start**, press **Play test sound**.

> [!IMPORTANT]
> Forever permanently blocks the combat log for addons. Everything here runs on your **target, focus and enemies with a visible nameplate**, through unit events. Zone-wide detection and ally monitoring are gone, and the client hides some data (names, targets, auras, cast timing) even for visible units.

✅ works · 🟡 partial · 🧪 experimental, off by default · ❌ gone

## Everything it does

### Voice alerts

| Feature | | What it does, and the catch |
| :--- | :---: | :--- |
| Spell callouts | ✅ | 230+ spells by class, per-event toggles (Gained, Faded, Cast start, Cast, On you, On friend, On enemy, CC faded, Interrupts you), presets with undo, search. Your target and focus are covered by default; turn on **All enemies in range** (Quick Start) to include other nameplates, where the client often hides the spell, so casts there can stay silent |
| Aura and CC alerts | 🟡 | Reads the `UNIT_AURA` change list, falls back to a spell ID poll when the client hides it. Every Sap and Polymorph rank is covered on you, enemies and allies. The Silence switches for Gained, Faded, Cast start and Cast are independent |
| Interrupts you cast | ✅ | Announces the spell you stopped, optional `/roar`. Exact when the client names the interrupter, otherwise paired by timing. Being interrupted by Kick or Counterspell plays the lockout voice unless you switch that spell off under Interrupts you |
| Interrupt extras | 🟡 | Focus interrupt sound, minimum cast time, pet interrupts, estimated "interrupt ready" call. The ready call is an estimate |
| Loss of control voice | 🧪 | Speaks stun, fear, root, silence, disarm, incapacitate, lockout from the game's own data, no spell list |
| Engine aura sounds | 🧪 | Hands self debuffs and target or focus enemy debuffs to the game's own aura sound. Not counted in Statistics |
| Chat alerts | ✅ | Say, Party, Raid or Instance, falls back to your own chat |
| Zone-wide, ally CC, any-enemy matching | ❌ | Needed the combat log |

### Proximity and battlegrounds

| Feature | | What it does, and the catch |
| :--- | :---: | :--- |
| Proximity toasts | ✅ | Sticky toasts via nameplate, target or mouseover. Close, Nearby, Medium, Detected bands, group size, 3 buff icons, click-to-target |
| Enemy awareness | 🟡 | Voice when an enemy targets you or casts on you. Silent when the client hides their target |
| Watchlist | 🟡 | Alert for watched players or guilds. Silent where names or guilds are hidden |
| Group vision | 🧪 | Enemies your party targets, far beyond nameplate range. Depends on the game sharing those units |
| Totem nameplates | 🧪 | Turns on the game's totem plates, restores your settings after |
| Quiet rules | ✅ | Silent on flight paths, while dead, optionally while unflagged, `/sa snooze` |
| Scoreboard class fallback | ✅ | Battleground class comes from the scoreboard when the nameplate hides it |
| Notices | 🧪 | Short cues for duel requests, summons, resurrections, group invites, queue pops, ready checks and low durability, each with an optional voice line, taskbar flash and chat line. A notice stays silent until its voice file exists (`/sa notices files` lists them). Off by default and not yet confirmed in game |
| Flag tracking | ✅ | Team-aware pickup, drop and capture toasts for WSG and Eye of the Storm. Returns are announced too when you turn them on, from the game's "returned to its base" message, which is not yet confirmed in game |

### Bars and meters

| Feature | | What it does, and the catch |
| :--- | :---: | :--- |
| Resource bars | ✅ | Health, Mana, Energy, Rage, Combo Points (10 shapes), feral form support, 7 textures |
| Casting bars | 🟡 | Player, target, focus, channels, finish animations. If enemy timing is hidden the bar still fills from the game's timer, without time text |
| Cast feed | 🟡 | One icon row per unit with time between casts. Other units' casts are sometimes shown generically |
| **Combat drop timer** | 🟡 | Hairline bar with millisecond digits counting down to leaving combat, pulse in the last second. The game does not report every hit, so it is an estimate that snaps to the real drop. Resyncs after death, loading screens and reloads |
| **Speed meter** | ✅ | Live movement speed as a percent of base run speed. Green above 100%, red below, plain when mounted or flying. Follows running, swimming, flying |
| **Footsteps** | 🟡 | A dotted trail on the minimap and on the zone map along the path you have walked since you logged in, kept across `/reload`. Off by default. Nothing is recorded in instances or on flight paths, a teleport starts a new stretch, and only the newest 1500 steps are kept. The world map shows the steps taken on the map it is displaying, so the continent view stays empty. Not yet confirmed in game |

### Trackers and tools

| Feature | | What it does, and the catch |
| :--- | :---: | :--- |
| Spell tracker | ✅ | Buff, debuff and cooldown icons that work in combat, spiral and border timers, "Ready!" glows, survives druid form swaps. A landed hit cannot be confirmed in combat, so the timer starts on cast. Finishers cancel on a miss or dodge |
| Minimap tracking | ✅ | Keeps target and focus on the minimap across loading screens |
| Spell Finder | ✅ | Search spell IDs, names and descriptions with fuzzy match, filters and full spell details |
| Statistics | ✅ | Session and all-time alerts: which fired, from whom, where. Counts spell, proximity, trinket, flag, interrupt, awareness, loss of control, watchlist and chat alerts |
| Developer Tools | ✅ | Database status, performance timings, Debug Mode traces |

## Commands

| Command | Action |
| :--- | :--- |
| `/sa` | Options window |
| `/sa help` | Full command list |
| `/sa probe` | What the client lets the addon read right now |
| `/sa snooze [min]` / `unsnooze` | Silence proximity alerts |
| `/sa footsteps clear` | Erase the footsteps trail |
| `/sa spelltest on` / `off` / `report` / `clear` | Record for up to 30 minutes what the game hands the addon for casts and auras, so we know which spell alerts can work. No player names are saved |
| `/sa watch [guild] <name>` / `unwatch` / `watchlist` | Manage the watchlist |
| `/sa aurasound` | Test engine aura sounds |

Built on Ace3 with per-character profiles. Protected frames are never touched in combat.

MIT · th3pajay / Starmistx
