This folder contains public secret templates plus a containerized setup script.

Real secret files are ignored by Git.

Quick start (writes to `./secrets`):

1. `docker compose --profile setup run --rm secret-init`
2. Follow prompts for `SRCDS_TOKEN` and `SRCDS_RCONPW`.
3. Start server with `sh ./scripts/up-with-secrets.sh`.

Ubuntu host path (`/etc/csgo-server/secrets`):

1. `sudo install -d -m 700 /etc/csgo-server/secrets`
2. `SECRETS_DIR=/etc/csgo-server/secrets docker compose --profile setup run --rm secret-init`
3. `sudo chmod 600 /etc/csgo-server/secrets/srcds_token /etc/csgo-server/secrets/srcds_rconpw`
4. Start server with `ENV_FILE=/etc/csgo-server/server.env SECRETS_DIR=/etc/csgo-server/secrets sh ./scripts/up-with-secrets.sh`.

Non-interactive mode:

`SRCDS_TOKEN=... SRCDS_RCONPW=... docker compose --profile setup run --rm secret-init`
