# Per-site packages

Each home's site-specific config lives in its own package directory here. The
shared `configuration.yaml` loads exactly one via a **per-machine symlink**:

```
homeassistant:
  packages: !include_dir_named packages/active/
```

```
packages/
  site_841n4th/          # main house — people, zones, customizations
  site_827pennlyn/       # shore house
  site_<third>/          # add a home = add a dir (no new branch)
  active -> site_841n4th # per-machine symlink, GITIGNORED (never committed)
```

## What belongs in a site package

- `person:` (this home's residents) — `packages/active/people/`
- `zone:` (this home's zones) — `packages/active/zones/`
- `homeassistant.customize:` (per-entity UI for those people) — `packages/active/customizations/`
- Site-only devices (a thermostat/receiver only this home has).

**Not** in packages: anything shared across homes (shared integrations,
templates, reusable dashboard cards) stays in the top-level config. Lovelace
dashboards are not part of the package system and are handled separately.

The site package entry file (e.g. `site_841n4th/site_841n4th.yaml`) references its
subdirs by config-root path through the symlink (`packages/active/people/`), so
the same file works for whichever site is active.

## Per-machine setup (run once on each home's device)

`packages/active` is per-machine and gitignored. After cloning/pulling, point it
at this machine's home **before** validating:

```bash
# from the config root
ln -sfn site_841n4th   packages/active   # main house
# ln -sfn site_827pennlyn packages/active # shore house
```

Then create `secrets.yaml` (see `secrets.example.yaml`) with this machine's
`site_name`, `site_latitude`, `site_longitude`, `site_elevation`, and the rest.

## Validation order

1. `ln -sfn site_<home> packages/active` (symlink must exist first, or
   `packages/active/` resolves to nothing).
2. Ensure `secrets.yaml` has the site keys.
3. `ha core check`.
4. `ha core restart`.

## Adding a new home

1. `mkdir -p packages/site_<home>/{people,zones,customizations}` and add a
   `site_<home>.yaml` entry file (copy an existing one; filenames must be
   globally unique across the packages tree).
2. Fill in that home's people/zones/customizations.
3. On that home's device: `ln -sfn site_<home> packages/active`, create
   `secrets.yaml`, then `ha core check`.
