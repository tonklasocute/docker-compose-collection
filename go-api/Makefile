# Shortcuts for this stack. Run `make` to list them.
COMPOSE ?= docker compose
# Git Bash on Windows rewrites /container/paths in arguments; turn that off
export MSYS_NO_PATHCONV := 1

.DEFAULT_GOAL := help
.PHONY: help up dev down logs ps reset test unit-test migration psql

help: ## List available targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.env:
	cp .env.example .env
	@echo "Created .env from .env.example - change the password in it."

up: .env ## Build and start postgres, migrations and the API (:8080)
	$(COMPOSE) up -d --build --wait

dev: .env ## Also start api-dev with hot reload (:8081, profile: dev)
	$(COMPOSE) --profile dev up -d --build --wait
	@echo "Edit any .go file - api-dev rebuilds. Logs: make logs s=api-dev"

down: ## Stop and remove containers (data is kept)
	$(COMPOSE) --profile '*' down

logs: ## Follow logs (one service: make logs s=api)
	$(COMPOSE) --profile '*' logs -f --tail=100 $(s)

ps: ## Show service status
	$(COMPOSE) --profile '*' ps -a

reset: ## Stop everything and DELETE the database (asks first)
	@printf 'This deletes every volume of this stack. Type "yes" to continue: '; \
	read ans; [ "$$ans" = yes ] || { echo Aborted.; exit 1; }
	$(COMPOSE) --profile '*' down -v --remove-orphans

test: ## Smoke-test the running stack (CRUD, hardening, hot reload)
	bash ./smoke-test.sh

unit-test: ## Run go vet + go test in the Dockerfile's test stage
	docker build --target test .

migration: ## Create a new migration pair (make migration name=add_tags)
	@test -n "$(name)" || { echo "usage: make migration name=add_tags"; exit 1; }
	docker run --rm -v "$(CURDIR)/migrations:/migrations" migrate/migrate:v4.20.1 \
		create -ext sql -dir /migrations -seq $(name)

psql: ## Open psql in the database
	$(COMPOSE) exec postgres sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'
