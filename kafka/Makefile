# Shortcuts for this stack. Run `make` to list them.
COMPOSE ?= docker compose
KAFKA_BIN := /opt/kafka/bin
BOOTSTRAP := kafka:29092
# Git Bash on Windows rewrites /container/paths in arguments; turn that off
export MSYS_NO_PATHCONV := 1

.DEFAULT_GOAL := help
.PHONY: help up tools down logs ps reset test topics produce consume

help: ## List available targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  \033[36m%-8s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.env:
	cp .env.example .env
	@echo "Created .env from .env.example - review it."

up: .env ## Start Kafka (and create KAFKA_TOPICS)
	$(COMPOSE) up -d --wait

tools: .env ## Start Kafka + Kafka UI (profile: tools)
	$(COMPOSE) --profile tools up -d --wait

down: ## Stop and remove containers (data is kept)
	$(COMPOSE) --profile '*' down

logs: ## Follow logs (one service: make logs s=kafka)
	$(COMPOSE) --profile '*' logs -f --tail=100 $(s)

ps: ## Show service status
	$(COMPOSE) --profile '*' ps -a

reset: ## Stop everything and DELETE all data (asks first)
	@printf 'This deletes every volume of this stack. Type "yes" to continue: '; \
	read ans; [ "$$ans" = yes ] || { echo Aborted.; exit 1; }
	$(COMPOSE) --profile '*' down -v --remove-orphans

test: ## Smoke-test the running stack
	bash ./smoke-test.sh

topics: ## List topics
	$(COMPOSE) exec kafka $(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BOOTSTRAP) --list

produce: ## Type messages into a topic (make produce t=events)
	$(COMPOSE) exec kafka $(KAFKA_BIN)/kafka-console-producer.sh --bootstrap-server $(BOOTSTRAP) --topic $(t)

consume: ## Read a topic from the beginning (make consume t=events)
	$(COMPOSE) exec kafka $(KAFKA_BIN)/kafka-console-consumer.sh --bootstrap-server $(BOOTSTRAP) --topic $(t) --from-beginning
