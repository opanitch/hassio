# Option B Implementation Plan — Single Branch + HA Packages

> Status: **in progress** · Updated: 2026-08-30 · Branch: `packages-migration`
> (cut from `master`; `master` is the safe fallback).
>
> Migrates the multi-home setup from branch-per-home to one branch where each
> home's site-specific config lives in `packages/site_<home>/`, selected per
> machine by a gitignored `packages/active` symlink. Rationale and options in
> [`MULTI_DEPLOYMENT_RECOMMENDATION.md`](./MULTI_DEPLOYMENT_RECOMMENDATION.md).

## Legend

- [x] done · [ ] not started · [~] partially done
- Authoritative validation (`ha core check`) runs on a real HA device, not in the
  dev environment — the dev environment only confirms YAML parses structurally.

## Key design decisions (settled)

- **Site selection = per-machine symlink** `packages/active -> packages/site_<home>/`
  (gitignored). HA `!secret` can't be interpolated into an `!include` path, which
  rules out a secret-driven path; the symlink is the least-code option that works.
- **Site package includes use config-root paths through the symlink**
  (`packages/active/people/`), not relative-to-file paths — avoids ambiguity in
  how HA resolves relative includes through a symlinked dir.
- **`configuration.yaml` is site-neutral**: `name`/`latitude`/`longitude`/
  `elevation` read `site_*` secrets; each machine's `secrets.yaml` carries values.
- **`auth_providers` stays in `configuration.yaml`** (HA processes it before
  packages — per HA docs).
- **Lovelace dashboards are NOT packages** (separate `lovelace:` system); per-site
  dashboards need their own symlink seam — deferred to Phase 3.

## Phase 0 — Checkpoint & branch

- [x] Commit pending docs on `master` as a checkpoint (`0b6415e`).
- [x] Create `packages-migration` branch from `master`.

## Phase 1 — Main-house package (`site_841n4th`)  ✅ built, ⏳ awaiting device check

- [x] Create `packages/site_841n4th/` and `packages/site_827pennlyn/` dirs.
- [x] Move `people/`, `locations/`→`zones/`, `customizations/` into
      `site_841n4th/` via `git mv` (history preserved). (`e3ab89f`)
- [x] Add `site_841n4th.yaml` package entry wiring `person:` / `zone:` /
      `homeassistant.customize:` via `packages/active/…`.
- [x] Make `configuration.yaml` site-neutral (`site_name`, `site_latitude`,
      `site_longitude`, `site_elevation`); remove root `person:`/`zone:`/
      `customize:` includes; add `packages: !include_dir_named packages/active/`.
- [x] Create `packages/active` symlink → `site_841n4th`; gitignore it.
- [x] Add `site_*` keys to `secrets.example.yaml`.
- [x] Add `packages/README.md` (layout, per-machine setup, validation order).
- [x] Mark `hermes` as intentionally-incomplete system user (`79f2c1d`).
- [x] Structurally parse-validate all files + confirm symlink resolves
      (9 people / 5 zones / 8 customizations).
- [ ] **Device check (owner):** on main-house device — pull branch, ensure
      `secrets.yaml` has `site_*` keys (and `hermes_id`, or comment out hermes),
      `ln -sfn site_841n4th packages/active`, run `ha core check`, share output.
- [ ] Fix anything the device check surfaces.

## Phase 2 — Shore-house reconciliation (`site_827pennlyn`)  ⛔ not started

- [ ] **Step 0 cleanup:** `git rm --cached` committed generated files that live on
      `shore-house` (`.xbox-token.json`, `OZW_Log.txt`, `aircast.xml`,
      `harmony_*.conf`, `ip_bans.yaml`, `known_devices.yaml`).
- [ ] Classify shore-house files: shared-config drift vs site-specific.
- [ ] Fold shore's **shared** improvements into the single branch (the one
      genuinely fiddly step — resolve where the branches drifted on shared files).
- [ ] Populate `packages/site_827pennlyn/` (people/zones/customizations + shore-only
      devices: Lyric, LIFX, Google Cast) with a `site_827pennlyn.yaml` entry file.
- [ ] Ensure shore's `secrets.yaml` maps `site_*` keys to `827 Pennlyn` / OCNJ.
- [ ] **Device check (owner):** on shore device — symlink to `site_827pennlyn`,
      `ha core check`.

## Phase 3 — Per-site dashboards (Lovelace)  ⛔ not started

- [ ] Design the dashboard symlink seam (packages don't cover `lovelace:`).
- [ ] Split site-specific views from shared reusable cards.
- [ ] Wire per-site dashboards through a `dashboards/active` (or equivalent)
      symlink; document per-machine setup.
- [ ] Device check on both homes.

## Phase 4 — Cutover  ⛔ not started

- [ ] Both homes validated on the single branch.
- [ ] Merge `packages-migration` → `master` (rename to `main` optional).
- [ ] Retire `shore-house` branch.
- [ ] Update `README.md` deployment section (branches → packages) and remove the
      "open question" note.

## Phase 5 — Third home  ⛔ not started (later, per owner)

- [ ] `packages/site_<third>/` scaffold (people/zones/customizations + entry file).
- [ ] Device check on the third home (symlink + `secrets.yaml` + `ha core check`).

## Commits on this branch

| Commit | Summary |
|--------|---------|
| `0b6415e` | docs checkpoint (on `master`): README, BEST_PRACTICES, CONTRIBUTING, secrets template, recommendation |
| `e3ab89f` | migrate main-house site config into `packages/site_841n4th`; site-neutral config; symlink selection |
| `79f2c1d` | mark hermes as intentionally-incomplete system user |

## Known risks / notes

- Relative-include-through-symlink behavior was avoided rather than relied on
  (config-root paths). If the device check ever shows empty person/zone loading,
  re-examine this first.
- `hermes` references `!secret hermes_id`; `secrets.yaml` must define it or the
  check fails on a missing secret.
- No config has been applied to a live HA instance yet — Phase 1 device check is
  the first real validation.
