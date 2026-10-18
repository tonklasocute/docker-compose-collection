# Shortcuts for this stack. Run `make` to list them.
COMPOSE ?= docker compose
# Git Bash on Windows rewrites /container/paths in arguments; turn that off
export MSYS_NO_PATHCONV := 1

.DEFAULT_GOAL := help
.PHONY: help up tools down logs ps reset test ca

help: ## List available targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  \033[36m%-7s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.env:
	cp .env.example .env
	@echo "Created .env from .env.example - change ELASTIC_PASSWORD in it."

up: .env ## Start Elasticsearch (runs setup first)
	$(COMPOSE) up -d --wait

tools: .env ## Start Elasticsearch + Kibana (profile: tools)
	$(COMPOSE) --profile tools up -d --wait

down: ## Stop and remove containers (data is kept)
	$(COMPOSE) --profile '*' down

logs: ## Follow logs (one service: make logs s=elasticsearch)
	$(COMPOSE) --profile '*' logs -f --tail=100 $(s)

ps: ## Show service status
	$(COMPOSE) --profile '*' ps -a

reset: ## Stop everything and DELETE all data and certs (asks first)
	@printf 'This deletes every volume of this stack, including certificates. Type "yes" to continue: '; \
	read ans; [ "$$ans" = yes ] || { echo Aborted.; exit 1; }
	$(COMPOSE) --profile '*' down -v --remove-orphans

test: ## Smoke-test the running stack
	bash ./smoke-test.sh

ca: ## Copy the CA certificate to ./ca.crt (for host clients)
	$(COMPOSE) cp elasticsearch:/usr/share/elasticsearch/config/certs/ca/ca.crt ./ca.crt
	@echo "Wrote ca.crt - e.g. curl --cacert ca.crt -u elastic https://localhost:9200"
