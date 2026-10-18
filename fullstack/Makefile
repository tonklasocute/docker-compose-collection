# Shortcuts for this stack. Run `make` to list them.
COMPOSE ?= docker compose

.DEFAULT_GOAL := help
.PHONY: help up down logs ps reset test unit-test psql

help: ## List available targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.env:
	cp .env.example .env
	@echo "Created .env from .env.example - change the password in it."

up: .env ## Build and start everything; open http://localhost:8080
	$(COMPOSE) up -d --build --wait

down: ## Stop and remove containers (data is kept)
	$(COMPOSE) --profile '*' down

logs: ## Follow logs (one service: make logs s=nginx)
	$(COMPOSE) --profile '*' logs -f --tail=100 $(s)

ps: ## Show service status
	$(COMPOSE) --profile '*' ps -a

reset: ## Stop everything and DELETE the database (asks first)
	@printf 'This deletes every volume of this stack. Type "yes" to continue: '; \
	read ans; [ "$$ans" = yes ] || { echo Aborted.; exit 1; }
	$(COMPOSE) --profile '*' down -v --remove-orphans

test: ## Smoke-test the running stack through nginx
	bash ./smoke-test.sh

unit-test: ## Go vet + tests for the API (Dockerfile test stage)
	docker build --target test ./api

psql: ## Open psql in the (unpublished) database
	$(COMPOSE) exec postgres sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'
