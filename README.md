# Home Assistant Configuration

Personal Home Assistant (HA) configuration, managed as code. Covers dashboards,
automations, device integrations, and custom components across multiple homes.

## Deployments

**One branch (`master`) runs every home.** Each home's site-specific config lives
in its own Home Assistant *package* under `packages/site_<home>/`, and the active
home is chosen per-machine by two gitignored symlinks:

| Home | Site package | Symlinks (per machine) |
|------|--------------|------------------------|
| Main house (841 N 4th) | `packages/site_841n4th/` | `packages/active` + `app/active` → `site_841n4th` |
| Parents' beach house (827 Pennlyn) | `packages/site_827pennlyn/` | `packages/active` + `app/active` → `site_827pennlyn` |

A shared, site-neutral `configuration.yaml` loads `packages/active/` (backend) and
`app/active/config/ui-config.yaml` (UI). Per-home values (coordinates, URLs, device
hosts/credentials) come from `secrets.yaml`, which is per-machine and **never
committed**. Adding a home = add a `packages/site_<new>/` + `app/site_<new>/` and
point that machine's symlinks at it — no new branch.

> Previously each home was its own git branch; that required manual porting of every
> shared change. The packages model (see
> [`docs/OPTION_B_IMPLEMENTATION_PLAN.md`](./docs/OPTION_B_IMPLEMENTATION_PLAN.md))
> replaced it so a shared change reaches all homes on next pull.

## Layout

```
configuration.yaml     # shared, site-neutral orchestrator (loads packages/active + app/active)
authentication/        # auth, MFA, HTTPS/TLS, DuckDNS, trusted networks (shared)
integrations/tts/      # the only shared integration; everything else is per-site
blueprints/            # stock + custom blueprints (shared)
packages/
  site_841n4th/        # main house: people, zones, customizations, automations,
  site_827pennlyn/     #   groups, switches, inputs, site integrations, device_tracker
  active -> site_...    # per-machine symlink (gitignored)
app/
  site_841n4th/        # per-home UI: views, components, dashboards, ui-config
  site_827pennlyn/
  active -> site_...    # per-machine symlink (gitignored)
custom_components/     # first-party / bundled Python (gitignored)
www/                   # static assets (e.g. profile images)
```

Full details of the packages/symlink model and each directory are in
[`packages/README.md`](./packages/README.md) and
[`BEST_PRACTICES.md`](./BEST_PRACTICES.md).

## Setup (new machine / new deployment)

1. **Clone** (single branch — no per-home branch):
   ```bash
   git clone <repo-url> hassio && cd hassio
   ```
2. **Point this machine at its home** with both gitignored symlinks:
   ```bash
   scripts/hass-site.sh 841n4th      # beach house: scripts/hass-site.sh 827pennlyn
   ```
   (or manually: `ln -sfn site_841n4th packages/active && ln -sfn site_841n4th app/active`)
3. **Create `secrets.yaml`** at the repo root (gitignored, never committed):
   ```bash
   cp secrets.example.yaml secrets.yaml   # then fill in real values
   ```
   Set this machine's `site_name`/`site_latitude`/`site_longitude`/`site_elevation`
   (from the LastPass coordinate catalog) plus device credentials. See the Secrets
   section of `BEST_PRACTICES.md` and `packages/README.md`.
4. **Validate:**
   ```bash
   ha core check
   ```
5. **Start / restart Home Assistant** (a full restart is required after changing
   dashboard `filename:` mappings, not just a reload):
   ```bash
   ha core restart
   ```

## Everyday commands

```bash
ha core check      # validate config (run before every commit)
ha core restart    # apply changes that touch includes/integrations
ha core logs       # tail logs while iterating
```

For automations, templates, and groups you can usually **reload** from
*Developer Tools → YAML* instead of a full restart.

## Making changes

The full contribution process (change workflow, validation gate, commit/branch
conventions, secrets check) lives in [`CONTRIBUTING.md`](./CONTRIBUTING.md). In
short: put the change in the right place, run `ha core check`, confirm behavior
in the UI, then commit atomically with no secrets staged.

## Security

- **Secrets never enter git.** `secrets.yaml`, the bare `secrets` file, and
  `secrets.*` are gitignored; only `secrets.example.yaml` (keys, no values) is
  tracked.
- HTTPS/TLS, CORS allowlists, IP bans, and trusted networks live under
  `authentication/`. Verify `server_port`, `ssl_certificate`, and `ssl_key` when
  moving hosts.
- Rotate the DuckDNS token and TLS materials when certificates renew.

## Documentation map

| Document | Purpose |
|----------|---------|
| `README.md` (this file) | Overview, setup, deployment, day-to-day commands |
| [`CONTRIBUTING.md`](./CONTRIBUTING.md) | Contribution process: change workflow, validation gate, commits, branches, secrets check |
| [`BEST_PRACTICES.md`](./BEST_PRACTICES.md) | Comprehensive authoring guide (structure, dashboards, integrations, templates, automations, secrets, validation, git) |
| [`packages/README.md`](./packages/README.md) | Per-site packages layout, the two-symlink setup, and validation order |
| [`docs/OPTION_B_IMPLEMENTATION_PLAN.md`](./docs/OPTION_B_IMPLEMENTATION_PLAN.md) | Record of the branch→packages migration (phases, decisions, gotchas) |
| `secrets.example.yaml` | Template of every required `!secret` key (placeholder values); copy to `secrets.yaml` |
| `AGENTS.md` | Repo reference for AI assistants; defers to `BEST_PRACTICES.md` for authoring conventions |
| `integrations/cameras/README.md` | Example of documenting a UI-configured integration |
