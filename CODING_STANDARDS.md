# Coding standards

Read during review: apply every rule below to the diff, and report each violation with its file and line.
The mechanical rules (Lua 5.1 syntax, zero comments, toc entries) are listed in `AGENTS.md` and
are not repeated here. This file holds the judgement calls a script cannot make.

## Hidden values

The Forever client returns *secret* (hidden) values from many APIs: enemy spell IDs and cast GUIDs,
unit health, power and cooldowns when restricted, auras when restricted, some event payloads. A
secret value may only be passed to a display sink or checked with `issecretvalue`.

- Every value from an API or payload that can return a secret goes through `SA_COMPAT.Plain`
  (secret becomes nil) or `issecretvalue` before any logic touches it.
- Allowed with a secret: passing it to a sink (`SetText`, `SetFormattedText`, `SetTexture`,
  `SetCooldown`, `GameTooltip:SetSpellByID`, `C_Spell.GetSpellName`/`GetSpellTexture` into a sink),
  and `issecretvalue(value)`.
- Everything else throws or misleads, so flag it: a truthiness test (`if value`, `value and x`,
  `value or y`), `==`/`~=`/`<`, arithmetic, `..`, `tostring` for logic, `#`, use as a table key, and
  string functions.
- Watch the `ok and value or fallback` idiom in particular: it tests the value's truthiness, and it
  also turns a legitimate `false` or `nil` result into the fallback.
- When a condition depends on a value that turned out hidden, it is *unknown*: skip the alert, rule or
  branch. An unknown never counts as true and is never guessed.

## Client APIs and events

- Handlers take the payload the client documents (`Blizzard_APIDocumentationGenerated`), in that
  order. Many unit events pass the unit first (`LOSS_OF_CONTROL_ADDED(unitTarget, effectIndex)`), and a
  plain `RegisterEvent` delivers them for every unit: filter on the unit, or register for one unit.
- New calls use the `C_*` namespace directly, or the shim in `soundalerter-constants.lua` when the
  surrounding code expects the old positional form.
- Optional or version-dependent APIs are checked for existence and called through `pcall`; a missing API
  degrades the feature quietly instead of erroring.

## Combat and protected frames

- Anything that moves, shows or reconfigures a secure frame, calls a protected function
  (`TargetUnit`, `CheckInteractDistance`, secure attribute changes) or sends chat waits behind an
  `InCombatLockdown()` check, or is queued for `PLAYER_REGEN_ENABLED`. `pcall` does not stop
  `ADDON_ACTION_BLOCKED`.
- Overlay frames on Blizzard's secure buttons are created and anchored out of combat; in combat only
  our own frames are shown or hidden.

## State and performance

- Every cache, buffer or per-player table has a cap and an eviction rule; nothing grows for the life of
  the session.
- Prefer events to `OnUpdate`. An unavoidable `OnUpdate` is throttled, stops when idle, and lives in a
  shared helper rather than being duplicated per module.
- Hot paths (per alert, per event, per frame) allocate nothing after warm-up: reused tables, pooled
  frames, upvalues instead of repeated global lookups.
- Text that depends on data is rebuilt only when that data changes (a version counter), not on every
  read.

## UI

- A frame that will call `SetBackdrop` is created with `"BackdropTemplate"`.
- Every new options control or page goes through `SA_MenuFX` and honours its off switch.
- Every new setting ships with its `defaults.lua` entry in the same change, so no option reads as nil on
  a fresh profile. A removed setting is added to `SA_ProfileCleanup` with a new `PASS`.
- Destructive actions (delete, reset, replace) ask for a second click.

## Change hygiene

- Do what was asked and nothing more: no helper abstraction for a one-off, no compatibility shim for
  removed code.
- A behaviour change updates `README.md` (and `CHANGELOG.md` for the release) in the same change. The
  TOC `## Version` and the README badge move together, once per batch.
- Imported or received data (profile texts, addon messages) is validated field by field against an
  allow-list and size limits before it touches saved variables; invalid entries are dropped and
  counted, never trusted.
