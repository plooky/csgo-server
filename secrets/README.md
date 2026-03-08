This folder contains public secret templates plus a containerized setup script.

Real secret files are ignored by Git.

Quick start (writes to `./secrets`):

1. `docker compose --profile setup run --rm secret-init`
2. Follow prompts for `SRCDS_TOKEN` and `SRCDS_RCONPW`.
3. Start server with `sh ./scripts/up-with-secrets.sh`.

Hidden input mode:

`SECRET_PROMPT_MODE=hidden docker compose --profile setup run --rm secret-init`

Non-interactive mode:

`SRCDS_TOKEN=... SRCDS_RCONPW=... docker compose --profile setup run --rm secret-init`

Optional local Steam auth for app install (if anonymous shows `No subscription`):

- `printf '%s' 'your_steam_username' > secrets/steam_user`
- `printf '%s' 'your_steam_password' > secrets/steam_pass`
- `printf '%s' '12345' > secrets/steam_guard_code` (optional one-time code)

Recommended one-time interactive login (only when your selected app needs account auth):

- `docker compose --profile setup run --rm steam-login`
