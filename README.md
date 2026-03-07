# csgo-server

Docker Compose stack for:
- CS:GO legacy dedicated server (Steam app `4465480` via `cm2network/steamcmd`)
- Apache FastDL (map/file hosting)
- Metamod + Sourcemod bootstrap

## TL;DR (First Run)

Do these steps from the repo root.

1. Create local-only config files (required once).
   - `cp .env.example .env`
   - `mkdir -p overrides.local/csgo`
   - `cp -an overrides/csgo/. overrides.local/csgo/`
2. Create local-only secrets (required once).
   - `docker compose --profile setup run --rm secret-init`
3. Login to Steam for app `4465480` access (required once).
   - `docker compose --profile setup run --rm steam-login`
4. Set your server values (required).
   - `nano .env`
   - `nano overrides.local/csgo/cfg/custom/01-server-identity.cfg`
   - `nano overrides.local/csgo/cfg/custom/02-access-security.cfg`
   - `nano overrides.local/csgo/motd.txt`
5. Start containers.
   - `sh ./scripts/up-with-secrets.sh`
6. Verify the server is running.
   - `sh ./scripts/up-with-secrets.sh logs -f csgo`

If logs show `No subscription` for app `4465480`, add local Steam auth (not committed):
- `printf '%s' 'your_steam_username' > secrets/steam_user`
- `printf '%s' 'your_steam_password' > secrets/steam_pass`
- `printf '%s' '12345' > secrets/steam_guard_code` (optional one-time code for guarded logins)

If logs show `Disk write failure`, fix host permissions and free space:
- `df -h`
- `sudo chown -R 1000:1000 data/steam data/csgo`
- `sudo chmod -R u+rwX data/steam data/csgo`

Optional: hidden secret input mode instead of paste-friendly visible input:
- `SECRET_PROMPT_MODE=hidden docker compose --profile setup run --rm secret-init`

## Pull-Safe Customization Model

- `overrides/csgo` is tracked defaults. Do not put personal edits here.
- `overrides.local/csgo` is gitignored. Put your server-specific edits here.
- On startup, tracked defaults are applied first, then `overrides.local` overrides them.
- `.env` and `secrets/srcds_*` are gitignored local runtime config/secrets.
- optional `secrets/steam_user` and `secrets/steam_pass` are gitignored local-only Steam auth.
- optional `secrets/steam_guard_code` is gitignored and can help first guarded login.
- After `git pull`, sync newly added default files without overwriting your local edits:
  - `cp -an overrides/csgo/. overrides.local/csgo/`

## Repo Layout

- `docker-compose.yml`: services for secret init, plugin bootstrap, CS:GO, and FastDL.
- `steam-login` setup service: one-time interactive Steam login with persistent session in `data/steam`.
- `overrides/csgo`: tracked default overrides applied on boot.
- `overrides.local/csgo` (ignored): local personal overrides applied after tracked defaults.
- `overrides/csgo/cfg/custom/*.cfg`: modular server customization files.
- `overrides/csgo/motd.txt`: server website URL shown by the scoreboard button.
- `secrets/init-secrets.sh`: interactive secret setup script meant to run in a one-off container.
- `fastdl/csgo`: FastDL document root (custom maps/files live here).
- `scripts/install-plugins.sh`: installs/updates Metamod + Sourcemod, then applies overrides.
- `scripts/run-csgo.sh`: updates app `4465480` (unless disabled) and launches the dedicated server.
  - auto-installs Steam Linux Runtime app `1070560` if required by `csgo.sh`.
- `scripts/build-fastdl.sh`: copies map assets from server data and creates `.bz2` archives.
- `scripts/up-with-secrets.sh`: starts compose after reading secret files.
- `data/csgo` (ignored): live game files downloaded by SteamCMD in-container.
- `data/steam` (ignored): persisted SteamCMD login/session data.

## Prerequisites

- Docker Engine + Docker Compose plugin on the host.
- Open ports:
  - UDP/TCP `27015` (game)
  - UDP `27005` (client)
  - UDP `27020` (GOTV)
  - TCP `8080` (FastDL; change with `FASTDL_PORT`)

## First Boot (Step by Step)

1. Create local env file.
   - `cp .env.example .env`
2. Create local override tree.
   - `mkdir -p overrides.local/csgo`
   - `cp -an overrides/csgo/. overrides.local/csgo/`
3. Generate local secret files.
   - `docker compose --profile setup run --rm secret-init`
4. Login to Steam account for app `4465480`.
   - `docker compose --profile setup run --rm steam-login`
   - enter username, password, and guard code when prompted
5. Set runtime config.
   - `nano .env`
   - keep `STEAM_APP_ID=4465480` for CS:GO legacy
   - set `STEAM_USER` or create `secrets/steam_user` for non-anonymous updates
   - keep `USE_STEAM_PASSWORD_LOGIN=0` for normal boot (uses cached login session)
   - optional: `UPDATE_ON_START=0` after first successful install to skip long verify pass on each boot
6. Set server config in local overrides.
   - `nano overrides.local/csgo/cfg/custom/01-server-identity.cfg` (set `hostname`)
   - `nano overrides.local/csgo/cfg/custom/02-access-security.cfg` (set `sv_downloadurl` to `http://host:8080/csgo`)
   - `nano overrides.local/csgo/motd.txt` (set scoreboard website URL)
7. Start services.
   - `sh ./scripts/up-with-secrets.sh`

On startup, `plugin-bootstrap` installs Metamod + Sourcemod if missing (or forced), then applies tracked overrides and finally local overrides.

## Customization Files

- `cfg/custom/01-server-identity.cfg`: hostname, tags, region, MOTD source.
- `cfg/custom/02-access-security.cfg`: password, FastDL URL, pure/filter settings.
- `cfg/custom/03-map-and-workshop.cfg`: mapcycle/mapgroup/workshop controls.
- `cfg/custom/10-gameplay-core.cfg`: round flow, warmup, team balance.
- `cfg/custom/11-round-and-economy.cfg`: money and overtime.
- `cfg/custom/12-team-and-communication.cfg`: friendly fire and voice policy.
- `cfg/custom/13-bot-control.cfg`: bot count and behavior.
- `cfg/custom/20-votes-and-governance.cfg`: vote permissions.
- `cfg/custom/30-network-and-performance.cfg`: rates and hibernation.
- `cfg/custom/40-gotv.cfg`: GOTV behavior.
- `cfg/custom/50-logging-and-admin.cfg`: logs and ban list persistence.

## Updating Plugins

- Normal boot keeps existing plugin install.
- Force reinstall on next boot:
  - `FORCE_PLUGIN_REINSTALL=1 sh ./scripts/up-with-secrets.sh up plugin-bootstrap`

## FastDL Workflow

Add custom content to the running server, then publish to FastDL:

```bash
./scripts/build-fastdl.sh
```

This syncs supported files from `data/csgo/csgo` to `fastdl/csgo` and builds `.bz2` archives.

## Useful Commands

- Full restart: `sh ./scripts/up-with-secrets.sh down && sh ./scripts/up-with-secrets.sh up -d`
- View logs: `sh ./scripts/up-with-secrets.sh logs -f csgo`
- View FastDL logs: `sh ./scripts/up-with-secrets.sh logs -f fastdl`
- Stop services: `sh ./scripts/up-with-secrets.sh down`
