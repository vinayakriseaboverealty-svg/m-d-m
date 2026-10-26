# MDM runbook

How to stand up, use, and look after the company MDM (Fleet Free) and the Claude Code usage dashboard. Commands assume the repo is checked out on the droplet at `/opt/m-d-m`.

## 1. One-time setup

### 1.1 What you need first

| Item | Who | Notes |
|---|---|---|
| A DigitalOcean droplet, Ubuntu 24.04, 2 vCPU / 4 GB | Senior | Separate from the HRMS. Turn on DigitalOcean droplet backups. |
| DNS A records for `mdm`, `otel` and `usage`.riseabovereality.com pointing at the droplet | Whoever manages DNS | Must exist before first start, or HTTPS certificates fail. |
| A company email address on riseabovereality.com, for example `it@riseabovereality.com` | Manager | Fleet refuses personal email domains for the Apple push certificate. |
| A shared company Apple Account | Manager | Used yearly to renew the Apple push certificate. Renewing with a different account means re-enrolling every Mac. |
| A password manager entry for the MDM | You | Holds `.env`, the itadmin password, the Grafana admin login, and the Fleet admin login. |

### 1.2 Start the server

```sh
git clone https://github.com/vinayakriseaboverealty-svg/m-d-m /opt/m-d-m   # or copy riseabove/deploy only
cd /opt/m-d-m/riseabove/deploy
sudo scripts/bootstrap-droplet.sh     # Docker, ufw, unattended upgrades, nightly backup cron
sudo scripts/init-env.sh              # creates .env with random secrets
sudo nano .env                        # check the three domains and ACME_EMAIL
sudo docker compose up -d
sudo docker compose ps                # everything "running"/"healthy"; fleet-init "exited (0)"
```

Copy `.env` into the password manager now. `FLEET_SERVER_PRIVATE_KEY` encrypts the Apple push certificate in the database; without it a backup can't be restored and every device has to be re-enrolled.

Add a DigitalOcean Cloud Firewall on the droplet: inbound TCP 80, TCP 443, UDP 443 from anywhere, TCP 22 only from known IPs. Docker's published ports bypass ufw, so the cloud firewall is the one that actually protects the box.

### 1.3 First login and Apple MDM

1. Open https://mdm.riseabovereality.com and create the first admin account. Use a long password from the password manager. Keep admins to two people.
2. **Settings > Integrations > MDM > Apple (macOS, iOS, iPadOS) > Turn on.** Enter the company email, download the signed CSR Fleet emails you, upload it at https://identity.apple.com/pushcert while signed in with the shared company Apple Account, then upload the resulting `.pem` back into Fleet.
3. Put a calendar reminder 11 months out to renew the push certificate (same Apple Account, **Renew**, not **Create**).

### 1.4 Apply the GitOps configuration

GitOps (`riseabove/gitops/`) is the source of truth for policies, profiles, scripts and settings. Changes made in the Fleet UI to those things get overwritten on the next apply.

Create an API-only user for GitOps, then log `fleetctl` in with its token:

```sh
fleetctl config set --address https://mdm.riseabovereality.com
fleetctl login                                   # as your admin user
fleetctl user create --name gitops --api-only --global-role gitops
# copy the printed API token
fleetctl config set --token <gitops token>
```

Apply, always with a dry run first:

```sh
cd riseabove/gitops
export FLEET_SERVER_URL=https://mdm.riseabovereality.com
export FLEET_ENROLL_SECRET=<random string, store in password manager>
export FLEET_SECRET_CLAUDE_OTEL_TOKEN=<CLAUDE_OTEL_TOKEN from .env>
export FLEET_SECRET_MACOS_ITADMIN_PASSWORD=<itadmin password, store in password manager>
fleetctl gitops -f default.yml --dry-run
fleetctl gitops -f default.yml
```

The dry run skips the Claude Code profile because it contains a `$FLEET_SECRET_` variable; that's expected.

### 1.5 Usage dashboard

Open https://usage.riseabovereality.com, sign in as `admin` with `GRAFANA_ADMIN_PASSWORD` from `.env`, and add a **Viewer** account for the manager under **Administration > Users**. The **Claude Code > Claude Code usage** dashboard is preinstalled.

## 2. Enrolling devices

### 2.1 Build the agent installers (once)

Get the exact command from **Hosts > Add hosts** in Fleet, or run:

```sh
fleetctl package --type=pkg --fleet-desktop --enable-scripts \
  --fleet-url=https://mdm.riseabovereality.com --enroll-secret=$FLEET_ENROLL_SECRET
```

