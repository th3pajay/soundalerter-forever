# SoundAlerter - Forever (BETA BUILD)

![Version](https://img.shields.io/badge/version-0.2.0-blue.svg) ![License](https://img.shields.io/badge/license-MIT-green.svg) ![WoW](https://img.shields.io/badge/WoW-Retail%20%7C%20Forever%20%7C%20Anniversary-orange.svg) ![Platform](https://img.shields.io/badge/platform-Windows-purple.svg)

**What changed:** WoW Forever permanently restricts `COMBAT_LOG_EVENT_UNFILTERED` for every third-party addon — a Blizzard platform decision, not a bug, and not addon-specific. SoundAlerter has been rebuilt around nameplate and unit-event tracking instead.

**Gone:**
- True zone-wide ambient detection of enemies you haven't targeted, moused over, or whose nameplate isn't visible
- The Custom Sound Alert engine's "any enemy anywhere" matching (now scoped to nameplate-visible/target/focus enemies)
- Ally-side CC/cast monitoring (friendly-target alert categories)

**Kept:**
- Voice alerts for your target, focus, and any enemy player with a visible nameplate nearby
- Proximity detection and toasts (now nameplate + target/mouseover driven)
- Battleground flag tracking (already chat-message based, unaffected)
- Casting bars, resource bars, spell tracker (never depended on combat log)
- All existing settings and Custom Sound Alert rules carry over automatically, no reconfiguration needed

---

**PVP combat suite**
Voiced PVP combat addon for WoW Forever, as it not only builds upon the legacy of Soundalerter 
but adds new functions, like proximity voice-toast alerts, castingbars, 
resource and spell cd management and combo point tracking. 

Also, it's still an early beta, please expect bugs.

<p align="center">
<img src="Media/soundalerter.png" alt="SoundAlerter Addon Logo" width="256"/>
</p>

---

## Overview

A voice and visual alert addon for arena and battleground PvP — instant callouts for enemy cooldowns, CC, and interrupts, plus a full combat awareness suite (proximity detection, flag tracking, resource bars, cast bars, and spell tracking).

**Performance**: Event handlers filter on unit token identity before touching any API, keeping per-event cost negligible even in large fights. Flag-alert timing is verifiable in-game via `/sa flag metrics`.

---

## The Complete Suite

### Voice Alerts - Instant Audio Callouts
450+ critical spell callouts with professional voice alerts, for your target, focus, and any enemy player with a visible nameplate nearby.

**Features:**
* Defensive cooldown, CC, and interrupt alerts
* Self and enemy debuff alerts
* English voice pack

**Configuration**: `/sa` -> Voice Alerts tab

---

### Proximity Alerts - Range Detection
Visual and audio alerts for nearby enemies. Sticky toasts include instant targeting and countdown timers.
<p align="center">
<img src="Media/toast_sticky.gif?raw=true" alt="Sticky Toast" width="256"/>
</p>

**Features:**
* Automatic enemy detection via nameplate range, target, or mouseover
* One-click targeting from toast
* PvE mode filtering

**Configuration**: `/sa` -> Proximity Alerts tab
**Commands**: `/sa toast test` (preview), `/sa toast status` (metrics)

---

### Battleground Alerts - Objective Tracking
Team-aware CTF tracking for WSG and Eye of the Storm.
<p align="center">
<img src="Media/toast_bg_flagpickup.gif?raw=true" alt="BG Flag Alerts" width="256"/>
</p>

**Features:**
* Class identification via chat-message parsing and unit scanning
* Visual flag status indicators

**Configuration**: `/sa` -> Battleground Alerts tab
**Commands**: `/sa flag myteam` (team check), `/sa flag metrics` (stats)

---

### Resource Bars - Power Tracking
Unified bars for Health, Mana, Energy, Rage, and Combo Points.
<p align="center">
<img src="Media/resource_mgt.gif?raw=true" alt="Resource Mgt" width="256"/>
</p>

**Features:**
* Feral Druid form-switching support
* Position memory per profile

**Configuration**: `/sa` -> Resource Bars tab

---

### Casting Bars - Accurate Timing
Cast bars for Player, Target, and Focus units.

**Features:**
* Channeled and mid-cast targeting support
* Interrupt flash effects
* Configurable orientation (horizontal/vertical) and fill direction per bar

**Configuration**: `/sa` -> Casting Bars tab

---

### Spell Tracker - Aura Management
Icon-based tracking for buffs, debuffs, and cooldowns.
<p align="center">
<img src="Media/spell_tracker.gif?raw=true" alt="Spell Tracker" width="256"/>
</p>

**Features:**
* Simultaneous player and target tracking
* Cooldown spiral animations and duration overlays

**Configuration**: `/sa` -> Spell Tracker tab

---

### Spell Finder - Database Access
Search 12,000+ spells instantly for IDs and tooltip data.
<p align="center">
<img src="Media/find_spell_db_progress.gif?raw=true" alt="Find Spell" width="256"/>
</p>

**Configuration**: `/sa` -> Developer Tools tab

The **Spell Database** panel shows build progress, indexed/unique/ranked spell counts, scan range, last update and auto-rebuild countdown, the game build it was indexed on, search timing percentiles, result-cache fill and addon memory.

---

### Statistics - Combat Intelligence
Per-encounter data, alert frequency tracking, and enemy danger ratings.

---

## Getting Started

### Installation
1. Download the latest release.
2. Extract the `SoundAlerter` folder to `World of Warcraft/Interface/AddOns/`.
3. Launch WoW and check the minimap button (alternatively use shift and ctrl clicks to shortcut proximity and battleground alerts).

<p align="center">
<img src="Media/minimap_anim.gif?raw=true" alt="Minimap Anim" width="32"/>
</p>

### Quick Setup
1. Type `/sa`.
2. Go to **Quick Start** tab.
3. Select combat zones (Arena, BGs, World).
4. Choose alert scope.
5. Test audio via preview.

---

## Performance Metrics

| Metric | Value | Details |
| :--- | :--- | :--- |
| Alert Latency | Real p50/p95/p99 via `/sa stats` | Timed with `debugprofilestop()`, not a guessed number |
| Flag Processing | P99 target: <10ms ("Excellent" rating) | Real per-event timing, via `/sa flag metrics` |
| Spell Search | Typically sub-ms for 3+ char terms | Real p50/p95/p99/max in Developer Tools -> Spell Database |
| Class Detection | Microsecond-scale, tiered GUID-to-class cache | Shared by voice alerts and proximity toasts, via `/sa stats` |

---

## Command Reference

| Command | Action |
| :--- | :--- |
| `/sa` | Main options panel |
| `/sa stats` | Class detection statistics |
| `/sa help` | Full categorized command list |
| `/sa apicheck` | Diagnostic scan of API/table availability (debug tool) |
| `/sa toast status` | Proximity performance metrics |
| `/sa toast enable` | Enable proximity toast notifications |
| `/sa toast enableclick` | Enable click-to-target functionality |
| `/sa toast init` | Manually initialize toast system |
| `/sa flag myteam` | Current BG team assignment |
| `/sa flag metrics` | Flag alert performance stats |
| `/sa flag toastmetrics` | Flag toast performance metrics |
| `/sa flag cache [persist]` | Class cache efficiency (both, or persistent only) |
| `/sa flag clearcache` | Clear persistent class cache |
| `/sa flag cleartoasts` | Clear all active flag toasts |

Developer/test subcommands (e.g. `/sa toast test`, `/sa flag test`) only appear and run with Debug Mode enabled in `/sa` options.

---

## Technical Highlights

* **Framework**: Built on Ace3 (AceAddon, AceEvent, AceDB, AceConfig, AceGUI).
* **Zero-Taint**: Uses secure APIs to prevent combat blocking.
* **Event-Driven**: Tracks nameplates (`NAME_PLATE_UNIT_ADDED`/`REMOVED`) plus `UNIT_SPELLCAST_*`/`UNIT_AURA` on target, focus, and tracked nameplates — `COMBAT_LOG_EVENT_UNFILTERED` is permanently unavailable to addons on this client.
* **Profiles**: Supports per-character configuration and export.

---

## Credits

**Author**: th3pajay

---

## License
MIT License - Open for use, modification, and distribution.

Fair winds, fellow adventurers!
*th3pajay / Starmistx - An old feral (https://warcraftmovies.com/pv.php?t=3&l=pajay)*
