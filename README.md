# csgo-server

Docker Compose stack for:
- CS:GO dedicated server (`cm2network/csgo`)
- Apache FastDL (map/file hosting)
- Metamod + Sourcemod bootstrap

## Repo Layout

- `docker-compose.yml`: services for secret init, plugin bootstrap, CS:GO, and FastDL.
- `overrides/csgo`: tracked server and plugin config overrides applied on boot.
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

## Config and Secrets (Public Repo Safe)

- Commit templates and setup scripts only: `.env.example`, `secrets/*.example`, and `secrets/init-secrets.sh`.
- Keep real values in private host files that are not committed.
- Do not store live `rcon_password` or `sv_setsteamaccount` values in tracked `overrides/csgo/cfg/server.cfg`.
- Keep `sv_downloadurl` in `overrides/csgo/cfg/server.cfg` set to your public FastDL URL.

## Ubuntu First Boot (Recommended)

### Option A: one private env file (simple)

1. Create private config directory:
   - `sudo install -d -m 700 /etc/csgo-server`
2. Create private env file from template:
   - `sudo cp .env.example /etc/csgo-server/server.env`
3. Edit `/etc/csgo-server/server.env` and set real values, including:
   - `SRCDS_TOKEN`
   - `SRCDS_RCONPW`
4. Lock file permissions:
   - `sudo chmod 600 /etc/csgo-server/server.env`
5. Update `overrides/csgo/cfg/server.cfg`:
   - set server name
   - set `sv_downloadurl` to your public FastDL URL (`http://host:8080/csgo`)
6. Start:
   - `docker compose --env-file /etc/csgo-server/server.env up -d`

### Option B: split env file + secret files (safer for shared servers)

1. Create private directories:
   - `sudo install -d -m 700 /etc/csgo-server /etc/csgo-server/secrets`
2. Create private env file:
   - `sudo cp .env.example /etc/csgo-server/server.env`
3. In `/etc/csgo-server/server.env`, leave these blank:
   - `SRCDS_TOKEN=`
   - `SRCDS_RCONPW=`
4. Run interactive secret setup in a container:
   - `SECRETS_DIR=/etc/csgo-server/secrets docker compose --profile setup run --rm secret-init`
5. Lock permissions:
   - `sudo chmod 600 /etc/csgo-server/server.env /etc/csgo-server/secrets/srcds_token /etc/csgo-server/secrets/srcds_rconpw`
6. Start with helper script:
   - `ENV_FILE=/etc/csgo-server/server.env SECRETS_DIR=/etc/csgo-server/secrets sh ./scripts/up-with-secrets.sh`

## Local First Boot (Quick)

1. Copy env template and fill values:
   - `cp .env.example .env`
2. Generate local secret files in a container:
   - `docker compose --profile setup run --rm secret-init`
3. Update `overrides/csgo/cfg/server.cfg`:
   - set server name
   - set `sv_downloadurl` to your public FastDL URL (`http://host:8080/csgo`)
4. Start:
   - `sh ./scripts/up-with-secrets.sh`

On startup, `plugin-bootstrap` downloads/install Metamod + Sourcemod if missing (or forced), then copies tracked overrides into the live game tree.

## Updating Plugins

- Normal boot keeps existing plugin install.
- Force reinstall on next boot:
  - `FORCE_PLUGIN_REINSTALL=1 docker compose --env-file /etc/csgo-server/server.env up plugin-bootstrap`
  - then set `FORCE_PLUGIN_REINSTALL=0` in your private env file.

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
