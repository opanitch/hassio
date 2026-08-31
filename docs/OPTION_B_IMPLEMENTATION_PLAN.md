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
- **Site-specific integrations live in the site package, not shared config.**
  Confirmed cases moved out of `configuration.yaml`: `nest:` (841 only; shore uses
  a UI-configured Honeywell Lyric) and `automation:` (each home has its own
  automations — 841 has 22, shore has 2). Rule for the shared-drift pass: anything
  that references a device/entity/secret only one home has belongs in that home's
  package.
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

## Phase 2 — Shore-house reconciliation (`site_827pennlyn`)  ✅ complete (both homes pass ha core check 2026-08-30)

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
- [ ] **Shared-drift reconciliation** (by category, owner sign-off per category):
  - [x] **Integrations** — per-device, none shared. Moved live device integrations
        into each site package (`light:`/`sensor:`/`template:` declared per-site,
        not root; `tts:` is the only shared integration). Deleted all deprecated /
        UI-migrated / unwired / 0-active-line files per `configuration.yaml` as the
        source of truth (~20 files). Parse + resolution validated; **awaiting device
        check on both homes.**
  - [ ] **Templates** — folded into integrations move above (front-lock, maria,
        vacuums per-site; date-time shared-but-duplicated). Confirm on device check.
  - [x] **Groups** — per-site. 841 has `light_groups` + `person_group` (moved to
        its package, `group:` declared there); shore uses no groups. Deleted dead
        shells (`front_door_lock` fully commented, `presence_devices` empty).
        Removed shared `group:` from root. Parse/resolution validated.
  - [ ] **Switches/inputs** — already moved to packages (Phase 3).
  - [x] **`configuration.yaml` enablers** — adopted shore's shared additions:
        `browser:`, `map:`, `schedule:` (`internal_url` already set by owner as
        desired). Site-specific keys handled per-site; kept `my:`.
  - [x] **Blueprints** — added shore's 4 stock HA blueprints at root (shared) and
        removed the stock-blueprint `.gitignore` rules so both homes track them.
  - [x] **device_tracker** — per-site (841 Verizon quantum_gateway, shore Netgear);
        moved into each package, removed shared include, added `router_user` to
        secrets template.
  - [x] **scenes** — dead on both homes (`[]` shell); deleted, dropped shared
        `scene:` include. Add per-site later if needed.
  - [x] **profile images (`www/`)** — no action: referenced via `!secret
        *_profile_home` paths, already per-machine.
  - **Shared-drift reconciliation COMPLETE.** Shared config now = `default_config`,
    `homeassistant` (site-neutral), `http`, enablers, `tts`, `frontend`/`lovelace`
    wiring, `packages`. Everything else is per-site or deleted.

## Phase 3 — Per-site UI / dashboards (Design B)  ✅ complete (both homes validated 2026-08-30)

Whole `app/` tree is per-site today (no shared UI yet). Implemented via a second
per-machine symlink `app/active -> app/site_<home>/`.

- [x] Move switches (flux/harmony) + inputs (yamaha, waze) into each site package
      as `switch:`/`input_number:`/`input_select:`; drop shared `switch:` include.
- [x] Restructure UI into `app/site_841n4th/` and `app/site_827pennlyn/`
      (views, components, config/ui-config, dashboard metadata, dashboard entry files).
- [x] `lovelace: !include app/active/config/ui-config.yaml`; `app/active` symlink
      created + gitignored.
- [x] Fix internal paths: dashboard entry `!include views/…` (relative-to-file);
      metadata `filename: app/active/…` (config-root through symlink); view→component
      `../components/…` unchanged (already correct).
- [x] Parse + full include-chain validated for both sites (lovelace → ui-config →
      dashboards metadata → filename targets → views → components all resolve).
- [x] **Device check — 841 (owner):** dashboards + views load (2026-08-30).
      Gotcha found: dashboard `filename:` changes need a **full `ha core restart`**
      (a config check/reload keeps the old in-memory mapping → `FileNotFoundError`
      on the pre-migration path). `filename:` must be **config-relative, no leading
      slash** (`app/active/dashboard-admin.yaml`) — an absolute `/config/...` form
      is wrong. Symlinked subdir works.
- [x] **Device check — shore (owner):** dashboards + views load and `ha core check`
      passes on shore with `site_827pennlyn` (2026-08-30).
- [ ] Future (only when needed): add `app/shared/` for truly-shared views/cards.

## Phase 4 — Cutover  ~ merged locally, push pending

- [x] Both homes validated on the single branch (`ha core check` passes on both).
- [x] Update `README.md` deployment section (branches → packages).
- [x] Merge `packages-migration` → `master` (`--no-ff`, local; not pushed).
      No rename (owner: keep `master`).
- [ ] **Push `master`** (owner to run/approve — not pushed automatically).
- [ ] Retire `shore-house` branch — **deferred** (owner: leave for now as safety net).
- [ ] Optional cleanup: delete local `packages-migration` after push confirms `master`.

## Phase 5 — Third home  ⛔ not started (later, per owner)

- [ ] `packages/site_<third>/` scaffold (people/zones/customizations + entry file).
- [ ] Device check on the third home (symlink + `secrets.yaml` + `ha core check`).

## Commits on this branch

See `git log master..packages-migration` for the full, authoritative list (the
migration spans many commits: docs checkpoint, site_841n4th, site_827pennlyn,
nest + automations + switches/inputs moves, the include-path fix, and the app/
per-site restructure). A hand-maintained table drifts, so it's intentionally
omitted here.

**Validated on real hardware:** `ha core check` passed on both the main-house
(841) and shore (827 Pennlyn) devices on 2026-08-30 for the site packages
(Phase 1 + 2 backend). Phase 3 (UI) awaits its device check.

## Follow-ups (tracked, not blocking the migration)

- [ ] **`mode: yaml` dashboard deprecation.** The dashboard definitions in
      `app/site_*/config/dashboards/*.yaml` use `mode: yaml`, which HA has flagged
      as legacy and slated for removal (~2026.8). Migrate the dashboard-definition
      mechanism separately from this migration; the per-site UI layout above is
      unaffected by how dashboards are *declared*.
- [ ] **Per-machine setup script.** Add a shell helper (e.g. `hass-site <home>` in
      `.zshrc`/`.bashrc`) that sets both symlinks at once:
      `ln -sfn site_<home> packages/active && ln -sfn site_<home> app/active`.
      Reduces the two-symlink setup to one command.

## Known risks / notes

- **Valid YAML ≠ still-supported platform.** File audits (active-line count +
  "DEPRECATED" notes) miss well-formed YAML for a platform HA has since removed
  from YAML config (e.g. `device_tracker: platform: netgear` → now UI-only). Only
  a real `ha core check`/restart on-device surfaces these. shore's netgear tracker
  hit this; 841's `quantum_gateway` is still YAML-valid. Watch for it on any home.

- **Include paths inside a package are relative to the including file's dir**
  (`packages/active/`), confirmed on-device. Use bare paths (`people/`,
  `nest_config.yaml`); never prefix with `packages/active/`. If person/zone lists
  ever load empty, check this first — `!include_dir_*` tolerates a missing dir
  silently (no error, just no entities), whereas a single-file `!include` errors.
- `hermes` references `!secret hermes_id`; `secrets.yaml` must define it or the
  check fails on a missing secret.
- No config has been applied to a live HA instance yet — Phase 1 device check is
  the first real validation.
