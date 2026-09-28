# Agents on this repo

This repo (`soundalerter-forever`) showcases agentic collaboration: two AI agents,
**claude** and **hermes**, committing to the same codebase under their own names,
alongside th3pajay (human maintainer, final say on everything).

## What you're working on

SoundAlerter - Forever: a voice/visual PvP alert addon for the WoW Forever client
(README.md has the full feature list). `COMBAT_LOG_EVENT_UNFILTERED` is permanently
restricted on this client — every detection path here is nameplate/unit-event based,
never combat-log based. Do not reintroduce combat-log-dependent detection; it will not
work on this client.

Tracked paths: `SoundAlerter/` (addon code), `Media/`, `README.md`, `.gitignore`.
Nothing else belongs in this repo — no workspace notes, no IDE config, no memory files.

## One-time setup (hermes, do this first)

1. Generate an SSH key on the rpi4b: `ssh-keygen -t ed25519 -C "hermes-soundalerter"`
   (empty passphrase is fine for a machine key; do not reuse a key from another repo).
2. Give th3pajay the **public** key. They add it as a repo Deploy Key with write access
   on GitHub (Settings -> Deploy keys). You never get a GitHub account or PAT — the
   deploy key is push access, scoped to this repo only.
3. Set local git identity **in this repo only** (not `--global`):
   ```
   git config user.name "hermes"
   git config user.email "hermes@users.noreply.github.com"
   ```
4. Clone via SSH and check out `develop`:
   ```
   git clone git@github.com:th3pajay/soundalerter-forever.git
   git checkout develop
   ```

## Every session

1. `git pull origin develop` before touching anything — claude or th3pajay may have
   pushed since your last session.
2. Work on `develop` directly (direct-push model, no PR gate). If your change is large
   or risky, say so in the commit message rather than splitting into a branch nobody
   will merge.
3. Commit as yourself — identity is already set from step 3 above, verify with
   `git config user.name` before your first commit if unsure.
4. `git push origin develop`. `main` is release-only; only th3pajay merges
   `develop` -> `main`.

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
  in your commit message or to th3pajay avoids clobbering.
