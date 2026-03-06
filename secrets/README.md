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