For Windows use `--type=msi` (needs Docker on a Mac or Linux machine, or WiX on Windows). Keep the installers in the password manager or a private drive, because they contain the enroll secret.

### 2.2 Enroll a Mac

1. Install `fleet-osquery.pkg` on the Mac (needs an admin account for this step).
2. Fleet Desktop appears in the menu bar. Click it, then **My device > Turn on MDM**, and follow the prompt to approve the profile in **System Settings > General > Device Management**.
3. In Fleet, the host shows MDM status **On (manual)** within a few minutes, and **OS settings** shows the five profiles as Verified.

### 2.3 Enroll a Windows PC

1. Run `fleet-osquery.msi` as an administrator.
2. In Fleet, open the host and run the script **set-claude-code-managed-settings.ps1**.

## 3. New employee Mac

1. Unbox the Mac and create the employee's account during setup (it becomes an admin; that's fine for now).
2. Enroll it (section 2.2).
3. In Fleet, on the host page, run **create-it-admin.sh**, then **install-standard-apps.sh**.
4. Have the employee turn on FileVault and send IT the recovery key (the "FileVault" policy's resolution text walks them through it).
5. Log out, log in once as `itadmin` to confirm the password works, log out.
6. Run **remove-admin-rights.sh**.
7. Check the host's **Policies** tab: everything should pass after the next check-in (Fleet Desktop > Refetch speeds it up).

To run a script on several Macs at once, select them on the **Hosts** page and use **Run script**.

## 4. Rolling out to existing staff

1. Tell staff what's coming and what's collected (section 7) before enrolling anyone.
2. Pilot on 2 Macs and 1 Windows PC for a week: enrollment, profiles, policies, the three scripts, and the usage dashboard filling in.
3. Enroll the rest in batches of about five. Run **create-it-admin.sh** on all of them, then **remove-admin-rights.sh** once each person has what they need installed.
4. Use the **Local administrator accounts** report and the **Daily account is a standard user** policy to confirm nobody is still an admin.

## 5. Leaving employees and lost devices

Fleet Free can't lock or erase Macs remotely (that's Premium). Until we decide on a remote-wipe option:

- **Leaving employee:** revoke their accounts first (Claude, GitHub, email, HRMS). When the Mac comes back, sign in as `itadmin`, then **System Settings > General > Transfer or Reset > Erase All Content and Settings**. The Mac re-enrolls like a new one.
- **Lost or stolen Mac:** revoke the person's accounts immediately. FileVault keeps the data unreadable while the Mac is powered off or locked, which is why the FileVault policy is marked critical.

## 6. Operations

### Backups and restore

`scripts/backup-mysql.sh` runs nightly at 02:30 and keeps 14 days in `/var/backups/riseabove-mdm`. DigitalOcean droplet backups copy them off the box. To restore:

```sh
cd /opt/m-d-m/riseabove/deploy
sudo docker compose stop fleet
gunzip -c /var/backups/riseabove-mdm/fleet-YYYYMMDD-HHMM.sql.gz | \
  sudo docker compose exec -T mysql sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" fleet'
sudo docker compose start fleet
```

The restored database only works with the same `FLEET_SERVER_PRIVATE_KEY` it was created with.

### Upgrading Fleet

Read the release notes in Fleet's CHANGELOG first. Then take a backup, set the new `FLEET_VERSION` in `.env`, and run `sudo docker compose pull fleet && sudo docker compose up -d fleet`. Migrations run automatically on start. Upgrade one minor version at a time when you've fallen behind.

### Rotating the Claude Code telemetry token

1. Generate a new value and put it in `.env` (`CLAUDE_OTEL_TOKEN`), then `sudo docker compose up -d otel-collector`.
2. Re-apply GitOps with the new `FLEET_SECRET_CLAUDE_OTEL_TOKEN` (Macs get the updated profile automatically).
3. Re-run **set-claude-code-managed-settings.ps1** on the Windows PCs.

Usage stops reporting between steps 1 and 2, so do them together.

### Logs

`sudo docker compose logs -f fleet` (or `caddy`, `otel-collector`). osquery result and status logs are in the `fleet-logs` volume.

## 7. What staff should be told

- The MDM shows IT each device's hardware, OS version, installed apps, local accounts, and whether security settings (FileVault, firewall, screen lock, and so on) are on. IT can push settings and run maintenance scripts.
- Claude Code reports usage numbers to the company: sessions, active time, tokens, estimated cost, lines of code changed, commits and pull requests, per Claude account email and device. It does **not** report prompts, Claude's responses, file contents, or commands.
- The MDM doesn't record screens, keystrokes, browsing, email or messages.
- Each person can see exactly what applies to their Mac in Fleet Desktop (menu bar > My device).
