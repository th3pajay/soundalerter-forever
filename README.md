<table>
<tr>
<td width="240" valign="top"><img src="Media/soundalerter.png" alt="An elf scout listening, with her dog" width="240"/></td>
<td valign="top">

# SoundAlerter Forever

**Personal combat assistant.**
Voiced PvP alerts, bars and trackers for WoW Forever.

<img alt="Version" src="https://img.shields.io/badge/version-0.2.75-blue.svg"/>
<img alt="License" src="https://img.shields.io/badge/license-MIT-green.svg"/>
<img alt="WoW" src="https://img.shields.io/badge/WoW-Retail%20%7C%20Forever%20%7C%20Anniversary-orange.svg"/>
<img alt="Status" src="https://img.shields.io/badge/status-beta-yellow.svg"/>

**Get it:** extract `SoundAlerter` to `World of Warcraft/Interface/AddOns/`, type `/sa`, open **Quick Start**, press **Play test sound**.

🟢 works · 🟡 partial · 🟣 experimental, off by default

</td>
</tr>
</table>

> [!IMPORTANT]
> Forever blocks the combat log for addons. Everything here runs on your **target, focus and enemies with a visible nameplate**. The client also hides some names, targets, auras and cast timing, so a few alerts can stay silent.

<p align="center">
<img src="Media/toast_sticky.gif?raw=true" width="256"/>
<img src="Media/resource_mgt.gif?raw=true" width="256"/>
<img src="Media/spell_tracker.gif?raw=true" width="256"/>
</p>

## Hear it

| | Feature | What it does | |
| :---: | :--- | :--- | :---: |
| <img src="Media/icons/voice.svg" width="32"/> | **Spell callouts** | 230+ spells by class with per-event toggles, presets and search. Covers your target and focus; turn on **All enemies in range** for other nameplates. Aura and CC alerts fall back to polling when the client hides the aura | 🟢 |
| <img src="Media/icons/control.svg" width="32"/> | **Control voice** | Speaks stun, fear, root, silence, disarm and incapacitate from the game's own data | 🟣 |
| <img src="Media/icons/interrupt.svg" width="32"/> | **Interrupts** | Calls the spell you stopped, and when you get locked out. Exact when the client names the interrupter, otherwise paired by timing | 🟢 |
| <img src="Media/icons/chat.svg" width="32"/> | **Chat alerts** | Say, party, raid or instance, with a fallback to your own chat | 🟢 |

## See it

| | Feature | What it does | |
| :---: | :--- | :--- | :---: |
| <img src="Media/icons/proximity.svg" width="32"/> | **Proximity toasts** | Pop-ups for enemies nearby with a distance band, level, group size and 3 aura icons. Pick an **Intel card** or a **Threat card**, click to target. Quiet rules and `/sa snooze` keep it silent when you want | 🟢 |
| <img src="Media/icons/aware.svg" width="32"/> | **Awareness and watchlist** | Voice when an enemy targets or casts on you, and for watched players or guilds. Silent where the client hides targets or names | 🟡 |
| <img src="Media/icons/flag.svg" width="32"/> | **Flag tracking** | Team-aware pickup, drop and capture toasts in WSG and Eye of the Storm. Returns too, once switched on | 🟢 |
| <img src="Media/icons/notice.svg" width="32"/> | **Notices** | Cues for duels, summons, resurrections, invites, queue pops, ready checks and low durability. Each is silent until its voice file exists (`/sa notices files`) | 🟣 |

## Watch it

| | Feature | What it does | |
| :---: | :--- | :--- | :---: |
| <img src="Media/icons/resource.svg" width="32"/> | **Resource bars** | Health, mana, energy, rage and combo points in 10 shapes with 8 celebration animations (each with its own spend and loss exit, and a Low / Normal / High quality setting), with feral form support and 7 textures | 🟢 |
| <img src="Media/icons/casting.svg" width="32"/> | **Casting bars** | Player, target and focus bars with a segmented look, an unfurl on cast start, bloom rings on finish, a stamped INTERRUPTED, a steel look for uninterruptible casts, a red timer flip in the last 0.7 s, channel pulses and a shrink when a cast stops. Low, Normal and High animation quality. Fills from the game's timer, without time text, when enemy timing is hidden | 🟡 |
| <img src="Media/icons/feed.svg" width="32"/> | **Cast feed** | One icon row per unit with the time between casts. Other units' casts can show generically | 🟡 |
| <img src="Media/icons/timer.svg" width="32"/> | **Combat timer** | Millisecond countdown to leaving combat. An estimate that snaps to the real drop | 🟡 |
| <img src="Media/icons/speed.svg" width="32"/> | **Speed meter** | Live movement speed as a percent of base run speed, green above 100% and red below | 🟢 |
| <img src="Media/icons/foot.svg" width="32"/> | **Footsteps** | A dotted trail on the minimap and zone map of where you walked. Off by default, not recorded in instances or on flight paths | 🟡 |

## Tune it

| | Feature | What it does | |
| :---: | :--- | :--- | :---: |
| <img src="Media/icons/tracker.svg" width="32"/> | **Spell tracker** | Buff, debuff and cooldown icons that work in combat, with spiral and border timers, a pop-in, a border that shifts from green to red as time runs out, a red tint warning, a shrink when the aura ends and a shine when a cooldown is ready. Low, Normal and High animation quality. The timer starts on cast, because a landed hit cannot be confirmed in combat | 🟢 |
| <img src="Media/icons/minimap.svg" width="32"/> | **Minimap tracking** | Keeps target and focus on the minimap across loading screens | 🟢 |
| <img src="Media/icons/finder.svg" width="32"/> | **Spell Finder** | Search spell IDs, names and descriptions with fuzzy match, filters and full spell details | 🟢 |
| <img src="Media/icons/stats.svg" width="32"/> | **Statistics** | Session and all-time counts of which alerts fired, from whom, and where | 🟢 |
| <img src="Media/icons/quick.svg" width="32"/> | **Quick Start** | Presets, volume and a test sound in one place | 🟢 |
| 🗺️ | **Minimap button** | Every Shift, Ctrl and Alt click on the left, right and middle button can run an action: options, a quick switch menu, proximity, battleground, snooze, lock bars, chat alerts, notices, next profile, Spell Finder, statistics or a test voice. The icon and tooltip follow your settings, with 12 icons to choose per state | 🟡 |

## Commands

| Command | Action |
| :--- | :--- |
| `/sa` | Options window |
| `/sa help` | Full command list |
| `/sa probe` | What the client lets the addon read right now |
| `/sa speed` | The raw speed values and what the Speed Meter would show, for checking swimming |
| `/sa fxstats [reset]` | How often the casting bars and spell tracker icons update at your animation quality |
| `/sa snooze [min]` / `unsnooze` | Silence proximity alerts |
| `/sa watch [guild] <name>` | Manage the watchlist |

Built on Ace3 with per-character profiles. Protected frames are never touched in combat.

MIT · th3pajay / Starmistx
