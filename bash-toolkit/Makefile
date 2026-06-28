SHELL := /usr/bin/env bash
FUNCS ?= lib/funciones.sh
TEMPLATE ?= lib/bash-template.sh

.PHONY: test lint

test:
	@echo "== Test de funciones =="
	@bash -c 'set -Eeuo pipefail; source ./$(FUNCS); \
		export SCRIPT_LOG=$$(mktemp); \
		log INFO "Test INFO"; log WARNING "Test WARN"; log ERROR "Test ERR"; \
		[[ -s $$SCRIPT_LOG ]] && echo "OK log" || { echo "FAIL log"; exit 1; }; \
		[[ "$$(statusToText 0)" == "OK" ]] || { echo "FAIL statusToText"; exit 1; }; \
		echo "OK tests"'

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -x $(FUNCS) $(TEMPLATE); \
	else \
		echo "shellcheck no esta instalado. Objetivo lint omitido."; \
	fi
