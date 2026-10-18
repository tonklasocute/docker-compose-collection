# Shortcuts for this stack. Run `make` to list them.
COMPOSE ?= docker compose

.DEFAULT_GOAL := help
.PHONY: help up tools down logs ps reset test shell

help: ## List available targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  \033[36m%-7s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.env:
	cp .env.example .env
	@echo "Created .env from .env.example - change the passwords in it."

up: .env ## Start MongoDB and wait until it is PRIMARY
	$(COMPOSE) up -d --wait

tools: .env ## Start MongoDB + mongo-express (profile: tools)
	$(COMPOSE) --profile tools up -d --wait

down: ## Stop and remove containers (data is kept)
	$(COMPOSE) --profile '*' down

logs: ## Follow logs (one service: make logs s=mongodb)
	$(COMPOSE) --profile '*' logs -f --tail=100 $(s)

ps: ## Show service status
	$(COMPOSE) --profile '*' ps

reset: ## Stop everything and DELETE all data (asks first)
	@printf 'This deletes every volume of this stack. Type "yes" to continue: '; \
	read ans; [ "$$ans" = yes ] || { echo Aborted.; exit 1; }
	$(COMPOSE) --profile '*' down -v --remove-orphans

test: ## Smoke-test the running stack
	bash ./smoke-test.sh

shell: ## Open mongosh as root
	$(COMPOSE) exec mongodb sh -c 'mongosh -u "$$MONGO_INITDB_ROOT_USERNAME" -p "$$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin'
