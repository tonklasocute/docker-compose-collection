# Contributing

Thanks for helping! A template is useful here only if someone can copy it, run one command, and trust it. That's why every template follows the same checklist and is tested end to end in CI.

## Local setup

You need Docker with Compose 2.30+, `bash` and `make`. The linters run from pinned Docker images when they aren't installed locally, so nothing else is required.

```bash
scripts/lint.sh                       # all static checks (what CI runs)
scripts/test-template.sh <template>   # start, health-check, smoke-test, tear down
scripts/test-all.sh                   # every template, then a pass/fail table
```

`test-template.sh` works on a copy in `.tmp/`, so your own `.env` and running containers are never touched. Add `--keep` to leave the stack running for debugging. If a default port is already taken on your machine, override it from the shell (shell variables take precedence over `.env`), e.g. `REDIS_PORT=16379 scripts/test-template.sh redis`.

## Template checklist

A new template is a folder with:

- [ ] **`compose.yaml`**: no `version:` key; every image pinned to an explicit version, written literally (no `${VAR}` in `image:`) so Dependabot can update it.
- [ ] **Secrets** as `${VAR:?set VAR in .env}`, with sensible defaults for everything else.
- [ ] A **healthcheck** on every long-running service that checks readiness, not just liveness. If a service can't have one (scratch image), add a comment that says why and what checks it instead.
- [ ] `depends_on` with `condition: service_healthy` (or `service_completed_successfully` for one-shot steps). `docker compose up --wait` must return only once the stack is usable.
- [ ] **Named volumes** for data, a **named network**, `restart: unless-stopped`, and memory limits where usage can grow.
- [ ] **Ports bound to `127.0.0.1`**, with a comment explaining how to expose them. Don't publish ports that only other containers need.
- [ ] **Profiles** for optional services: `tools` for admin UIs, `dev` for hot-reload variants, `demo` for example backends.
- [ ] **App images** (if the template builds one): multi-stage, non-root `USER`, a `.dockerignore`, and the final size measured and stated in the README. Use `read_only`, `cap_drop: [ALL]` and `no-new-privileges` where the app allows it.
- [ ] **`.env.example`**: every variable used by `compose.yaml`, each with a comment. Mark required ones `REQUIRED`, and use `change-me-...` placeholders for secrets.
- [ ] **`Makefile`** with at least `up`, `down`, `logs`, `ps`, `reset` (asks for confirmation) and `test`. Copy one from an existing template; `make` with no target lists the targets.
- [ ] **`smoke-test.sh`**: runs against the live stack and checks real behaviour (a query, a produce/consume round-trip, an authenticated request, a restart that keeps data), plus security defaults such as the port binding. Use the same `check "description" command...` helper as the other templates. Put `# test-profiles: a,b` in it if CI should enable profiles other than `tools`.
- [ ] Test-only services (mock APIs, fake servers) go in **`compose.test.yaml`**, never in `compose.yaml`.
- [ ] **`README.md`** with these sections: what it is, Quick start (three commands), Services (image + ports table), Environment variables (table), Default credentials, Connecting (from the host and from another container), Reset data, Troubleshooting, Files.
- [ ] A row in the root README's template table, including the badge URL.

## Pull requests

- One template or one fix per pull request.
- **Conventional commits** with the template as the scope, e.g. `feat(postgres): add postgres + pgadmin template`, `fix(kafka): wait for the controller quorum`, `docs(redis): explain eviction policies`. Use `ci`, `chore` or `docs` without a scope for repo-wide changes.
- `scripts/lint.sh` and `scripts/test-template.sh <template>` pass locally. CI runs both.
- Never commit a real `.env`, token or key. CI runs gitleaks over the full history. `.gitleaks.toml` only allow-lists the documented `change-me-...` placeholders.
- Add a line to `CHANGELOG.md` under *Unreleased*.

## Upgrading an image

Dependabot opens weekly PRs for minor and patch updates of compose images, Dockerfiles, Go and npm modules, and for GitHub Actions. The test workflow runs on each one. **Major** versions are ignored on purpose (see `.github/dependabot.yml`). Upgrade those by hand in their own PR: read the upstream release notes, migrate data or config if needed, and update the template's README (versions, behaviour, troubleshooting) along with the tag.
