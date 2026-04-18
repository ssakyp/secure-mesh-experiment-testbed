SERVICES = api-gateway auth-service transaction-service audit-service currency-exchange user-profile notification-service fraud-analytics reporting-service account-service ledger-service card-management
REGISTRY = localhost:5000/fintech

.PHONY: all build push default

all: build push

build:
	@for svc in $(SERVICES); do \
		echo "Building $$svc..."; \
		cd $$svc && docker build -t $(REGISTRY)/$$svc:latest . && cd ..; \
	done

push:
	@for svc in $(SERVICES); do \
		echo "Importing $$svc to k3d cluster..."; \
		k3d image import $(REGISTRY)/$$svc:latest -c research-cluster; \
	done

