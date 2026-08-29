# Home Assistant Configuration

Personal Home Assistant (HA) configuration, managed as code. Covers dashboards,
automations, device integrations, and custom components across multiple homes.

## Deployments

Each home is a **git branch** of this same configuration:

| Branch | Home | Notes |
|--------|------|-------|
| `master` | Main house (841 N 4th) | Default / source branch |
| `shore-house` | Parents' beach house | Sibling deployment |

The branches share nearly all structure. What differs between them lives in
`secrets.yaml` (coordinates, URLs, device hosts/credentials) and a few
site-specific entities/views. `secrets.yaml` is per-machine and **never
committed**, so each house naturally carries its own values.

> How best to keep the two homes in sync long-term (shared base vs. per-site
> overlays) is an open question — see the follow-up task, not yet decided.

## Layout

```
configuration.yaml     # orchestrator; wires everything via !include
automations.yaml       # all automations
dashboard-*.yaml        # Lovelace entrypoints (admin / user)
app/                   # UI: views, reusable components, switches, inputs
integrations/          # one folder per device class (lights, sensors, media, ...)
authentication/        # auth, MFA, HTTPS/TLS, DuckDNS, trusted networks
groups/ people/ locations/ customizations/ scenes/
custom_components/     # first-party / bundled Python (gitignored)
www/                   # static assets
```

Full details of the include model and each directory are in
[`BEST_PRACTICES.md`](./BEST_PRACTICES.md).

## Setup (new machine / new deployment)

1. **Clone and check out the branch** for the target home:
   ```bash
   git clone <repo-url> hassio && cd hassio
   git checkout master        # or: git checkout shore-house
   ```
2. **Create `secrets.yaml`** at the repo root. It is gitignored and must never be
   committed. Populate it from the committed template if present:
   ```bash
   cp secrets.example.yaml secrets.yaml   # then fill in real values
   ```
   Required keys include site geolocation, `external_url`, DuckDNS token, and
   device credentials (Roomba, cameras, Nest, Xbox, etc.). See the Secrets section
   of `BEST_PRACTICES.md`.
3. **Validate the configuration:**
   ```bash
   ha core check
   ```
4. **Start / restart Home Assistant:**
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
| `secrets.example.yaml` | Template of every required `!secret` key (placeholder values); copy to `secrets.yaml` |
| `AGENTS.md` | Repo reference for AI assistants; defers to `BEST_PRACTICES.md` for authoring conventions |
| `integrations/cameras/README.md` | Example of documenting a UI-configured integration |
