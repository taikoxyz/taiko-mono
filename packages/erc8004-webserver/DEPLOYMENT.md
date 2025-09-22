# Kubernetes Deployment Guide

Complete guide for deploying the ERC-8004 Off-Chain Storage Server to Kubernetes.

## 📋 Prerequisites

### Kubernetes Cluster Requirements
- **Kubernetes**: v1.24+ 
- **Helm**: v3.8+
- **Storage**: Dynamic provisioning with StorageClass
- **Ingress**: nginx-ingress controller
- **Cert Manager**: For TLS certificates (recommended)
- **Monitoring**: Prometheus operator (optional)

### Resource Requirements

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage |
|-----------|-------------|-----------|----------------|--------------|---------|
| App (per replica) | 500m | 1000m | 512Mi | 1Gi | - |
| PostgreSQL | 1000m | 2000m | 1Gi | 2Gi | 50Gi |
| Redis | 250m | 500m | 512Mi | 1Gi | 10Gi |

## 🚀 Quick Deployment

### 1. Add Required Helm Repositories
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### 2. Create Namespace
```bash
kubectl create namespace erc8004
kubectl config set-context --current --namespace=erc8004
```

### 3. Deploy Dependencies
```bash
# PostgreSQL
helm install erc8004-postgresql bitnami/postgresql \
  --set auth.postgresPassword="secure_postgres_password" \
  --set auth.username="agent_user" \
  --set auth.password="secure_agent_password" \
  --set auth.database="agent_db" \
  --set primary.persistence.size="50Gi"

# Redis
helm install erc8004-redis bitnami/redis \
  --set auth.password="secure_redis_password" \
  --set master.persistence.size="10Gi"
```

### 4. Deploy Application
```bash
# Development
helm install erc8004 ./helm -f helm/values.dev.yaml

# Production
helm install erc8004 ./helm -f helm/values.prod.yaml
```

## 🔧 Production Deployment

### 1. Prepare Environment

#### Create Production Values
```bash
cp helm/values.prod.yaml helm/values.production.yaml
```

#### Update Configuration
```yaml
# helm/values.production.yaml
image:
  repository: your-registry.com/erc8004-server
  tag: "v1.0.0"

ingress:
  hosts:
    - host: agent.yourdomain.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: agent-tls
      hosts:
        - agent.yourdomain.com

config:
  server:
    domain: "agent.yourdomain.com"
  blockchain:
    web3Provider: "https://rpc.mainnet.taiko.xyz"
    contractAddress: "0x..." # Your deployed contract
```

### 2. Secure Secrets Management

#### Create Secret with Kubectl
```bash
kubectl create secret generic erc8004-secrets \
  --from-literal=database-password="$(openssl rand -base64 32)" \
  --from-literal=redis-password="$(openssl rand -base64 32)" \
  --from-literal=secret-key="$(openssl rand -base64 64)"
```

#### Or use External Secrets Operator
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.yourdomain.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "erc8004-role"
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: erc8004-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: erc8004-secrets
  data:
  - secretKey: database-password
    remoteRef:
      key: erc8004/database
      property: password
  - secretKey: redis-password
    remoteRef:
      key: erc8004/redis
      property: password
  - secretKey: secret-key
    remoteRef:
      key: erc8004/app
      property: secret-key
```

### 3. Database Setup

#### Deploy PostgreSQL with High Availability
```yaml
# postgresql-ha-values.yaml
postgresql:
  replication:
    enabled: true
    user: replicator
    password: "secure_replication_password"
  
  primary:
    persistence:
      size: 100Gi
      storageClass: "fast-ssd"
    resources:
      requests:
        cpu: 1000m
        memory: 2Gi
      limits:
        cpu: 2000m
        memory: 4Gi
  
  readReplicas:
    replicaCount: 2
    persistence:
      size: 100Gi
      storageClass: "fast-ssd"
```

```bash
helm install erc8004-postgresql bitnami/postgresql-ha \
  -f postgresql-ha-values.yaml
