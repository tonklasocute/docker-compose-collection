# Shortcuts for this stack. Run `make` to list them.
COMPOSE ?= docker compose
# Git Bash on Windows rewrites /container/paths in arguments; turn that off
export MSYS_NO_PATHCONV := 1

.DEFAULT_GOAL := help
.PHONY: help up register verify config unregister down logs ps reset test

help: ## List available targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.env:
	cp .env.example .env
	@echo "Created .env from .env.example - set GITLAB_URL and RUNNER_TOKEN in it."

up: .env ## Start the runner and wait until it is healthy
	$(COMPOSE) up -d --wait

register: .env ## Register with GitLab using GITLAB_URL / RUNNER_TOKEN from .env
	bash ./register.sh

verify: ## Check the registered runners can authenticate with GitLab
	$(COMPOSE) exec runner gitlab-runner verify

config: ## Print config.toml (contains the runner token!)
	$(COMPOSE) exec runner cat /etc/gitlab-runner/config.toml

unregister: ## Unregister every runner in config.toml from GitLab
	$(COMPOSE) exec runner gitlab-runner unregister --all-runners

down: ## Stop and remove containers (the registration is kept)
	$(COMPOSE) --profile '*' down

logs: ## Follow logs (one service: make logs s=runner)
	$(COMPOSE) --profile '*' logs -f --tail=100 $(s)

ps: ## Show service status
	$(COMPOSE) --profile '*' ps

reset: ## Stop everything and DELETE config.toml / the registration (asks first)
	@printf 'This deletes every volume of this stack, including the registration. Type "yes" to continue: '; \
	read ans; [ "$$ans" = yes ] || { echo Aborted.; exit 1; }
	$(COMPOSE) --profile '*' down -v --remove-orphans

test: ## Smoke-test the running stack (full job run if the test profile is up)
	bash ./smoke-test.sh
