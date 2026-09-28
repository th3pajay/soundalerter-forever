# Agents on this repo

This repo (`soundalerter-forever`) showcases agentic collaboration: two AI agents,
**claude** and **hermes**, committing to the same codebase under their own names,
alongside th3pajay (human maintainer, final say on everything).

## Who decides

th3pajay's instruction beats every rule below, including the ones written as absolutes. If he asks
for something this document forbids — a comment, a branch, an extra file — do it, and say in your
report which rule you waived. Where two rules conflict, the one that protects the running addon
wins over the one that protects tidiness. Nothing here is decided by an agent's taste.

## What you're working on

SoundAlerter - Forever: a voice/visual PvP alert addon for the WoW Forever client
(README.md has the full feature list). `COMBAT_LOG_EVENT_UNFILTERED` is permanently
restricted on this client — every detection path here is nameplate/unit-event based,
never combat-log based. Do not reintroduce combat-log-dependent detection; it will not
work on this client. A combat-log registration is not a harmless fallback: it registers
cleanly, never fires, and is rediscovered later as a mystery. Remove the path instead.

The TOC advertises three clients — `## Interface: 110105, 20506, 16001`, where `16001` is Forever —
so a change that calls a modern-only API has to hold on all three unless th3pajay scopes it.

Tracked paths: `SoundAlerter/` (addon code), `Media/`, `README.md`, `AGENTS.md`, `.gitignore`.
Nothing else belongs in this repo — no workspace notes, no IDE config, no memory files, no scratch
scripts. Instructions that are specific to one agent stay outside the repo; this file is the part
both agents share.

## Every session

1. `git pull origin develop` before touching anything — claude or th3pajay may have
   pushed since your last session.
2. Work on `develop` directly (direct-push model, no PR gate). If your change is large
   or risky, say so in the commit message rather than splitting into a branch nobody
   will merge.
3. Commit under your own name — `hermes <hermes@users.noreply.github.com>`. Check
   `git config user.name` before your first commit; the setting is local to the clone, never
   `--global`, and th3pajay's own identity stays untouched.
4. `git push origin develop`. `main` is release-only; only th3pajay merges
   `develop` -> `main`.
5. If the push is rejected, the other side has moved: `git pull --rebase origin develop`, re-run
   the checks below, push again. A rejected push is never fixed by force.

Commit messages match the existing log: plain descriptive prose, a line or a short paragraph, no
Conventional-Commit prefixes, and nothing appended under the message — no trailers, no extra header
lines, no local paths.

## Before you call a change done

There is no test suite and no `tools/` in this repo, so these are the gates that exist. Run them,
and say which ones you ran.

1. `luac5.1 -p <file>` over every `.lua` you touched. The client embeds Lua 5.1: no `goto`, no
   `//`, `unpack` and not `table.unpack`. If the toolchain is not installed, write "not
   syntax-checked" instead of implying a pass.
2. `grep -rnE '^[[:space:]]*--' SoundAlerter/` returns nothing — the comment rule, checked
   rather than trusted.
3. A behaviour change ships with its README.md edit in the same commit, and the README version
   badge and the TOC's `## Version` move together and never disagree.
4. Read the changed path end to end, and re-read whatever it reads. Name the command or code path
   you actually checked — in the commit message or the report. "Verified" with nothing behind it
   is the failure this document exists to prevent.
5. Anything touching events, combat lockdown, sound playback, layout or saved variables cannot be
   proven offline. List it as an in-game check for th3pajay rather than claiming it works.

## Standing rules

- **Zero comments in `SoundAlerter/`.** Not even for non-obvious logic. Identifiers
  and structure carry the explanation; this holds even when you're sure a comment
  would help — it won't survive review.
- **README.md updates ship in the same commit as the code change it describes**,
  never as a follow-up. A commit that changes behavior without touching README is
  incomplete, not just undocumented.
- **Verify before you claim.** If you're reporting what a change does, re-check it
  against the actual code path, not what the change was intended to do — this
  addon's detection logic has broken before from a fix that looked correct but
  missed a shared upvalue.
- **Don't touch claude's in-flight file without saying so first** (and vice versa) —
  `git pull` won't warn you about a conflict claude is mid-edit on; a short heads-up
  in your commit message or to th3pajay avoids clobbering. If you must edit a file the other
  agent committed to most recently, keep the change minimal and name the file in the commit
  message.
- **Never handle a possibly-secret value bare.** Do not compare, concatenate, format, do
  arithmetic on, or key a table with it before scrubbing — `issecretvalue`, `canaccessvalue`.
  An unscrubbed secret throws and taints the addon for the rest of the session, and the damage
  reaches events that have nothing to do with the change.
- **Verify a client call against the target branch's own generated documentation**, not from
  memory of retail or of another client. Where a call shape has to be translated, the translation
  lives in one place, not at every call site.
- **This file is the contract.** It changes by agreement: an edit here rewrites the other agent's
  rules, so say what you changed and why. Everything it says about th3pajay's authority applies
  to it as well.

## When something looks broken

- `Permission denied (publickey)` — the deploy key is unregistered or its write access is
  unticked. Ask th3pajay; do not switch credentials.
- `push` rejected, non-fast-forward — the other side pushed. Rebase, re-check, push.
- Nothing fires in game while the code reads correctly — check whether the path touches restricted
  combat data, and whether a secret value is handled unscrubbed. Both fail silently, and neither is
  a registration bug.