```

#### Run Initial Migrations
```bash
# Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql --timeout=300s

# Create migration job
kubectl create job migrate-initial \
  --image=your-registry.com/erc8004-server:v1.0.0 \
  -- alembic upgrade head
```

### 4. Monitoring Setup

#### Install Prometheus Operator
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

#### Configure ServiceMonitor
```yaml
# servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: erc8004-metrics
  labels:
    app.kubernetes.io/name: erc8004-webserver
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: erc8004-webserver
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
```

### 5. Deploy Application
```bash
helm install erc8004 ./helm \
  -f helm/values.production.yaml \
  --set secrets.existingSecret="erc8004-secrets"
```

## 🔍 Post-Deployment Verification

### 1. Check Pod Status
```bash
kubectl get pods -l app.kubernetes.io/name=erc8004-webserver
```

### 2. Verify Services
```bash
kubectl get services
kubectl get ingress
```

### 3. Health Checks
```bash
# Port forward for testing
kubectl port-forward service/erc8004-webserver 8080:80

# Test health endpoint
curl http://localhost:8080/health

# Test agent card endpoint
curl http://localhost:8080/.well-known/agent-card.json
```

### 4. Check Logs
```bash
kubectl logs -f deployment/erc8004-webserver
```

## 🔄 Upgrades and Updates

### Rolling Updates
```bash
# Update image tag
helm upgrade erc8004 ./helm \
  --set image.tag="v1.1.0" \
  --reuse-values

# Watch rollout
kubectl rollout status deployment/erc8004-webserver
```

### Database Migrations
```bash
# Create migration job
kubectl create job migrate-v1-1-0 \
  --image=your-registry.com/erc8004-server:v1.1.0 \
  -- alembic upgrade head
```

### Rollback Strategy
```bash
# Check rollout history
kubectl rollout history deployment/erc8004-webserver

# Rollback to previous version
kubectl rollout undo deployment/erc8004-webserver

# Or rollback to specific revision
kubectl rollout undo deployment/erc8004-webserver --to-revision=2
```

## 🛡️ Security Configuration

### Network Policies
```yaml
# networkpolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: erc8004-network-policy
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: erc8004-webserver
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8000
  egress:
  - to:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: postgresql
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: redis
    ports:
    - protocol: TCP
      port: 6379
  - to: []
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

### Pod Security Standards
```yaml
# podsecuritypolicy.yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: erc8004-psp
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
```

### TLS Configuration
```yaml
# certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: agent-tls
spec:
  secretName: agent-tls
  dnsNames:
  - agent.yourdomain.com
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
```

## 📊 Monitoring and Alerting

### Grafana Dashboard
```json
{
  "dashboard": {
    "title": "ERC-8004 Server Metrics",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "rate(erc8004_requests_total[5m])",
            "legendFormat": "{{method}} {{endpoint}}"
          }
        ]
      },
      {
        "title": "Response Time",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(erc8004_request_duration_seconds_bucket[5m]))",
            "legendFormat": "95th percentile"
          }
        ]
      },
      {
        "title": "Active Agents",
        "targets": [
          {
            "expr": "erc8004_agents_total",
            "legendFormat": "Total Agents"
          }
        ]
      }
    ]
  }
}
```

### Prometheus Alerts
```yaml
# alerts.yaml
groups:
- name: erc8004-alerts
  rules:
  - alert: ERC8004HighErrorRate
    expr: rate(erc8004_requests_total{status_code!~"2.*"}[5m]) > 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High error rate detected"
      description: "Error rate is {{ $value }} errors per second"

  - alert: ERC8004DatabaseDown
    expr: erc8004_database_connection_status == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Database connection lost"

  - alert: ERC8004HighMemoryUsage
    expr: erc8004_system_memory_usage_percent > 80
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage: {{ $value }}%"

  - alert: ERC8004PodCrashLooping
    expr: rate(kube_pod_container_status_restarts_total{pod=~"erc8004-webserver-.*"}[15m]) > 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Pod is crash looping"
```

