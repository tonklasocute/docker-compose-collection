# Shortcuts for this stack. Run `make` to list them.
COMPOSE ?= docker compose

.DEFAULT_GOAL := help
.PHONY: help up tools down logs ps reset test mysql

help: ## List available targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  \033[36m%-7s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.env:
	cp .env.example .env
	@echo "Created .env from .env.example - change the passwords in it."

up: .env ## Start MySQL and wait until it is healthy
	$(COMPOSE) up -d --wait

tools: .env ## Start MySQL + Adminer (profile: tools)
	$(COMPOSE) --profile tools up -d --wait

down: ## Stop and remove containers (data is kept)
	$(COMPOSE) --profile '*' down

logs: ## Follow logs (one service: make logs s=mysql)
	$(COMPOSE) --profile '*' logs -f --tail=100 $(s)

ps: ## Show service status
	$(COMPOSE) --profile '*' ps

reset: ## Stop everything and DELETE all data (asks first)
	@printf 'This deletes every volume of this stack. Type "yes" to continue: '; \
	read ans; [ "$$ans" = yes ] || { echo Aborted.; exit 1; }
	$(COMPOSE) --profile '*' down -v --remove-orphans

test: ## Smoke-test the running stack
	bash ./smoke-test.sh

mysql: ## Open the mysql client as root
	$(COMPOSE) exec mysql sh -c 'MYSQL_PWD="$$MYSQL_ROOT_PASSWORD" mysql -uroot "$$MYSQL_DATABASE"'
