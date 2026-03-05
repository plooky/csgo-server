# csgo-server

Docker Compose stack for:
- CS:GO dedicated server (`cm2network/csgo`)
- Apache FastDL (map/file hosting)
- Metamod + Sourcemod bootstrap

## Repo Layout

- `docker-compose.yml`: services for plugin bootstrap, CS:GO, and FastDL.
- `overrides/csgo`: tracked server and plugin config overrides applied on boot.
- `fastdl/csgo`: FastDL document root (custom maps/files live here).
- `scripts/install-plugins.sh`: installs/updates Metamod + Sourcemod, then applies overrides.
- `scripts/build-fastdl.sh`: copies map assets from server data and creates `.bz2` archives.
- `data/csgo` (ignored): live game files downloaded by SteamCMD in-container.

## Prerequisites

- Docker Engine + Docker Compose plugin on the host.
- Open ports:
  - UDP/TCP `27015` (game)
  - UDP `27005` (client)
  - UDP `27020` (GOTV)
  - TCP `8080` (FastDL; change with `FASTDL_PORT`)

## First Boot

1. Copy env template and fill real values:
   - `cp .env.example .env`
2. Update `overrides/csgo/cfg/server.cfg`:
   - set server name
   - set strong `rcon_password`
   - set `sv_setsteamaccount` token
   - set `sv_downloadurl` to your public FastDL URL (`http://host:8080/csgo`)
3. Start the stack:
   - `docker compose up -d`

On startup, `plugin-bootstrap` downloads/install Metamod + Sourcemod if missing (or forced), then copies tracked overrides into the live game tree.

## Updating Plugins

- Normal boot keeps existing plugin install.
- Force reinstall on next boot:
  - `FORCE_PLUGIN_REINSTALL=1 docker compose up plugin-bootstrap`
  - then set `FORCE_PLUGIN_REINSTALL=0` in `.env`.

## FastDL Workflow

Add custom content to the running server, then publish to FastDL:

```bash
./scripts/build-fastdl.sh
```

This syncs supported files from `data/csgo/csgo` to `fastdl/csgo` and builds `.bz2` archives.

## Useful Commands

- Full restart: `docker compose down && docker compose up -d`
- View logs: `docker compose logs -f csgo`
- View FastDL logs: `docker compose logs -f fastdl`
- Stop services: `docker compose down`