## 🔧 Troubleshooting

### Common Issues

#### Pod Startup Issues
```bash
# Check pod events
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name> --previous

# Check resource constraints
kubectl top pods
kubectl describe nodes
```

#### Database Connection Problems
```bash
# Test database connectivity
kubectl run -it --rm debug --image=postgres:15 --restart=Never -- \
  psql -h erc8004-postgresql -U agent_user -d agent_db

# Check database logs
kubectl logs -f erc8004-postgresql-0
```

#### Redis Connection Issues
```bash
# Test Redis connectivity
kubectl run -it --rm debug --image=redis:7 --restart=Never -- \
  redis-cli -h erc8004-redis-master -a password ping

# Check Redis logs
kubectl logs -f erc8004-redis-master-0
```

#### Ingress/TLS Issues
```bash
# Check ingress status
kubectl describe ingress erc8004-webserver

# Check certificate status
kubectl describe certificate agent-tls

# Test TLS
curl -v https://agent.yourdomain.com/.well-known/agent-card.json
```

### Performance Issues

#### High CPU Usage
```bash
# Check current resource usage
kubectl top pods

# Review resource limits
kubectl describe pod <pod-name> | grep -A 5 -B 5 "Limits\|Requests"

# Scale up if needed
kubectl scale deployment erc8004-webserver --replicas=5
```

#### Database Performance
```bash
# Check slow queries
kubectl exec -it erc8004-postgresql-0 -- \
  psql -U agent_user -d agent_db -c "
  SELECT query, mean_time, calls 
  FROM pg_stat_statements 
  ORDER BY mean_time DESC 
  LIMIT 10;"

# Check database connections
kubectl exec -it erc8004-postgresql-0 -- \
  psql -U agent_user -d agent_db -c "
  SELECT count(*), state 
  FROM pg_stat_activity 
  GROUP BY state;"
```

### Log Analysis
```bash
# Filter for errors
kubectl logs -f deployment/erc8004-webserver | jq 'select(.level == "error")'

# Security events
kubectl logs -f deployment/erc8004-webserver | jq 'select(.security_event == true)'

# Performance events
kubectl logs -f deployment/erc8004-webserver | jq 'select(.performance_event == true)'

# Request tracing
kubectl logs -f deployment/erc8004-webserver | jq 'select(.request_id == "req_abc123")'
```

## 🔄 Backup and Recovery

### Database Backup
```bash
# Create backup job
kubectl create job backup-$(date +%Y%m%d) \
  --image=postgres:15 \
  -- pg_dump -h erc8004-postgresql -U agent_user -d agent_db > /backup/dump-$(date +%Y%m%d).sql

# Or use persistent volume backup
kubectl create job backup-pv-$(date +%Y%m%d) \
  --image=backup-tool \
  -- backup-pv /var/lib/postgresql/data s3://backup-bucket/
```

### Recovery Procedure
```bash
# Scale down application
kubectl scale deployment erc8004-webserver --replicas=0

# Restore database
kubectl create job restore-$(date +%Y%m%d) \
  --image=postgres:15 \
  -- psql -h erc8004-postgresql -U agent_user -d agent_db < /backup/dump.sql

# Scale up application
kubectl scale deployment erc8004-webserver --replicas=3
```

## 📈 Scaling Strategies

### Horizontal Pod Autoscaling
```yaml
# hpa-custom.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: erc8004-webserver-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: erc8004-webserver
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  - type: Pods
    pods:
      metric:
        name: erc8004_requests_per_second
      target:
        type: AverageValue
        averageValue: "100"
```

### Vertical Pod Autoscaling
```yaml
# vpa.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: erc8004-webserver-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: erc8004-webserver
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: erc8004-webserver
      maxAllowed:
        cpu: 2
        memory: 4Gi
      minAllowed:
        cpu: 100m
        memory: 128Mi
```

---

This deployment guide provides a comprehensive approach to running the ERC-8004 server in production Kubernetes environments with proper security, monitoring, and operational practices.