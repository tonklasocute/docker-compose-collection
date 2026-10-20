# Shortcuts for this stack. Run `make` to list them.
COMPOSE ?= docker compose

.DEFAULT_GOAL := help
.PHONY: help up down logs ps reset test admin queues export

help: ## List available targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  \033[36m%-7s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.env:
	cp .env.example .env
	@echo "Created .env from .env.example - change the password in it."

up: .env ## Start RabbitMQ, import definitions.json, wait until healthy
	$(COMPOSE) up -d --wait

down: ## Stop and remove containers (data is kept)
	$(COMPOSE) down

logs: ## Follow logs
	$(COMPOSE) logs -f --tail=100

ps: ## Show service status
	$(COMPOSE) ps

reset: ## Stop everything and DELETE all data (asks first)
	@printf 'This deletes every volume of this stack. Type "yes" to continue: '; \
	read ans; [ "$$ans" = yes ] || { echo Aborted.; exit 1; }
	$(COMPOSE) down -v --remove-orphans

test: ## Smoke-test the running stack
	bash ./smoke-test.sh

admin: ## Run rabbitmqadmin (make admin a="list exchanges")
	$(COMPOSE) exec rabbitmq rabbitmqadmin $(a)

queues: ## List queues in the vhost with message counts
	$(COMPOSE) exec rabbitmq rabbitmqadmin list queues

export: ## Print the vhost's current definitions as JSON (to update definitions.json)
	@$(COMPOSE) exec -T rabbitmq rabbitmqadmin definitions export_from_vhost --stdout
