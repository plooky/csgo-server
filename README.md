# csgo-server

Docker Compose stack for:
- CS:GO dedicated server (`cm2network/csgo`)
- Apache FastDL (map/file hosting)
- Metamod + Sourcemod bootstrap

## TL;DR (First Run, Local-Only)

From the repo root:

```bash
cp .env.example .env
mkdir -p overrides.local/csgo
cp -an overrides/csgo/. overrides.local/csgo/
docker compose --profile setup run --rm secret-init
nano .env
nano overrides.local/csgo/cfg/custom/01-server-identity.cfg
nano overrides.local/csgo/cfg/custom/02-access-security.cfg
sh ./scripts/up-with-secrets.sh
```

Then verify:

```bash
sh ./scripts/up-with-secrets.sh logs -f csgo
```

If you want hidden typing instead of paste-friendly visible input:

```bash
SECRET_PROMPT_MODE=hidden docker compose --profile setup run --rm secret-init
```

## Pull-Safe Customization Model

- `overrides/csgo` is tracked default config.
- `overrides.local/csgo` is your personal config and is gitignored.
- On startup, tracked defaults are applied first, then `overrides.local` is applied on top.
- `.env` and `secrets/srcds_*` are gitignored local runtime secrets/config.
- After `git pull`, you can copy any newly added default files without overwriting your edits:
  - `cp -an overrides/csgo/. overrides.local/csgo/`

## Repo Layout

- `docker-compose.yml`: services for secret init, plugin bootstrap, CS:GO, and FastDL.
- `overrides/csgo`: tracked default overrides applied on boot.
- `overrides.local/csgo` (ignored): local personal overrides applied after tracked defaults.
- `overrides/csgo/cfg/custom/*.cfg`: modular server customization files.
- `overrides/csgo/motd.txt`: server website URL shown by the scoreboard button.
- `secrets/init-secrets.sh`: interactive secret setup script meant to run in a one-off container.
- `fastdl/csgo`: FastDL document root (custom maps/files live here).
- `scripts/install-plugins.sh`: installs/updates Metamod + Sourcemod, then applies overrides.
- `scripts/build-fastdl.sh`: copies map assets from server data and creates `.bz2` archives.
- `scripts/up-with-secrets.sh`: starts compose after reading secret files.
- `data/csgo` (ignored): live game files downloaded by SteamCMD in-container.

## Prerequisites

- Docker Engine + Docker Compose plugin on the host.
- Open ports:
  - UDP/TCP `27015` (game)
  - UDP `27005` (client)
  - UDP `27020` (GOTV)
  - TCP `8080` (FastDL; change with `FASTDL_PORT`)

## First Boot (Step by Step)

1. Create local env file:
   - `cp .env.example .env`
2. Create local override tree:
   - `mkdir -p overrides.local/csgo`
   - `cp -an overrides/csgo/. overrides.local/csgo/`
3. Generate local secret files:
   - `docker compose --profile setup run --rm secret-init`
4. Edit local runtime config:
   - `nano .env`
5. Edit local server config:
   - `nano overrides.local/csgo/cfg/custom/01-server-identity.cfg`
   - `nano overrides.local/csgo/cfg/custom/02-access-security.cfg`
   - `nano overrides.local/csgo/motd.txt`
   - set `hostname` in `01-server-identity.cfg`
   - set `sv_downloadurl` in `02-access-security.cfg` to your public FastDL URL (`http://host:8080/csgo`)
   - set the website URL in `motd.txt`
6. Start:
   - `sh ./scripts/up-with-secrets.sh`

On startup, `plugin-bootstrap` downloads/install Metamod + Sourcemod if missing (or forced), then applies tracked overrides followed by local overrides.

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
