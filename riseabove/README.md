# Rise Above Reality MDM

Company device management on self-hosted [Fleet](https://fleetdm.com) Free, plus a Claude Code usage dashboard. Everything in this folder is ours; the rest of the repository is an unmodified copy of Fleet's source and isn't needed to run this (we use Fleet's official Docker image).

## What's here

| Path | What it is |
|---|---|
| `deploy/` | Docker Compose stack for one dedicated DigitalOcean droplet: Caddy (HTTPS), Fleet, MySQL, Redis, OpenTelemetry collector, Prometheus, Grafana. Plus setup, secret-generation and backup scripts. |
| `gitops/` | Fleet configuration as code: org settings, policies, macOS configuration profiles, scripts, reports. Applied with `fleetctl gitops`. |
| `docs/runbook.md` | Setup, enrolling devices, new-employee setup, offboarding, backups, upgrades, and what to tell staff. |

## How it fits together

```
Macs / Windows PCs ──(fleetd agent + Apple MDM)──▶ https://mdm.riseabovereality.com ──▶ Fleet ──▶ MySQL, Redis
Claude Code on each device ──(usage metrics, bearer token)──▶ https://otel.riseabovereality.com ──▶ collector ──▶ Prometheus
Manager / IT ──▶ https://usage.riseabovereality.com ──▶ Grafana (Claude Code usage dashboard)
```

All three hostnames go through Caddy on the same droplet; nothing else is exposed.

## What it does on Fleet Free

| Manager's ask | How | Status |
|---|---|---|
| Set policies centrally | 5 macOS configuration profiles (firewall, Gatekeeper, screen lock, guest account off, Claude Code settings) and 11 compliance policies | Ready |
| Install apps | `install-standard-apps.sh`, run per Mac or in bulk from Fleet (Fleet's built-in installer is Premium) | Ready; edit the app list |
| Restrict apps | Staff become standard users (`create-it-admin.sh`, `remove-admin-rights.sh`) and Gatekeeper blocks unidentified apps | Ready. A real allow/block list (Santa) is a follow-up |
| New employee setup | Checklist in the runbook: enroll, then three scripts | Ready (manual enrollment; no Apple Business Manager) |
| Remote wipe / lock | Premium-only in Fleet | **Open decision**, see below |
| Monitor Claude Code usage | Claude Code's built-in telemetry, locked on by MDM, into a Grafana dashboard | Ready |

## Open decisions

1. **Remote wipe and lock.** Fleet Free blocks the Apple `EraseDevice` and `DeviceLock` commands (`server/service/mdm.go`, `appleMDMPremiumCommands`). Options: accept "revoke accounts + FileVault" for now (the runbook's interim process), build our own image with that check removed (the code is MIT-licensed outside `ee/`, but we'd maintain a fork), or pay for Premium.
2. **Kubernetes vs droplet.** This is built for a dedicated droplet. If it must live on the existing DigitalOcean Kubernetes cluster, Fleet's Helm chart is in `charts/fleet`, but it needs its own namespace, database and Redis, not the HRMS ones.

## Verification status

Checked on a Windows dev machine without a working Docker engine or Python:

- `docker compose config` accepts the stack, and every pinned image tag exists on Docker Hub.
- All shell scripts pass `sh -n`. The dashboard JSON parses.
- Every `paths:` glob in `gitops/default.yml` matches files. The `.mobileconfig` files have balanced XML, a `Configuration` top-level type, unique identifiers, names and UUIDs, and no Fleet-reserved payloads. Every osquery table in the policies and report exists on the platforms they declare (checked against `schema/osquery_fleet_schema.json`).

Not yet run: a real YAML parser, the PowerShell parser, the Fleet GitOps validator (`.claude/skills/fleet-gitops/scripts/validate.py`), `fleetctl gitops --dry-run`, the collector's own config check, and anything on a real Mac or PC. The dashboard queries match metric names by pattern because the exact Prometheus names weren't observed. The pilot in the runbook covers all of this.
