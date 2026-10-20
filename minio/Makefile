# Shortcuts for this stack. Run `make` to list them.
COMPOSE ?= docker compose

.DEFAULT_GOAL := help
.PHONY: help up down logs ps reset test mcli buckets

help: ## List available targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  \033[36m%-8s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.env:
	cp .env.example .env
	@echo "Created .env from .env.example - change the passwords in it."

up: .env ## Start MinIO, create buckets + app user, wait until healthy
	$(COMPOSE) up -d --wait

down: ## Stop and remove containers (data is kept)
	$(COMPOSE) down

logs: ## Follow logs
	$(COMPOSE) logs -f --tail=100

ps: ## Show service status
	$(COMPOSE) ps

reset: ## Stop everything and DELETE all buckets and objects (asks first)
	@printf 'This deletes every volume of this stack. Type "yes" to continue: '; \
	read ans; [ "$$ans" = yes ] || { echo Aborted.; exit 1; }
	$(COMPOSE) down -v --remove-orphans

test: ## Smoke-test the running stack (S3 PUT/GET/DELETE, access control)
	bash ./smoke-test.sh

mcli: ## Run the S3/admin client as root (make mcli a="ls local/app")
	$(COMPOSE) exec minio mcli $(a)

buckets: ## List buckets
	$(COMPOSE) exec minio mcli ls local
