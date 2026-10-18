# Shortcuts for this stack. Run `make` to list them.
COMPOSE ?= docker compose

.DEFAULT_GOAL := help
.PHONY: help up dev down logs ps reset test unit-test psql redis-cli

help: ## List available targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.env:
	cp .env.example .env
	@echo "Created .env from .env.example - change the passwords in it."

up: .env ## Build and start postgres, redis and the API (:3000)
	$(COMPOSE) up -d --build --wait

dev: .env ## Also start api-dev in watch mode (:3001, profile: dev)
	$(COMPOSE) --profile dev up -d --build --wait
	@echo "Edit anything in src/ - api-dev recompiles. Logs: make logs s=api-dev"

down: ## Stop and remove containers (data is kept)
	$(COMPOSE) --profile '*' down

logs: ## Follow logs (one service: make logs s=api)
	$(COMPOSE) --profile '*' logs -f --tail=100 $(s)

ps: ## Show service status
	$(COMPOSE) --profile '*' ps

reset: ## Stop everything and DELETE the database (asks first)
	@printf 'This deletes every volume of this stack. Type "yes" to continue: '; \
	read ans; [ "$$ans" = yes ] || { echo Aborted.; exit 1; }
	$(COMPOSE) --profile '*' down -v --remove-orphans

test: ## Smoke-test the running stack (CRUD, cache, hardening, watch mode)
	bash ./smoke-test.sh

unit-test: ## Typecheck + vitest in the Dockerfile's test stage
	docker build --target test .

psql: ## Open psql in the database
	$(COMPOSE) exec postgres sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'

redis-cli: ## Open redis-cli (authenticated)
	$(COMPOSE) exec redis redis-cli
