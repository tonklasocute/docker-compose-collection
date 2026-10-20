# Shortcuts for this stack. Run `make` to list them.
COMPOSE ?= docker compose

.DEFAULT_GOAL := help
.PHONY: help up demo down logs ps reset test htpasswd certs

help: ## List available targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  \033[36m%-9s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.env:
	cp .env.example .env
	@echo "Created .env from .env.example - set DOMAIN and the dashboard login in it."

up: .env ## Start Traefik + socket proxy
	$(COMPOSE) up -d --wait

demo: .env ## Also start the whoami demo backend (profile: demo)
	$(COMPOSE) --profile demo up -d --wait
	@echo "Try: curl -k https://whoami.localhost   (or your DOMAIN)"

down: ## Stop and remove containers (certificates are kept)
	$(COMPOSE) --profile '*' down

logs: ## Follow logs (one service: make logs s=traefik)
	$(COMPOSE) --profile '*' logs -f --tail=100 $(s)

ps: ## Show service status
	$(COMPOSE) --profile '*' ps

reset: ## Stop everything and DELETE acme.json / all certificates (asks first)
	@printf 'This deletes every volume of this stack, including issued certificates. Type "yes" to continue: '; \
	read ans; [ "$$ans" = yes ] || { echo Aborted.; exit 1; }
	$(COMPOSE) --profile '*' down -v --remove-orphans

test: ## Smoke-test the running stack
	bash ./smoke-test.sh

htpasswd: ## Print a dashboard login for .env (make htpasswd u=admin p='secret')
	@test -n "$(u)" -a -n "$(p)" || { echo "usage: make htpasswd u=admin p='secret'"; exit 1; }
	@printf "TRAEFIK_DASHBOARD_USERS='%s'\n" "$$(docker run --rm httpd:2.4.69-alpine3.24 htpasswd -nbB -C 10 '$(u)' '$(p)')"

certs: ## List the domains that have a certificate in acme.json
	@$(COMPOSE) exec -T traefik sh -c 'cat /letsencrypt/acme.json' | \
		sed -n 's/.*"main": "\([^"]*\)".*/\1/p'
