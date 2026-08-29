# Repository Guidelines

## Authoring conventions live in BEST_PRACTICES.md

All working guidance for this repo — structure & the `!include` model, secrets
handling, naming, dashboards/Lovelace, integrations, templates, automations,
groups/people/zones, validation, and the git workflow — is maintained in
[`BEST_PRACTICES.md`](./BEST_PRACTICES.md). Read it before making changes.

**Quick reference:**

```bash
ha core check      # validate config from repo root (run before every commit)
ha core restart    # apply changes that touch includes/integrations
ha core logs       # tail logs while iterating
```

- **Never commit secrets.** `secrets.yaml`, the bare `secrets` file, and
  `secrets.*` are gitignored; use `!secret` for all sensitive values.
- **Validate before committing** with `ha core check`; there is no unit-test
  suite — config validation is the safety net.
- **Keep entity IDs and automation `id`s stable**; commit atomically (YAML +
  its view together).

For anything not covered by this pointer, defer to `BEST_PRACTICES.md`. The
contribution process (change workflow, validation gate, commit/branch conventions,
secrets check) lives in `CONTRIBUTING.md`. See also `README.md` for setup and
per-deployment (branch) details.

---

# Repository Tour

## 🎯 What This Repository Does

This repository contains the complete Home Assistant configuration for the 841 N 4th residence, covering dashboards, automations, custom components, and device integrations.

**Key responsibilities:**
- Automate lighting, HVAC, security, and notifications defined in `automations.yaml` and device-specific integration folders.
- Expose curated Lovelace dashboards (`app/views/*.yaml`, `dashboard-*.yaml`) for both admin and household users.
- Extend Home Assistant via bundled custom components (`custom_components/xboxone`, `custom_components/hacs`) and third-party services like DuckDNS, Nest, and Roomba.

---

## 🏗️ Architecture Overview

### System Context
```
[Residents & mobile apps]
        ↓
[DuckDNS + HTTPS endpoint] → [Home Assistant Core (configuration.yaml)]
        ↓                           ↓
   [Cloud APIs: Nest, Xbox, Plex]   [Local devices: Z-Wave, Roomba, Yamaha]
```

### Key Components
- **Core configuration (`configuration.yaml`)** – Declares global site data, auth providers, and includes every downstream module (automations, integrations, dashboards, people, scenes).
- **Domain-specific bundles (`integrations/`)** – Each subfolder maps to a Home Assistant platform (lights, media players, sensors, templates, zwave) with fine-grained YAML, enabling targeted overrides or rollbacks.
- **Presentation layer (`app/config`, `app/views`, `app/components`)** – Lovelace dashboards (`dashboard-*.yaml`) stitch together reusable cards and per-room layouts; `app/components/status/*.yaml` exposes shared cards for cleaning, presence, etc.
- **Custom components (`custom_components/xboxone`, `custom_components/hacs`)** – Python code extending HA; `xboxone/media_player.py` talks to a SmartGlass REST server via `requests` and `voluptuous` schemas, while HACS manages third-party repositories.
- **Security & identity (`authentication/`, `people/`, `customizations/`)** – DuckDNS, SSL, IP ban policies, and persona metadata are segregated to keep operational secrets isolated via `!secret` references.

### Data Flow
1. Devices publish state through integration YAML (e.g., `binary_sensors/vacuums_cleaning_status.yaml` or Roomba via `integrations/cleaning/vacuum_config.yaml`).
2. Home Assistant ingests updates, evaluating automations in `automations.yaml` (e.g., the "Welcome Home" lock trigger).
3. Actions call services (`light.turn_on`, `homeassistant.restart`, `notify.notify`) or delegate to custom components (Xbox media control).
4. Lovelace dashboards (`app/views/…`) display the resulting state, while notifications and scripts touch residents’ phones or lights.
5. Periodic tasks (like certificate expiry in automation `Restart on Expiry`) can restart HA Core, ensuring DuckDNS/SSL remain valid.

