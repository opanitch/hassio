# Per-site packages

Each home's site-specific config lives in its own package directory here. The
shared `configuration.yaml` loads exactly one via a **per-machine symlink**,
pulling in only that site's orchestrator file (fixed name `_site_package.yaml`):

```
homeassistant:
  packages:
    active_site: !include packages/active/_site_package.yaml
```

> Do **not** use `!include_dir_named packages/active/` here: that walks the site
> directory and treats every leaf file (`people/*.yaml`, `zones/*.yaml`, the
> lock templates, etc.) as its own package, which fails package-schema
> validation and spams "Invalid package definition" warnings. Load the single
> `_site_package.yaml` orchestrator instead — it `!include`s the rest.

```
packages/
  site_841n4th/          # main house — people, zones, customizations
    _site_package.yaml   #   site orchestrator (fixed name, loaded by config)
  site_827pennlyn/       # shore house
    _site_package.yaml
  site_<third>/          # add a home = add a dir (no new branch)
  active -> site_841n4th # per-machine symlink, GITIGNORED (never committed)
```

## What belongs in a site package

- `person:` (this home's residents) — `packages/active/people/`
- `zone:` (this home's zones) — `packages/active/zones/`
- `homeassistant.customize:` (per-entity UI for those people) — `packages/active/customizations/`
- `automation:` (each home's own automations) — `packages/active/automations.yaml`
- `switch:` / `input_number:` / `input_select:` (device-tied helpers) —
  `packages/active/{switches,inputs}/`
- Site-only devices/integrations (e.g. `nest:` at 841; shore's Lyric is UI-only).

**UI is separate:** Lovelace is not part of the package system, so per-site views,
components, and dashboards live under `app/site_<home>/`, selected by a second
per-machine symlink `app/active` (loaded via
`lovelace: !include app/active/config/ui-config.yaml`). No shared UI exists today;
a future `app/shared/` can hold truly-shared views/cards that a site view
`!include`s explicitly.

**Not** in a site package: anything shared across homes (shared integrations,
templates) stays in the top-level config.

The site package entry file (`site_<home>/_site_package.yaml`, a fixed name so
the shared config can load it through the `packages/active` symlink) references
its
subdirs by **package-relative** path (`people/`, `zones/`, `customizations/`,
`nest_config.yaml`). HA resolves `!include` inside a package relative to the
including file's own directory (`packages/active/`), so do **not** prefix paths
with `packages/active/` — that doubles to `packages/active/packages/active/…` and
fails to load. The same entry file works for whichever site is active because it
is reached through the `packages/active` symlink.

## Per-machine setup (run once on each home's device)

Two per-machine symlinks select this home's config and UI (`packages/active` for
the backend, `app/active` for the UI). Both are gitignored and must exist
**before** validating. Use the helper script:

```bash
scripts/hass-site.sh 841n4th        # main house  (827pennlyn for the shore house)
scripts/hass-site.sh                # show current selection + available sites
```

Optionally add a shell function to `~/.zshrc` / `~/.bashrc`:

```bash
hass-site() { "$HOME/config/scripts/hass-site.sh" "$@"; }   # adjust path to your config dir
```

Equivalent manual form (what the script does):

```bash
ln -sfn site_841n4th packages/active && ln -sfn site_841n4th app/active
```

Then create `secrets.yaml` (see `secrets.example.yaml`) with this machine's
`site_name`, `site_latitude`, `site_longitude`, `site_elevation`, and the rest.

## Validation order

1. `scripts/hass-site.sh <home>` to set both symlinks (must exist first, or the
   includes resolve to nothing).
2. Ensure `secrets.yaml` has the site keys.
3. `ha core check`.
4. `ha core restart` — a **full restart is required** when dashboard `filename:`
   mappings change (a config check/reload keeps the old in-memory mapping and
   throws `FileNotFoundError` on the old path). Dashboard `filename:` values are
   **config-relative, no leading slash** (e.g. `app/active/dashboard-admin.yaml`).
5. Confirm entities actually populate (Developer Tools → States: `person.*`,
   `zone.home`, and dashboards in the sidebar) — `ha core check` tolerates a
   missing `!include_dir_*` silently, so a passing check alone is not proof.

## Adding a new home

1. `mkdir -p packages/site_<home>/{people,zones,customizations}` and add a
   `_site_package.yaml` entry file (copy an existing one; the entry file uses
   this fixed name in every site so the shared `configuration.yaml` loads it via
   the `packages/active` symlink). Add `app/site_<home>/` for its UI.
2. Fill in that home's people/zones/customizations/automations and views.
3. On that home's device: `scripts/hass-site.sh <home>`, create `secrets.yaml`,
   then `ha core check`. The new site is auto-discovered by the script (no edit
   needed) once `packages/site_<home>/` and `app/site_<home>/` both exist.
