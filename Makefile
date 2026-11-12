# cloudru-cli: сборки нет, но есть проверки и установка провайдера.
SHELL := /bin/bash
PROVIDER_VERSION ?= 2.1.6
PLUGIN_DIR := $(HOME)/.terraform.d/plugins/registry.terraform.io/cloudru/cloud/$(PROVIDER_VERSION)/$(shell go env GOOS 2>/dev/null || echo darwin)_$(shell go env GOARCH 2>/dev/null || echo arm64)

.PHONY: help check provider init plan fmt

help: ## показать цели
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | sed 's/:.*## / — /'

check: ## проверить CLI: синтаксис, shellcheck (если есть), запуск
	bash -n bin/cloudru
	@if command -v shellcheck >/dev/null; then shellcheck -S warning bin/cloudru; else echo "shellcheck нет — пропущено"; fi
	@bin/cloudru --version

provider: ## скачать провайдер cloudru/cloud в локальное зеркало
	@mkdir -p "$(PLUGIN_DIR)"
	curl -sL -o "$(PLUGIN_DIR)/terraform-provider-cloud_v$(PROVIDER_VERSION)" \
	  "https://github.com/cloud-ru/evo-terraform/releases/download/v$(PROVIDER_VERSION)/terraform-provider-cloud_$(PROVIDER_VERSION)_$(shell go env GOOS 2>/dev/null || echo darwin)_$(shell go env GOARCH 2>/dev/null || echo arm64)"
	@chmod +x "$(PLUGIN_DIR)/terraform-provider-cloud_v$(PROVIDER_VERSION)"
	@echo "провайдер в $(PLUGIN_DIR)"

init: ## tofu init в terraform/
	cd terraform && tofu init -input=false

plan: ## tofu plan в terraform/
	cd terraform && tofu plan -input=false