---

## 📁 Project Structure [Partial Directory Tree]

```
hassio/
├── configuration.yaml        # Central configuration with all includes
├── automations.yaml          # Core automation rules
├── dashboard-admin.yaml      # Admin Lovelace entrypoint (includes app/views)
├── dashboard-user.yaml       # User-facing Lovelace entrypoint
├── app/
│   ├── config/
│   │   ├── ui-config.yaml    # Declares YAML dashboard mode + directory includes
│   │   └── dashboards/       # Dashboard metadata (admin/user panels)
│   ├── components/           # Reusable Lovelace cards (presence, status)
│   ├── inputs/               # Helper entities (e.g., number inputs)
│   ├── switches/             # Switch definitions pulled into main config
│   └── views/                # Room-by-room Lovelace layouts
├── integrations/
│   ├── binary_sensors/
│   ├── lights/
│   ├── media_players/
│   ├── sensors/
│   ├── templates/
│   └── zwave/
├── custom_components/
│   ├── hacs/                 # Community Store backend
│   └── xboxone/              # Custom media_player implementation
├── authentication/           # DuckDNS, HTTP, MFA, trusted networks
├── blueprints/               # Stock HA automation/script/template blueprints
├── customizations/           # Per-person UI metadata
├── groups/                   # Light/person/presence groups
├── people/                   # Entity definitions for tracked residents
├── scenes/                   # Lifx or other scene configurations
└── www/                      # Static assets (e.g., profile photos)
```

### Key Files to Know

| File | Purpose | When You'd Touch It |
|------|---------|---------------------|
| `configuration.yaml` | Global HA configuration, include graph, auth setup | Add/remove integrations, modify system settings |
| `automations.yaml` | Event-driven rules (lighting, notifications, cert renewals) | Create/edit automations, adjust triggers/conditions |
| `app/config/ui-config.yaml` | Declares YAML dashboard mode and directory includes | Add new dashboards or switch between YAML/UI modes |
| `app/views/*` | Individual Lovelace pages per room/area | Update UI layout or expose new entities |
| `app/components/status/*.yaml` | Shared Lovelace cards (cleaning, presence) | Reuse or tweak status widgets across dashboards |
| `integrations/*/*.yaml` | Device/platform-specific settings (lights, media, sensors) | Onboard new hardware or tune existing integrations |
| `custom_components/xboxone/media_player.py` | Python SmartGlass client | Update Xbox control logic or dependencies |
| `custom_components/hacs/manifest.json` | HACS metadata | Track upstream compatibility, ensure frontend resources load |
| `authentication/http_config.yaml` | HTTPS, CORS, login hardening | Rotate certificates/ports or adjust allowed origins |
| `dashboard-*.yaml` | Entry points for admin/user Lovelace panels | Reorder views or expose additional dashboards |

---

## 🔧 Technology Stack

### Core Technologies
- **Language:** YAML – primary medium for Home Assistant configuration, automations, and Lovelace views.
- **Framework:** Home Assistant Core (2023+ compatible) – orchestrates integrations, automations, and UI defined in this repo.
- **Database/State:** Home Assistant’s recorder (external DB not versioned here) plus Z-Wave network files (`zwcfg_*.xml`).
- **Web Layer:** Lovelace dashboards with YAML mode enabled (`app/config/ui-config.yaml`).

### Key Libraries
- **`requests`** – Used inside `custom_components/xboxone` to talk to the SmartGlass REST server.
- **`voluptuous`** – Schema validation for Xbox platform configuration (`PLATFORM_SCHEMA`).
- **HACS (Home Assistant Community Store)** – Included in `custom_components/hacs` to manage third-party cards and integrations.

### Development Tools
- **Home Assistant CLI (`ha core …`)** – Validate, restart, and inspect logs for this configuration bundle.
- **SmartGlass REST server** – External service that the Xbox custom component communicates with; ensure version `0.9.8` per `REQUIRED_SERVER_VERSION`.
- **Z-Wave / MQTT tooling** – Not committed here but implied by `integrations/zwave` and commented MQTT entries for future expansion.

