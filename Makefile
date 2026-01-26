.PHONY: help deploy test stats purge verify clean

help: ## Show this help message
	@echo "KOME Cache Node - Available Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

deploy: ## Deploy cache node to Raspberry Pi
	@./scripts/deploy.sh

test: ## Test cache node functionality
	@./scripts/test.sh

stats: ## Show cache statistics
	@./scripts/stats.sh

purge: ## Purge cache
	@./scripts/purge.sh

verify: ## Verify connectivity before deployment
	@./scripts/verify-connectivity.sh

clean: ## Clean local test artifacts
	@rm -rf cache/ nginx-cache/ *.log
