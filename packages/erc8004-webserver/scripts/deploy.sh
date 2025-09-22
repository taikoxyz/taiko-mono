#!/bin/bash

# ERC-8004 WebServer Deployment Script
# Usage: ./scripts/deploy.sh [environment] [version]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HELM_CHART="$PROJECT_ROOT/helm"

# Default values
ENVIRONMENT="${1:-staging}"
VERSION="${2:-latest}"
NAMESPACE="erc8004-${ENVIRONMENT}"
RELEASE_NAME="erc8004"
if [ "$ENVIRONMENT" = "staging" ]; then
    RELEASE_NAME="erc8004-staging"
fi

# Registry configuration
REGISTRY="${REGISTRY:-ghcr.io/taikoxyz}"
IMAGE_NAME="${IMAGE_NAME:-erc8004-webserver}"
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${VERSION}"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    local deps=("kubectl" "helm" "docker")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "$dep is not installed or not in PATH"
            exit 1
        fi
    done
    
    log_success "All dependencies are available"
}

check_cluster_connectivity() {
    log_info "Checking Kubernetes cluster connectivity..."
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        log_error "Please check your kubeconfig and cluster connectivity"
        exit 1
    fi
    
    local context=$(kubectl config current-context)
    log_success "Connected to cluster: $context"
}

validate_environment() {
    case "$ENVIRONMENT" in
        dev|development)
            ENVIRONMENT="development"
            VALUES_FILE="helm/values.dev.yaml"
            DOMAIN="localhost"
            ;;
        staging|stage)
            ENVIRONMENT="staging"
            VALUES_FILE="helm/values.yaml"
            DOMAIN="erc8004-staging.taiko.xyz"
            ;;
        prod|production)
            ENVIRONMENT="production"
            VALUES_FILE="helm/values.prod.yaml"
            DOMAIN="agent.taiko.xyz"
            ;;
        *)
            log_error "Invalid environment: $ENVIRONMENT"
            log_error "Valid environments: dev, staging, prod"
            exit 1
            ;;
    esac
    
    log_info "Deploying to environment: $ENVIRONMENT"
    log_info "Using values file: $VALUES_FILE"
}

create_namespace() {
    log_info "Creating namespace: $NAMESPACE"
    
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Namespace $NAMESPACE is ready"
}

deploy_dependencies() {
    log_info "Deploying dependencies for $ENVIRONMENT environment..."
    
    # Add Bitnami repo
    helm repo add bitnami https://charts.bitnami.com/bitnami > /dev/null 2>&1 || true
    helm repo update > /dev/null
    
    case "$ENVIRONMENT" in
        production)
            log_info "Deploying PostgreSQL with high availability..."
            helm upgrade --install "${RELEASE_NAME}-postgresql" bitnami/postgresql-ha \
                --namespace "$NAMESPACE" \
                --set postgresql.auth.username="agent_user" \
                --set postgresql.auth.database="agent_db" \
                --set postgresql.primary.persistence.size="100Gi" \
                --set postgresql.readReplicas.replicaCount=2 \
                --wait --timeout=600s
            ;;
        staging)
            log_info "Deploying PostgreSQL (single instance)..."
            helm upgrade --install "${RELEASE_NAME}-postgresql" bitnami/postgresql \
                --namespace "$NAMESPACE" \
                --set auth.username="agent_user" \
                --set auth.database="agent_db" \
                --set primary.persistence.size="50Gi" \
                --wait --timeout=600s
            ;;
        development)
            log_info "Deploying PostgreSQL (development)..."
            helm upgrade --install "${RELEASE_NAME}-postgresql" bitnami/postgresql \
                --namespace "$NAMESPACE" \
                --set auth.username="dev_user" \
                --set auth.database="dev_agent_db" \
                --set primary.persistence.enabled=false \
                --wait --timeout=300s
            ;;
    esac
    
    # Deploy Redis
    log_info "Deploying Redis..."
    local redis_args=("--namespace" "$NAMESPACE" "--wait" "--timeout=300s")
    
    if [ "$ENVIRONMENT" = "development" ]; then
        redis_args+=(
            "--set" "master.persistence.enabled=false"
        )
    else
        redis_args+=(
            "--set" "master.persistence.size=10Gi"
        )
    fi
    
    helm upgrade --install "${RELEASE_NAME}-redis" bitnami/redis \
        "${redis_args[@]}"
    
    log_success "Dependencies deployed successfully"
}

