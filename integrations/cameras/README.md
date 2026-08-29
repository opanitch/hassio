# UniFi Protect Camera Integration

## Overview

This integration connects to the community UniFi Dream Machine (UDM) running
UniFi OS 5.0.12 at WAN IP `71.162.188.30` to stream 4x G5 Bullet cameras.

## Hardware

| Camera | Location | Connection | IP Address |
|--------|----------|------------|------------|
| G5 Bullet #1 | TBD | Wired (PoE) | TBD |
| G5 Bullet #2 | TBD | Wired (PoE) | TBD |
| G5 Bullet #3 | TBD | Wired (PoE) | TBD |
| G5 Bullet #4 | TBD | Wired (PoE) | TBD |

> Update the table above with actual camera names, locations, and fixed IPs
> once the integration is configured.

## Integration Type

The **UniFi Protect** integration is configured via the Home Assistant UI
(Settings → Devices & Services → Add Integration → "UniFi Protect"), **not**
through YAML files. See the setup steps below.

## Required Secrets

Add the following to `secrets.yaml`:

```yaml
unifi_protect_host: "71.162.188.30"
unifi_protect_port: "443"
unifi_protect_username: "homeassistant"
unifi_protect_password: "<password-for-ha-local-account>"
```

## Dashboard

Camera feeds are displayed in:
- `app/views/cameras-view.yaml` — dedicated security cameras page
- `app/views/exterior-view.yaml` — exterior view (camera snapshot cards)
