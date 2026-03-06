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
nano overrides.local/csgo/cfg/server.cfg   # set hostname + sv_downloadurl
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
   - `nano overrides.local/csgo/cfg/server.cfg`
   - set `hostname`
   - set `sv_downloadurl` to your public FastDL URL (`http://host:8080/csgo`)
6. Start:
   - `sh ./scripts/up-with-secrets.sh`

On startup, `plugin-bootstrap` downloads/install Metamod + Sourcemod if missing (or forced), then applies tracked overrides followed by local overrides.

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