run_pre_deploy_checks() {
    log_info "Running pre-deployment checks..."
    
    # Check if image exists (if not latest)
    if [ "$VERSION" != "latest" ]; then
        log_info "Checking if image exists: $FULL_IMAGE"
        if ! docker manifest inspect "$FULL_IMAGE" &> /dev/null; then
            log_warn "Cannot verify image existence: $FULL_IMAGE"
            log_warn "Proceeding anyway..."
        else
            log_success "Image verified: $FULL_IMAGE"
        fi
    fi
    
    # Check Helm chart validity
    log_info "Validating Helm chart..."
    if ! helm lint "$HELM_CHART" > /dev/null; then
        log_error "Helm chart validation failed"
        exit 1
    fi
    log_success "Helm chart is valid"
}

run_database_migration() {
    log_info "Running database migrations..."
    
    local migration_job="migrate-$(date +%s)"
    local job_yaml="apiVersion: batch/v1
kind: Job
metadata:
  name: $migration_job
  namespace: $NAMESPACE
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: migrate
        image: $FULL_IMAGE
        command: ['alembic', 'upgrade', 'head']
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: ${RELEASE_NAME}-secret
              key: database-url
        - name: ENVIRONMENT
          value: $ENVIRONMENT"
    
    echo "$job_yaml" | kubectl apply -f -
    
    # Wait for migration to complete
    if kubectl wait --for=condition=complete job/$migration_job -n "$NAMESPACE" --timeout=300s; then
        log_success "Database migration completed successfully"
    else
        log_error "Database migration failed"
        kubectl logs job/$migration_job -n "$NAMESPACE" || true
        kubectl delete job/$migration_job -n "$NAMESPACE" --ignore-not-found=true
        exit 1
    fi
    
    # Cleanup migration job
    kubectl delete job/$migration_job -n "$NAMESPACE" --ignore-not-found=true
}

deploy_application() {
    log_info "Deploying application..."
    
    local helm_args=(
        "$RELEASE_NAME"
        "$HELM_CHART"
        "--namespace" "$NAMESPACE"
        "--values" "$PROJECT_ROOT/$VALUES_FILE"
        "--set" "image.repository=$REGISTRY/$IMAGE_NAME"
        "--set" "image.tag=$VERSION"
        "--set" "config.server.domain=$DOMAIN"
        "--wait"
        "--timeout=600s"
    )
    
    # Environment-specific overrides
    case "$ENVIRONMENT" in
        production)
            helm_args+=(
                "--set" "config.blockchain.web3Provider=https://rpc.mainnet.taiko.xyz"
                "--set" "config.blockchain.chainId=167000"
            )
            ;;
        staging)
            helm_args+=(
                "--set" "config.blockchain.web3Provider=https://rpc.test.taiko.xyz"
                "--set" "config.blockchain.chainId=167001"
            )
            ;;
        development)
            helm_args+=(
                "--set" "ingress.enabled=false"
                "--set" "config.blockchain.web3Provider=https://rpc.test.taiko.xyz"
                "--set" "config.blockchain.chainId=167001"
            )
            ;;
    esac
    
    if helm upgrade --install "${helm_args[@]}"; then
        log_success "Application deployed successfully"
    else
        log_error "Application deployment failed"
        exit 1
    fi
}