---

## 🌐 External Dependencies

### Required Services
- **DuckDNS** – Dynamic DNS + certificate automation (`authentication/duckdns_config.yaml`, `Restart on Expiry` automation) keeps HTTPS endpoints alive.
- **Nest** – Climate integration via `integrations/climate_control/nest_config.yaml`.
- **Roomba (via `roomba` platform)** – Cleaning automation in `integrations/cleaning/vacuum_config.yaml` with secrets-backed credentials.
- **Xbox SmartGlass REST** – Remote control for Xbox devices through `custom_components/xboxone`.

### Optional/Configurable
- **MQTT / UPNP** – YAML stubs exist but are commented out; enable when needed in `integrations/network/`.
- **HACS-managed frontend resources** – Additional Lovelace cards or themes pulled via `custom_components/hacs` when configured.

---

### Environment Variables

Secrets are resolved via `!secret` entries in `configuration.yaml` and integration files. Common keys include:

```bash
external_url=            # Public DuckDNS URL for the installation
zone_home_lat/long=      # Precise geolocation for sunrise/sunset automations
roomba_host/username/password=  # Vacuum credentials
server_port=             # HTTPS listener port
ssl_certificate / ssl_key=  # Paths to TLS materials
orca duckdns_token=      # DuckDNS access token
```

Store actual values in `secrets.yaml` (ignored by Git) and never commit them.

---

## 🔄 Common Workflows

### Add or Update an Automation
1. Modify `automations.yaml` (keep IDs stable when editing existing entries).
2. Run `ha core check` to validate syntax and entity references.
3. Reload automations or restart HA (`ha core restart`) to apply changes.
4. Confirm behavior through Developer Tools or associated Lovelace cards.

**Code path:** `automations.yaml` → Home Assistant Automation Engine → Target services (lights, locks, notifications).

### Extend a Lovelace Dashboard
1. Add or update a card in `app/components/` if it will be reused; otherwise edit the specific file under `app/views/`.
2. Include the new view or card in `dashboard-admin.yaml` or `dashboard-user.yaml` as needed.
3. Validate via `ha core check` and reload the dashboard through the HA UI.

**Code path:** `app/components/*` → `app/views/*` → `dashboard-*.yaml` → Lovelace frontend.

### Introduce a New Device Integration
1. Create or modify the relevant YAML under `integrations/<domain>/` (e.g., add a light group or media player definition).
2. Reference any secrets via `!secret` and document them for ops.
3. Validate configuration, then restart HA.

**Code path:** `integrations/...` → `configuration.yaml` include graph → HA integration loader.

---

## 📈 Performance & Scale

- **Caching / Polling:** Many integrations (e.g., Roomba, Xbox) poll external endpoints; keep their YAML files lean and disable unused entities to reduce load.
- **Dashboards:** Break complex Lovelace cards into smaller includes (`app/components/status/*.yaml`) to avoid UI lag.

### Monitoring
- Use `ha core logs` and Lovelace status cards (`app/components/status/cleaning.yaml`) to monitor device health; add more sensors under `integrations/sensors/` for visibility when needed.

---

## 🚨 Things to Be Careful About

### 🔒 Security Considerations
- **Authentication:** Default provider plus optional MFA modules are defined under `authentication/`. Keep DuckDNS tokens and SSL keys in `secrets.yaml` and rotate them when the `Restart on Expiry` automation fires.
- **Network Exposure:** `authentication/http_config.yaml` enforces CORS allowlists, IP bans, and TLS. Verify `server_port`, `ssl_certificate`, and `ssl_key` whenever you move hosts.
- **External APIs:** Xbox SmartGlass requires server version `0.9.8`. Nest, Roomba, and DuckDNS credentials must stay in secrets and never be logged.

*Update to last commit: 3c725a7042f7167c0cf0ac4aa60fb12f8a113292*
