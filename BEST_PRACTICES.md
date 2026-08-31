# Home Assistant Configuration — Best Practices

This is the **standalone, comprehensive authoring guide** for this repository. It
documents *how* to build and maintain the Home Assistant (HA) configuration:
dashboards, integrations, templates, automations, secrets, naming, and validation.

Read this before making changes. If a section grows too large, we will split it
into dedicated `RULES`/`SKILLS` docs and link them from here.

> `AGENTS.md` intentionally defers to this document for authoring guidance and
> only keeps a short pointer. Keep working conventions here, not there.

## Table of Contents

1. [Golden Rules](#1-golden-rules)
2. [Repository Structure & Include Model](#2-repository-structure--include-model)
3. [Secrets Management](#3-secrets-management)
4. [Naming Conventions](#4-naming-conventions)
5. [Dashboards & Lovelace](#5-dashboards--lovelace)
6. [Integrations](#6-integrations)
7. [Templates & Sensors](#7-templates--sensors)
8. [Automations & Scripts](#8-automations--scripts)
9. [Groups, People, Zones & Customizations](#9-groups-people-zones--customizations)
10. [Custom Components](#10-custom-components)
11. [Validation & Testing](#11-validation--testing)
12. [Git Workflow](#12-git-workflow)
13. [Multi-Deployment Notes](#13-multi-deployment-notes)

---

## 1. Golden Rules

- **Validate before you commit.** Run `ha core check` (or
  `homeassistant --script check_config -c .`) on every change.
- **Never commit secrets.** No tokens, coordinates, hosts, or credentials in
  tracked YAML. Everything sensitive goes through `!secret`.
- **One concept per file.** Prefer many small, scoped files over large monoliths.
  The include model (below) is built for this.
- **Keep entity IDs stable.** Renaming an entity or automation `id` breaks
  dashboards, automations, and history. Change display `name`, not the ID.
- **Comment intent, not syntax.** Explain *why* a card, template, or automation
  exists — future-you will thank you.
- **Match the existing pattern.** When in doubt, copy the structure of a nearby
  file rather than inventing a new layout.

---

## 2. Repository Structure & Include Model

`configuration.yaml` is the orchestrator. It wires everything else in with
`!include` directives; you rarely add config inline there — you add a file to the
right directory and (if needed) an include.

### Include directives used in this repo

| Directive | Behavior | Used for |
|-----------|----------|----------|
| `!include file.yaml` | Inlines one file | Single-block config (`http`, `nest`, `automations.yaml`) |
| `!include_dir_list dir/` | Merges files into a **list** | `people/`, `locations/` (zones) |
| `!include_dir_merge_list dir/` | Concatenates list items across files | `integrations/lights/`, `sensors/`, `templates/`, `switches/`, `scenes/`, `binary_sensors/` |
| `!include_dir_named dir/` | Builds a **dict** keyed by filename | `customizations/`, dashboards |
| `!include_dir_merge_named dir/` | Merges dict entries across files | `groups/` |
| `!secret key` | Resolves a value from `secrets.yaml` | Any sensitive value |

**Rule of thumb:** the directive is chosen by the *platform's* expected shape.
Lights/sensors/switches expect a **list**, so they use `merge_list`. Groups and
customizations are **dicts keyed by name**, so they use `named`. Don't mix these
up — a list file dropped into a `named` include will fail validation.

### Where things live

```
configuration.yaml          # orchestrator + include graph
automations.yaml            # all automations (single file, HA UI-managed format)
scripts.yaml                # scripts (currently empty/commented)
dashboard-admin.yaml        # admin Lovelace entrypoint -> includes app/views/*
dashboard-user.yaml         # user Lovelace entrypoint -> includes app/views/*
ui-lovelace.yaml            # default dashboard -> !include dashboard-user.yaml
app/
  config/ui-config.yaml     # declares YAML dashboard mode + dashboards dir
  config/dashboards/        # dashboard metadata (admin/user panels)
  views/                    # one file per room/area (Lovelace views)
  components/               # reusable cards (presence, status/*)
  switches/                 # switch platform definitions (merge_list)
  inputs/                   # helper entities (input_number, etc.)
integrations/<domain>/      # one folder per HA platform/domain
authentication/             # auth providers, MFA, http/TLS, DuckDNS, trusted nets
groups/ people/ locations/  # groups (merge_named), persons (list), zones (list)
customizations/             # per-entity UI metadata (named)
scenes/ blueprints/ www/    # scenes, stock blueprints (gitignored), static assets
custom_components/          # first-party/bundled Python (gitignored by default)
```

### Adding something new — decision flow

1. Is it a **device/platform integration**? → `integrations/<domain>/<name>_config.yaml`.
2. Is it a **UI page**? → `app/views/<area>-view.yaml`, then reference it from a
   `dashboard-*.yaml`.
3. Is it a **reusable card**? → `app/components/...`, then `!include` it from views.
4. Is it a **derived value**? → `integrations/templates/<name>.yaml`.
5. Is it an **automation**? → add to `automations.yaml`.

Then add/uncomment the matching include in `configuration.yaml` **only if the
directory isn't already wired in** (most are).

---

## 3. Secrets Management

**The single most important rule in this repo: secrets never enter git.**

- All sensitive values are referenced via `!secret <key>` and resolved from
  `secrets.yaml` at the repo root.
- `secrets.yaml`, the bare `secrets` file, and any `secrets.*` variant are
  **gitignored**. A committed `secrets.example.yaml` (keys only, no values) is the
  allowed exception and serves as the template.
- The local `secrets` file that may exist on a dev machine is **not** the real
  deployment's secrets and must never be committed.

### What belongs in secrets

- Site geolocation: latitude, longitude, elevation, external/internal URLs.
- Credentials & tokens: DuckDNS token, Roomba host/blid/password, camera creds,
  Nest, Xbox, Plex, etc.
- Anything host- or site-specific: ports, certificate paths, LAN IPs.

### Pattern

```yaml
# configuration.yaml (site-neutral — same on every home)
homeassistant:
  name: !secret site_name
  latitude: !secret site_latitude
  longitude: !secret site_longitude
  external_url: !secret external_url
```

```yaml
# secrets.yaml  (GITIGNORED — never committed; values from LastPass catalog)
site_name: "841 N 4th"
site_latitude: 39.9xxxxx
site_longitude: -75.1xxxxx
external_url: "https://example.duckdns.org"
```

### secrets.example.yaml

Maintain a committed `secrets.example.yaml` listing every required key with a
placeholder value. It doubles as the bootstrap checklist when standing up a new
deployment (or the shore house). Keys — not values.

### Site location vs. known-location catalog

- **`site_*`** (`site_name`, `site_latitude`, `site_longitude`, `site_elevation`)
  always describe **the machine you are setting up**. The shared
  `configuration.yaml` and each home's "Home" zone read these, so the same config
  runs every home — you just point `site_*` at that home's coordinates.
- **`zone_<name>_*`** keys are a **catalog of known locations** (residences,
  workplaces). Each home defines only the zones it cares about — a new home need
  not carry every zone.
- **Real coordinates are never committed.** The template ships placeholders only;
  the authoritative coordinate values live in the **LastPass coordinate catalog**.
  When standing up a machine, copy the relevant numbers from LastPass into that
  machine's gitignored `secrets.yaml`.

> Site-specific secrets are the natural seam between deployments. Keeping *only*
> the values different between homes (while sharing structure) is what makes the
> multi-home setup manageable. See [Multi-Deployment Notes](#13-multi-deployment-notes).

---

## 4. Naming Conventions

- **YAML/JSON indentation:** 2 spaces. **Python** (`custom_components/`): 4-space PEP 8.
- **Filenames:** `snake_case` with a descriptive scope and a `_config` suffix for
  integrations (`waze_drivetime_config.yaml`, `nest_config.yaml`). Views use
  `kebab-case` with a `-view` suffix (`living-room-view.yaml`). Match whatever the
  sibling files already do in that directory.
- **Entity IDs:** `snake_case`, domain-prefixed (`light.kitchen_window`,
  `sensor.date_time_dashboard`). Stable forever once referenced.
- **Automation `id`:** keep the existing numeric IDs stable; only edit `alias`
  and `description` for humans.
- **Python classes:** mirror the platform (`XboxOneDevice`).
- **No spaces, no camelCase** in filenames or entity IDs.

---

## 5. Dashboards & Lovelace

Dashboards run in **YAML mode** (`app/config/ui-config.yaml`,
`resource_mode: yaml`). This means the UI editor is disabled for these dashboards
— all edits happen in files.

### Layering

```
dashboard-admin.yaml / dashboard-user.yaml   # title + list of view includes
        └── app/views/<area>-view.yaml       # one page per room/area
                └── app/components/*.yaml     # reusable cards (!include)
```

### Conventions

- **One view per room/area.** Each `app/views/*-view.yaml` starts with `path`,
  `title`, optional `badges`, then `cards`.
- **Group cards with stacks.** Use `vertical-stack` / `horizontal-stack` / `grid`
  to organize, and comment each logical group (`# lights`, `# media`, `# outlets`)
  as seen in `kitchen-view.yaml`.
- **Reuse via includes.** If a card appears on more than one view, extract it to
  `app/components/` and `!include ../components/<name>.yaml`.
- **Prefer modern card types.** `tile` with `features:` (e.g. `light-brightness`)
  for rich controls; `media-control` for players; `button` for switches.
- **Keep views lean.** Break large pages into included component files to avoid
  frontend lag.
- **Register new views** by adding an `!include app/views/<name>.yaml` line to the
  appropriate `dashboard-*.yaml`. Admin and user dashboards can expose different
  subsets of the same views.

### Example (authentic pattern)

```yaml
path: kitchen
title: Kitchen
badges:
  - entity: sun.sun
  - entity: sensor.time
cards:
  # lights
  - type: vertical-stack
    cards:
      - type: tile
        entity: light.kitchen
        name: Kitchen Lights
        tap_action:
          action: toggle
        features:
          - type: "light-brightness"
```

---

## 6. Integrations

Each device class lives in `integrations/<domain>/` with one `*_config.yaml` per
device or logical unit. Most domains are wired with `!include_dir_merge_list`, so
each file contributes list items to that platform.

### Conventions

- **Scope one integration per file** (`yamaha_config.yaml`, `epson_config.yaml`).
- **Reference secrets, never inline credentials/hosts.**
- **UI-configured integrations** (UniFi Protect, iRobot Roomba, Nest device
  access, Xbox) are set up via *Settings → Devices & Services*, **not** YAML. When
  an integration is UI-managed, leave a documentation file (see
  `integrations/cameras/README.md`) describing hardware, required secrets, and the
  setup steps — do not leave dead YAML pretending to configure it.
- **Deprecated config** should be clearly marked and commented out with a
  migration note, as in `integrations/cleaning/roomba_config.yaml`, rather than
  deleted silently.
- **Commented includes** in `configuration.yaml` (mqtt, upnp, zwave) are staged
  for future use — enable them by uncommenting the include *and* providing the
  backing file.

---

## 7. Templates & Sensors

Template entities live in `integrations/templates/` (merged as a list under the
`template:` integration). Plain sensors live in `integrations/sensors/`.

### Conventions

- **Modern `template:` schema.** Use the list form with `- sensor:` / `- binary_sensor:`
  blocks, each entry having `name`, `state`, and optional `icon`/`attributes`.
- **Quote Jinja.** Always wrap templates in quotes and use `states('...')`,
  `as_timestamp`, `timestamp_custom`, etc.
- **Guard against `unknown`/`unavailable`.** Sensors referenced during startup can
  be missing; default gracefully (`| default(...)`, `is_defined`, availability
  templates) so the whole `template:` block doesn't fail.
- **Descriptive names** map to readable entity IDs
  (`name: "Date time dashboard"` → `sensor.date_time_dashboard`).

```yaml
- sensor:
  - name: "Date time dashboard"
    state: "{{ as_timestamp(states('sensor.date_time_iso')) | timestamp_custom('%A %B %-d, %I:%M %p') }}"
    icon: "mdi:calendar-clock"
```

---

## 8. Automations & Scripts

Automations live in the single `automations.yaml` (HA UI-managed format).

### Conventions

- **Keep `id` stable, edit `alias`/`description`.** IDs tie history and traces.
- **Always set a human `alias`** and a `description` explaining the intent.
- **Structure:** `trigger` → `condition` → `action`. Prefer explicit `condition`
  blocks over cramming logic into templates.
- **Prefer entity/state triggers over device IDs** where practical — device IDs
  (`device_id: 25b2...`) are opaque and break if the device is re-paired. Some
  existing automations use device triggers; new ones should favor `state`,
  `numeric_state`, or `template` triggers tied to stable entity IDs.
- **Reload, don't always restart.** Use *Developer Tools → YAML → Reload
  Automations* for iteration; restart HA only when includes/integrations change.
- **Scripts** go in `scripts.yaml` (currently empty). Re-enable its include in
  `configuration.yaml` when you add the first script.

---

## 9. Groups, People, Zones & Customizations

- **Groups** (`groups/`, `!include_dir_merge_named`): dict keyed by group name.
  Each entry has `name`, `entities`, optional `icon`, `all`. Split by concern
  (`light_groups.yaml`, `person_group.yaml`, `presence_devices.yaml`).
- **People** (`people/`, `!include_dir_list`): one `*_config.yaml` per person.
- **Zones** (`locations/`, `!include_dir_list`): one `location.*.yaml` per zone.
  Coordinates come from secrets, not literals.
- **Customizations** (`customizations/`, `!include_dir_named`): per-entity UI
  metadata (`person.<name>.yaml`) keyed by filename.

---

## 10. Custom Components

`custom_components/` is **gitignored by default** because most contents are
third-party. If you author your own integration, add a targeted un-ignore
(`!custom_components/my_integration/`) in `.gitignore`.

- Follow **PEP 8 / 4-space** indentation; pass `flake8`/`pylint` if modified.
- Validate config schemas with `voluptuous` (`PLATFORM_SCHEMA`).
- Pin external service versions where the component requires them (e.g. Xbox
  SmartGlass `REQUIRED_SERVER_VERSION`).

---

## 11. Validation & Testing

There is no unit-test suite; **config validation is the safety net.**

```bash
# Validate the full configuration from repo root
ha core check
# or, outside a supervised install:
homeassistant --script check_config -c .

# Apply changes
ha core restart      # full restart (needed for new includes/integrations)
# Prefer targeted reloads from Developer Tools -> YAML for automations/templates/groups

# Watch logs while iterating
ha core logs
```

> The **pre-commit checklist** (validation gate + secrets check) and all commit,
> branch, and PR conventions live in [`CONTRIBUTING.md`](./CONTRIBUTING.md).

---

## 12. Git Workflow

Commit, branch, and PR conventions — plus the pre-commit gate and secrets check —
are maintained in [`CONTRIBUTING.md`](./CONTRIBUTING.md). Highlights:

- **Validate before committing:** `ha core check` must pass.
- **Never commit secrets:** verify with `git check-ignore -v secrets secrets.yaml`.
- **Atomic commits;** keep entity IDs/automation `id`s stable.
- **Don't force-push** shared branches (`master`, `shore-house`).

---

## 13. Multi-Deployment Notes

Each deployment currently lives on its own branch: `master` (main house),
`shore-house` (beach house). The two configurations share almost all structure and
differ mainly in **site-specific secrets** (coordinates, URLs, device hosts) and a
handful of site-specific entities/views.

Practical guidance today:

- Keep **structure identical** across branches so changes port cleanly.
- Keep **all site differences in `secrets.yaml`** wherever possible, so the same
  YAML works on both. `secrets.yaml` is per-machine and never committed, so it is
  naturally different per house.
- When you improve shared logic on one branch, port it to the other promptly to
  avoid divergence.

> A recommended long-term branch/sync strategy (shared base vs. per-site overlays,
> how to reduce manual porting) is a **separate follow-up task** — this section
> documents only the current reality.
