# Contributing

Process and conventions for making changes to this Home Assistant configuration.
For *how to author* config (structure, dashboards, integrations, templates,
naming), see [`BEST_PRACTICES.md`](./BEST_PRACTICES.md). For setup and the
deployment/branch model, see [`README.md`](./README.md).

## Before you start

- Work on the branch for the target home: `master` (main house) or `shore-house`
  (beach house). See the deployment table in `README.md`.
- Make sure you have a local `secrets.yaml` (copied from `secrets.example.yaml`)
  so the config validates.

## Change workflow

1. **Put the change in the right place.** Follow the "Adding something new"
   decision flow in `BEST_PRACTICES.md` (integration → `integrations/<domain>/`,
   UI page → `app/views/`, reusable card → `app/components/`, derived value →
   `integrations/templates/`, automation → `automations.yaml`).
2. **Validate.** Run `ha core check` (or `homeassistant --script check_config -c .`)
   from the repo root. It must pass.
3. **Verify behavior.** Exercise the change through a dashboard card or
   *Developer Tools*. Prefer reloading (Developer Tools → YAML) over a full
   `ha core restart` where possible.
4. **Commit** (see below).

## Pre-commit checklist (contribution gate)

- [ ] `ha core check` passes.
- [ ] New/changed entities are exercised by a dashboard card or view.
- [ ] No secrets in tracked files — everything sensitive uses `!secret`.
- [ ] Includes use the correct directive for the platform's shape
      (list vs named — see `BEST_PRACTICES.md` §2).
- [ ] Entity IDs and automation `id`s were kept stable (only human-facing
      `name`/`alias`/`description` changed).

## Secrets

**Secrets never enter git.** Before committing, confirm the secret files are
ignored:

```bash
git check-ignore -v secrets secrets.yaml
git status --short | grep -i secret   # should show nothing sensitive
```

- `secrets.yaml`, the bare `secrets` file, and `secrets.*` are gitignored.
- Only `secrets.example.yaml` (keys, placeholder values) is tracked. When you add
  a new `!secret` key, add it to `secrets.example.yaml` in the same commit.

## Commits

- **Atomic:** pair a YAML change with its dashboard/view and any secrets-template
  update in the same commit.
- **Message style:** short and action-focused, referencing the subsystem —
  e.g. `add waze drivetime sensor`, `update living room remote to new devices`.
- Prefer new commits over `--amend`; only amend your own unpushed commits.
- Don't skip hooks (`--no-verify`) unless explicitly needed.

## Branches & pull requests

- **Branch naming:** `feature/<area>-<summary>` or `fix/<device>-<issue>`.
- Keep PRs focused; include a note about any required `ha core restart` and a
  screenshot for UI-visible changes.
- **Do not force-push** the shared deployment branches (`master`, `shore-house`).
- Deployment branches diverge mainly by `secrets.yaml`; when you improve shared
  logic on one branch, port it to the other promptly to limit drift. (A better
  long-term sync strategy is a tracked follow-up.)
