# Multi-Deployment Strategy — Recommendation

> Status: **Proposal / for decision** · Updated: 2026-08-29 · Scope: how to manage
> a **growing set of Home Assistant homes** (`master` = 841 N 4th,
> `shore-house` = 827 Pennlyn, **a third home now planned**, and more over time)
> long-term.
>
> This is a written recommendation only — no config has been migrated. See
> [Next steps](#next-steps) for how far to take it.

## TL;DR

Branches are being used as long-lived environment forks, which makes porting
changes between homes painful — and that pain grows linearly with each new house.
**With a third home now planned, adopt Option B: one branch, with each home's
differences isolated in Home Assistant
[`packages/`](https://www.home-assistant.io/docs/configuration/packages/)
selected per-machine via `secrets.yaml`.** Do the generated-file cleanup as step 0.

The earlier "just cherry-pick between branches" answer (Option A) only held while
there were two homes. At three or more, per-change porting is O(N) hand-work with
an O(N) chance to miss a home — the structure now pays for itself.

---

## What the two branches actually look like today

Diffing `master` against `shore-house`:

- **102 files changed, ~74k insertions / ~2k deletions** since the merge base
  (`9c6757e`, "fixed url config location").
- Both branches carry **~30 commits the other doesn't**. `shore-house` even has
  commits named "updates from master" — manual porting is already happening.

### Legitimate, site-specific differences

- **Different residents.** `master`: drama, hal, jake, jose, julian, nate, yariv,
  hermes. `shore-house`: becky, howie, john, mary, oren. Different `people/`,
  `customizations/`, and profile images.
- **Different identity/location.** Home name `841 N 4th` vs `827 Pennlyn`;
  zone secret keys `zone_841n4th_*` vs `zone_ocnj_*`.
- **Different devices.** Shore has a Lyric thermostat, LIFX, Google Cast; master
  has a different media/lock/light mix.
- **Different dashboards/views** for different rooms.

### Divergence that is *noise*, not real config

- **Committed generated/runtime files on `shore-house`** that should be ignored
  (they predate the current `.gitignore`): `.xbox-token.json`, `OZW_Log.txt`,
  `aircast.xml`, `harmony_17514843.conf`, `ip_bans.yaml`, `known_devices.yaml`.
  These inflate the diff substantially.
- **None of the docs exist on `shore-house`** — no `AGENTS.md`, `README.md`,
  `BEST_PRACTICES.md`, or `CONTRIBUTING.md`. What we just wrote lives only on
  `master`.

**Good news:** `shore-house` already uses `!secret` for site values in
`configuration.yaml`, so the secrets-as-seam discipline is partly in place.

---

## The core problem

Git branches are designed for **converging** work (feature → merge → delete), not
for permanently-parallel deployments. Using branches as environment forks means
every shared improvement needs a cherry-pick or a noisy "updates from master"
merge, and divergence only grows over time.

**This scales badly.** With N homes-as-branches, one shared fix must be ported
N−1 times by hand, each an opportunity to miss a home or resolve a conflict
differently. A third home makes this concrete; a fourth makes it worse. The right
structure makes a shared change cost the *same* whether you have two homes or ten:
edit once, every home gets it on next pull.

---

## Options

### Option A — Keep branches, add discipline (only viable at N=2)

Keep one branch per home, but:
1. Purge committed generated files and let `.gitignore` do its job.
2. Make `master` the canonical source for all *shared* structure.
3. Keep anything site-specific in `secrets.yaml` + a small set of clearly-named
   site files. Port shared changes via `git cherry-pick` or periodic merges.

| Pros | Cons |
|------|------|
| No restructure; start today | Porting is O(N) per change — breaks down at 3+ homes |
| Familiar workflow | Diverging person-lists/dashboards keep each diff large |
| | Nothing structurally prevents drift; easy to miss a home |

**Verdict:** fine for two homes, does not scale to three or more. With a third
home planned, this is no longer the target — keep only its **step 1 cleanup** as a
prerequisite for Option B.

### Option B — Single branch + HA `packages/` + per-site selection (recommended, scales to N homes)

One `main` branch holds 100% of shared config. Everything that differs per home is
isolated into a Home Assistant **package** directory per site, with the active
site chosen per-machine by `secrets.yaml` (already per-machine, never committed).

- **Shared:** integrations, templates, reusable cards, automations that apply
  everywhere.
- **Site-specific:** one directory per home —
  `packages/site_841n4th/`, `packages/site_827pennlyn/`,
  `packages/site_<third>/`, … — each holding that home's people, zones,
  dashboards, and devices.
- **Selection:** `configuration.yaml` loads the active home's package via a
  `!secret active_site` value (or a per-machine symlink `packages/active →
  packages/site_xxx`). Adding a home = add one `packages/site_<new>/` directory
  and point that machine's `secrets.yaml` at it. No new branch, no porting.

| Pros | Cons |
|------|------|
| One branch, one history — **no porting**, at any home count | One-time migration to sort shared vs site |
| A shared fix reaches every home on next pull | Requires discipline: site specifics must stay inside a package |
| **Adding home N+1 is O(1):** one new package dir | |
| Site differences are explicit and contained | |

### Option C — Shared base branch + thin per-site overlay branches

A `base` branch holds shared config; `master` and `shore-house` become thin
overlays that only add site files and merge `base` regularly.

| Pros | Cons |
|------|------|
| Clean shared/site separation | Three branches to track |
| Less noise than today | Still merging `base` into two overlays |
| | More moving parts than Option B |

---

## Recommendation

**Adopt Option B (single branch + packages). Do the generated-file cleanup as
step 0.**

The lazy-senior read still applies — build the least structure that removes the
work — but the answer changes with the home count. At two homes, cherry-picking was
cheaper than a migration, so waiting was correct (YAGNI). A **third home is the
evidence** that per-change porting is now repetitive O(N) toil, and the laziest way
to stop doing repetitive work forever is to build the seam once. Packages make a
shared change cost the same at 3 homes as at 10, and make adding home N+1 a
one-directory operation. Building it now is the efficient move, not premature.

Do **not** keep expanding the branch-per-home pattern to the third house — that
locks in the O(N) porting you're trying to escape.

### Step 0 — Cleanup (do first, on every branch)

`git rm --cached` the committed generated files — `.xbox-token.json`,
`OZW_Log.txt`, `aircast.xml`, `harmony_*.conf`, `ip_bans.yaml`,
`known_devices.yaml` (already in `.gitignore`). Removes most of the diff noise so
the shared-vs-site reconciliation is tractable.

### Migration to packages

1. **Classify** every file as *shared* or *site-specific* (generate from the
   branch diff).
2. **Create a package dir per home:** `packages/site_841n4th/`,
   `packages/site_827pennlyn/`, and `packages/site_<third>/`. Move each home's
   people, zones, dashboards, and devices into its dir.
3. **Wire it up:** load `packages/active/` in `configuration.yaml`; each machine's
   `secrets.yaml` selects its site (`active_site`) or symlinks `packages/active`.
4. **Reconcile** the branches' shared config into one `main` (the one genuinely
   fiddly step — resolving where they drifted on shared files).
5. **Onboard the third home** directly as a new package dir — no branch.
6. **Retire** the deployment branches once `main` runs every home.

Option C (shared base + overlay branches) is strictly more moving parts than B for
the same benefit, and also scales poorly with home count — skip it.

---

## Open decisions

- **How far to take this now:** (a) recommendation only [this doc], (b) also
  produce the shared-vs-site file inventory to make the migration concrete, or
  (c) draft the full migration to packages.
- **Third home:** onboard it directly as a `packages/site_<third>/` directory
  during the migration, rather than cutting a third branch.
- **Docs gap:** only `master` has the repo docs (`README.md`, `BEST_PRACTICES.md`,
  `CONTRIBUTING.md`, `AGENTS.md`). Under Option B this resolves itself — one
  `main` branch means one copy of the docs for every home.

## Next steps

This document is the deliverable for the "recommend a multi-deployment strategy"
task. No implementation has been performed. The recommendation is **Option B**;
pick an "how far" scope above to proceed. The cheapest concrete first action is
Step 0 (remove committed generated files), which is safe and useful regardless.
