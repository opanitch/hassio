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
- **Site package includes use package-relative paths** (bare `people/`, `zones/`,
  `nest_config.yaml`). HA resolves `!include` inside a package **relative to the
  including file's directory** (`packages/active/`), so a `packages/active/…`
  prefix would double to `packages/active/packages/active/…` and fail. Verified on
  the 841 device (a `packages/active/nest_config.yaml` include produced
  `.../packages/active/packages/active/nest_config.yaml: unable to read file`).
- **`configuration.yaml` is site-neutral**: `name`/`latitude`/`longitude`/
  `elevation` read `site_*` secrets; each machine's `secrets.yaml` carries values.
- **`auth_providers` stays in `configuration.yaml`** (HA processes it before
  packages — per HA docs).
- **Lovelace dashboards are NOT packages** (separate `lovelace:` system); per-site
  dashboards need their own symlink seam — deferred to Phase 3.

## Phase 0 — Checkpoint & branch

- [x] Commit pending docs on `master` as a checkpoint (`0b6415e`).
- [x] Create `packages-migration` branch from `master`.

## Phase 1 — Main-house package (`site_841n4th`)  ✅ complete (validated 2026-08-30, incl. include-path fix)

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
- [x] **Device check (owner):** on main-house device — pulled branch, set
      `secrets.yaml` `site_*` keys, `ln -sfn site_841n4th packages/active`,
      `ha core check` passed (2026-08-30) — **but this was a partial false positive:**
      the buggy `packages/active/...` include paths made `!include_dir_*` resolve to
      a missing dir (silently empty), so people/zones likely loaded empty while the
      check still passed. Include paths fixed in `5196ec6`.
- [x] **Re-verify 841 (owner):** pulled fix, `ha core check` passed (2026-08-30).
- [x] **Shore device check (owner):** `ha core check` passed on shore with
      `site_827pennlyn` — no nest-secret error (2026-08-30).

## Phase 2 — Shore-house reconciliation (`site_827pennlyn`)  ~ in progress

**Which branch is the newer shared baseline?** Both were last actively worked on
2026-04-12. `shore-house`'s last real work is slightly later that day and includes
"update to new OS" + template modernizations (e.g. `vacuums-cleaning-status.yaml`),
so **bias toward shore's version on HA-compat/integration/template files**.
`master` has a later "automation backups" commit (2026-06-23) shore lacks — flag
the automations delta specifically.

- [x] Build `packages/site_827pennlyn/` from shore's people/zones/customizations
      (Home zone auto-follows host via `site_*`; keeps site-only `location.oren.yaml`).
      Parse-validated; symlink resolution confirmed.
- [x] **Device check (owner):** shore `ha core check` passed with `site_827pennlyn`
      and OCNJ `site_*` values (2026-08-30). Nest correctly not loaded on shore.
- [x] **Step 0 cleanup:** the generated files are only *added* on `shore-house`;
      not brought over to the packages branch. (`.gitignore` already covers them.)
- [ ] **Shared-drift reconciliation:** produce a per-file classification table
      (improvement to adopt / site-specific → move to package / divergence → pick
      one) for the ~40 differing shared files, get owner sign-off, then apply.

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
| `d9dd5d5` | keep coordinates as placeholders; document site_* vs zone catalog |

**Phase 1 validated on real hardware:** `ha core check` passed on the main-house
device on 2026-08-30 with the packages layout + symlink + `site_*` secrets.

## Known risks / notes

- **Include paths inside a package are relative to the including file's dir**
  (`packages/active/`), confirmed on-device. Use bare paths (`people/`,
  `nest_config.yaml`); never prefix with `packages/active/`. If person/zone lists
  ever load empty, check this first — `!include_dir_*` tolerates a missing dir
  silently (no error, just no entities), whereas a single-file `!include` errors.
- `hermes` references `!secret hermes_id`; `secrets.yaml` must define it or the
  check fails on a missing secret.
- No config has been applied to a live HA instance yet — Phase 1 device check is
  the first real validation.
