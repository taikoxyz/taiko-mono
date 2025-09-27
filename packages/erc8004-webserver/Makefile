# ERC-8004 WebServer Makefile

.PHONY: help dev test build deploy clean
.DEFAULT_GOAL := help

# Variables
DOCKER_IMAGE := erc8004-server
DOCKER_TAG := latest
REGISTRY := ghcr.io/taikoxyz
NAMESPACE := erc8004
HELM_RELEASE := erc8004

help: ## Show this help message
	@echo "ERC-8004 WebServer Development Commands"
	@echo "======================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Development commands
dev: ## Start development server with hot reload
	uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

install: ## Install Python dependencies
	pip install -r requirements.txt

test: ## Run test suite
	pytest tests/ -v --cov=app --cov-report=html

test-watch: ## Run tests in watch mode
	pytest-watch

lint: ## Run code linting
	flake8 app tests
	black --check app tests
	mypy app --ignore-missing-imports

format: ## Format code with black
	black app tests

# Database commands
db-migrate: ## Run database migrations
	alembic upgrade head

db-migrate-create: ## Create new migration
	alembic revision --autogenerate

db-reset: ## Reset database (WARNING: destructive)
	alembic downgrade base
	alembic upgrade head

# Docker commands
docker-build: ## Build Docker image
	docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

docker-run: ## Run Docker container locally
	docker-compose up -d

docker-stop: ## Stop Docker containers
	docker-compose down

docker-push: ## Push Docker image to registry
	docker tag $(DOCKER_IMAGE):$(DOCKER_TAG) $(REGISTRY)/$(DOCKER_IMAGE):$(DOCKER_TAG)
	docker push $(REGISTRY)/$(DOCKER_IMAGE):$(DOCKER_TAG)

docker-clean: ## Clean Docker images and containers
	docker-compose down --volumes --remove-orphans
	docker system prune -af

# Kubernetes/Helm commands
k8s-namespace: ## Create Kubernetes namespace
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -

helm-install: k8s-namespace ## Install with Helm (development)
	helm install $(HELM_RELEASE) ./helm \
		--namespace $(NAMESPACE) \
		--values helm/values.dev.yaml

helm-upgrade: ## Upgrade Helm deployment
	helm upgrade $(HELM_RELEASE) ./helm \
		--namespace $(NAMESPACE) \
		--reuse-values

helm-uninstall: ## Uninstall Helm deployment
	helm uninstall $(HELM_RELEASE) --namespace $(NAMESPACE)

helm-template: ## Generate Kubernetes manifests from Helm chart
	helm template $(HELM_RELEASE) ./helm \
		--values helm/values.dev.yaml \
		--output-dir ./k8s-manifests

# Production deployment commands
deploy-staging: ## Deploy to staging environment
	helm upgrade --install $(HELM_RELEASE)-staging ./helm \
		--namespace $(NAMESPACE)-staging \
		--create-namespace \
		--values helm/values.yaml \
		--set image.tag=$(DOCKER_TAG) \
		--set config.server.domain="erc8004-staging.taiko.xyz" \
		--wait

deploy-prod: ## Deploy to production environment
	@echo "🚨 Production deployment requires manual confirmation"
	@read -p "Are you sure you want to deploy to production? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		helm upgrade --install $(HELM_RELEASE) ./helm \
			--namespace $(NAMESPACE)-prod \
			--create-namespace \
			--values helm/values.prod.yaml \
			--set image.tag=$(DOCKER_TAG) \
			--wait; \
	else \
		echo "Deployment cancelled"; \
	fi

# Monitoring commands
logs: ## Show application logs
	kubectl logs -f deployment/$(HELM_RELEASE)-webserver -n $(NAMESPACE)

port-forward: ## Forward local port to service
	kubectl port-forward service/$(HELM_RELEASE)-webserver 8080:80 -n $(NAMESPACE)

status: ## Show deployment status
	kubectl get pods,services,ingress -n $(NAMESPACE)
	helm status $(HELM_RELEASE) -n $(NAMESPACE)

metrics: ## Show metrics endpoint
	@echo "Metrics endpoint: http://localhost:8080/metrics"
	@echo "Health endpoint: http://localhost:8080/health"
	@echo "Agent card: http://localhost:8080/.well-known/agent-card.json"

# Testing commands
test-integration: ## Run integration tests against deployed service
	@echo "Running integration tests..."
	curl -f http://localhost:8080/health
	curl -f http://localhost:8080/.well-known/agent-card.json
	@echo "✅ Integration tests passed"

test-load: ## Run load tests with k6
	k6 run tests/load/basic-load-test.js

smoke-test: ## Run smoke tests
	@echo "Running smoke tests..."
	@python tests/smoke_test.py
	@echo "✅ Smoke tests passed"

# Security commands
security-scan: ## Run security scans
	bandit -r app/
	safety check
	trivy fs .

# Backup commands
backup-db: ## Backup database
	kubectl create job backup-$(shell date +%Y%m%d-%H%M) \
		--image=postgres:15 \
		--namespace $(NAMESPACE) \
		-- pg_dump -h $(HELM_RELEASE)-postgresql -U agent_user -d agent_db

# Cleanup commands
clean: ## Clean up temporary files
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
	find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	rm -rf .coverage htmlcov/ .pytest_cache/ .mypy_cache/

clean-k8s: ## Clean up Kubernetes resources
	kubectl delete namespace $(NAMESPACE) --ignore-not-found=true

# Documentation commands
docs-serve: ## Serve API documentation locally
	@echo "API docs available at http://localhost:8000/api/docs"
	@echo "Starting development server..."
	uvicorn app.main:app --host 0.0.0.0 --port 8000

docs-generate: ## Generate API documentation
	@echo "Generating API documentation..."
	@python -c "
import json
from app.main import app
with open('openapi.json', 'w') as f:
    json.dump(app.openapi(), f, indent=2)
print('OpenAPI spec generated: openapi.json')
"

# Development setup
setup: ## Setup development environment
	@echo "Setting up development environment..."
	cp .env.example .env
	@echo "📝 Edit .env with your configuration"
	pip install -r requirements.txt
	@echo "✅ Development environment ready!"

# CI/CD helpers
ci-build: ## Build for CI (no cache)
	docker build --no-cache -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

ci-test: ## Run tests in CI environment
	pytest tests/ -v --cov=app --cov-report=xml --tb=short

ci-security: ## Run security checks in CI
	bandit -r app -f json -o bandit-report.json || true
	safety check --json --output safety-report.json || true

# Version management
version: ## Show current version
	@python -c "
import json
with open('package.json') as f:
    print(json.load(f)['version'])
"

tag: ## Create git tag for current version
	@VERSION=$$(python -c "import json; print(json.load(open('package.json'))['version'])") && \
	git tag -a v$$VERSION -m "Release v$$VERSION" && \
	echo "Created tag v$$VERSION"

# Utilities
shell: ## Get shell access to running pod
	kubectl exec -it deployment/$(HELM_RELEASE)-webserver -n $(NAMESPACE) -- /bin/bash

debug: ## Start debug container
	kubectl run debug --rm -it --image=python:3.11-slim --namespace $(NAMESPACE) -- bash