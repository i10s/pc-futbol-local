# Developer helpers. End users do not need this file — just run ./pcf
.DEFAULT_GOAL := help
SHELL := /bin/bash

.PHONY: help list check lint test all

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

list: ## List available games
	@./pcf list

check: ## Validate data/games.json
	@python3 scripts/check-games.py

lint: ## Lint shell + check Python syntax
	@shellcheck -e SC1091 pcf scripts/lib.sh scripts/selftest.sh mirror/cloudflare/sync-to-r2.sh
	@python3 -m py_compile scripts/serve.py scripts/_game.py scripts/check-games.py
	@echo "lint OK"

test: check ## Run the server self-test (Range + security)
	@bash scripts/selftest.sh

all: lint check test ## Run everything CI runs (except PowerShell)