verify_deployment() {
    log_info "Verifying deployment..."
    
    # Wait for rollout to complete
    if kubectl rollout status deployment/${RELEASE_NAME}-webserver -n "$NAMESPACE" --timeout=300s; then
        log_success "Deployment rollout completed"
    else
        log_error "Deployment rollout failed"
        exit 1
    fi
    
    # Health check
    log_info "Running health check..."
    
    local pod_name
    pod_name=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=erc8004-webserver" -o jsonpath="{.items[0].metadata.name}")
    
    if [ -z "$pod_name" ]; then
        log_error "No pods found for health check"
        exit 1
    fi
    
    local health_check="kubectl exec -n $NAMESPACE $pod_name -- curl -f http://localhost:8000/health"
    if $health_check &> /dev/null; then
        log_success "Health check passed"
    else
        log_error "Health check failed"
        kubectl logs -n "$NAMESPACE" "$pod_name" --tail=50
        exit 1
    fi
    
    # Agent card check
    log_info "Checking agent card endpoint..."
    local agent_card_check="kubectl exec -n $NAMESPACE $pod_name -- curl -f http://localhost:8000/.well-known/agent-card.json"
    if $agent_card_check &> /dev/null; then
        log_success "Agent card endpoint is working"
    else
        log_warn "Agent card endpoint check failed (this may be expected if not configured)"
    fi
}

show_deployment_info() {
    log_info "Deployment Information"
    echo "======================"
    echo "Environment: $ENVIRONMENT"
    echo "Namespace: $NAMESPACE"
    echo "Release: $RELEASE_NAME"
    echo "Image: $FULL_IMAGE"
    echo "Domain: $DOMAIN"
    echo ""
    
    log_info "Useful commands:"
    echo "View pods: kubectl get pods -n $NAMESPACE"
    echo "View logs: kubectl logs -f deployment/${RELEASE_NAME}-webserver -n $NAMESPACE"
    echo "Port forward: kubectl port-forward service/${RELEASE_NAME}-webserver 8080:80 -n $NAMESPACE"
    echo "Helm status: helm status $RELEASE_NAME -n $NAMESPACE"
    
    if [ "$ENVIRONMENT" != "development" ]; then
        echo "Health check: curl https://$DOMAIN/health"
        echo "Agent card: curl https://$DOMAIN/.well-known/agent-card.json"
    else
        echo "Health check: curl http://localhost:8080/health (after port-forward)"
    fi
}

rollback_on_failure() {
    log_error "Deployment failed. Initiating rollback..."
    
    if helm rollback "$RELEASE_NAME" -n "$NAMESPACE" &> /dev/null; then
        log_success "Rollback completed"
    else
        log_error "Rollback failed. Manual intervention required."
    fi
}

cleanup() {
    log_info "Cleaning up temporary resources..."
    # Add cleanup logic if needed
}

main() {
    log_info "Starting ERC-8004 WebServer deployment"
    log_info "Environment: $ENVIRONMENT, Version: $VERSION"
    
    # Trap to handle failures
    trap rollback_on_failure ERR
    trap cleanup EXIT
    
    check_dependencies
    check_cluster_connectivity
    validate_environment
    create_namespace
    
    # Ask for confirmation in production
    if [ "$ENVIRONMENT" = "production" ]; then
        echo ""
        log_warn "🚨 PRODUCTION DEPLOYMENT WARNING 🚨"
        log_warn "You are about to deploy to PRODUCTION environment"
        log_warn "Domain: $DOMAIN"
        log_warn "Image: $FULL_IMAGE"
        echo ""
        read -p "Are you sure you want to continue? [y/N] " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deployment cancelled by user"
            exit 0
        fi
    fi
    
    deploy_dependencies
    run_pre_deploy_checks
    run_database_migration
    deploy_application
    verify_deployment
    
    log_success "🎉 Deployment completed successfully!"
    show_deployment_info
}

# Help function
show_help() {
    echo "ERC-8004 WebServer Deployment Script"
    echo ""
    echo "Usage: $0 [environment] [version]"
    echo ""
    echo "Environments:"
    echo "  dev, development  - Development environment"
    echo "  staging, stage    - Staging environment"  
    echo "  prod, production  - Production environment"
    echo ""
    echo "Examples:"
    echo "  $0 development latest"
    echo "  $0 staging v1.0.0"
    echo "  $0 production v1.2.3"
    echo ""
    echo "Environment Variables:"
    echo "  REGISTRY          - Container registry (default: ghcr.io/taikoxyz)"
    echo "  IMAGE_NAME        - Image name (default: erc8004-webserver)"
    echo ""
}

# Parse arguments
case "${1:-}" in
    -h|--help|help)
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac