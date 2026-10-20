# Shortcuts for this stack. Run `make` to list them.
COMPOSE ?= docker compose
# Git Bash on Windows rewrites /container/paths in arguments; turn that off
export MSYS_NO_PATHCONV := 1

.DEFAULT_GOAL := help
.PHONY: help up down logs ps reset test token psql

help: ## List available targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  \033[36m%-7s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.env:
	cp .env.example .env
	@echo "Created .env from .env.example - change the passwords in it."

up: .env ## Build and start Keycloak + PostgreSQL, import realms/
	$(COMPOSE) up -d --build --wait
	@echo "Admin console: http://localhost:$$($(COMPOSE) port keycloak 8080 | cut -d: -f2)/admin"

down: ## Stop and remove containers (data is kept)
	$(COMPOSE) down

logs: ## Follow logs (one service: make logs s=keycloak)
	$(COMPOSE) logs -f --tail=100 $(s)

ps: ## Show service status
	$(COMPOSE) ps

reset: ## Stop everything and DELETE all data, realms included (asks first)
	@printf 'This deletes every volume of this stack. Type "yes" to continue: '; \
	read ans; [ "$$ans" = yes ] || { echo Aborted.; exit 1; }
	$(COMPOSE) down -v --remove-orphans

test: ## Smoke-test the running stack (tokens, PKCE login)
	bash ./smoke-test.sh

token: ## Print an access token for demo-service (client credentials)
	@$(COMPOSE) exec -T keycloak bash -c 'exec 3<>/dev/tcp/127.0.0.1/8080; \
	body="grant_type=client_credentials&client_id=demo-service&client_secret=$$DEMO_CLIENT_SECRET"; \
	printf "POST /realms/demo/protocol/openid-connect/token HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: $${#body}\r\nConnection: close\r\n\r\n%s" "$$body" >&3; \
	sed -n "s/.*\"access_token\":\"\([^\"]*\)\".*/\1/p" <&3'

psql: ## Open psql in the Keycloak database
	$(COMPOSE) exec postgres sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'
