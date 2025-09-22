# ERC-8004 Off-Chain Storage Server

Production-ready implementation of an ERC-8004 compliant off-chain storage server for Trustless Agents, designed for deployment on Kubernetes.

## 🎯 Overview

This server implements the [ERC-8004 standard](https://eips.ethereum.org/EIPS/eip-8004) for Trustless Agents, providing the required off-chain infrastructure to store AgentCards and manage feedback/validation data. Built with FastAPI, PostgreSQL, and Redis, it's designed for high availability and scalability on Kubernetes.

## ✨ Features

### ERC-8004 Compliance
- **RFC 8615 compliant AgentCard endpoint** at `/.well-known/agent-card.json`
- **Feedback Management** with full CRUD operations and pagination
- **Validation Request/Response system** with expiration handling
- **Agent Registration** with EIP-712 signature verification
- **Reputation Scoring** based on feedback aggregation

### Security & Authentication
- **Ethereum signature verification** for all write operations
- **EIP-712 structured data signing** support
- **CAIP-10 address format** compliance (`namespace:reference:address`)
- **Signature replay attack prevention** using Redis caching
- **Rate limiting** with different limits for authenticated/public endpoints
- **Input validation** using Pydantic models

### Performance & Scalability
- **Multi-tier caching** with Redis (AgentCards: 5min, Feedback: 1min, Reputation: 30s)
- **Database connection pooling** with configurable pool sizes
- **Async/await** throughout for maximum performance
- **Horizontal scaling** with stateless design
- **IPFS hash generation** for data integrity

### Monitoring & Observability
- **Prometheus metrics** endpoint at `/metrics`
- **Structured JSON logging** with correlation IDs
- **Health checks** for Kubernetes liveness/readiness probes
- **Performance metrics** tracking request duration and system resources
- **Security event logging** for audit trails

### Production Ready
- **Docker multi-stage builds** for optimized container images
- **Kubernetes Helm charts** with full production configuration
- **Database migrations** with Alembic
- **Graceful shutdown** handling
- **Resource limits** and **anti-affinity** rules
- **Network policies** for security isolation

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Load Balancer │    │   Kubernetes     │    │   Monitoring    │
│   (Nginx/ALB)   │────│   Ingress        │────│  (Prometheus)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                       ┌────────▼─────────┐
                       │  ERC-8004 Pods   │
                       │  (3-10 replicas) │
                       └────────┬─────────┘
                                │
            ┌───────────────────┼───────────────────┐
            │                   │                   │
    ┌───────▼────────┐ ┌────────▼────────┐ ┌───────▼────────┐
    │   PostgreSQL   │ │     Redis       │ │   Web3 RPC     │
    │   (Primary +   │ │   (Cache +      │ │   (Taiko)      │
    │   Replicas)    │ │   Rate Limit)   │ │                │
    └────────────────┘ └─────────────────┘ └────────────────┘
```

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose
- Kubernetes cluster (for production)
- PostgreSQL 15+
- Redis 7+

### Local Development

1. **Clone and setup**:
```bash
cd packages/erc8004-webserver
cp .env.example .env
# Edit .env with your configuration
```

2. **Start with Docker Compose**:
```bash
docker-compose up -d
```

3. **Run database migrations**:
```bash
docker-compose exec erc8004-server alembic upgrade head
```

4. **Access the application**:
- API: http://localhost:8000
- Documentation: http://localhost:8000/api/docs
- Health Check: http://localhost:8000/health

### Production Deployment

1. **Build and push Docker image**:
```bash
make docker-build
make docker-push
```

2. **Deploy with Helm**:
```bash
# Install PostgreSQL and Redis dependencies
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install erc8004-postgresql bitnami/postgresql -f helm/postgresql-values.yaml
helm install erc8004-redis bitnami/redis -f helm/redis-values.yaml

# Deploy the application
helm install erc8004 ./helm -f helm/values.prod.yaml
```

3. **Verify deployment**:
```bash
kubectl get pods -l app.kubernetes.io/name=erc8004-webserver
curl https://your-domain/.well-known/agent-card.json
```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `AGENT_DOMAIN` | Domain for agent card URIs | `agent.example.com` |
| `DATABASE_URL` | PostgreSQL connection string | `postgresql+asyncpg://...` |
| `REDIS_URL` | Redis connection string | `redis://redis:6379` |
| `WEB3_PROVIDER` | Ethereum RPC endpoint | `https://rpc.taiko.xyz` |
| `CHAIN_ID` | Ethereum chain ID | `167000` |
| `SECRET_KEY` | Application secret key | ⚠️ **Change in production** |
| `RATE_LIMIT_PUBLIC` | Public API rate limit | `100/minute` |
| `RATE_LIMIT_AUTHENTICATED` | Authenticated rate limit | `1000/minute` |

See [.env.example](.env.example) for complete configuration options.

### Kubernetes Configuration

The Helm chart supports three deployment modes:

- **Development**: `helm/values.dev.yaml` - Single replica, no persistence
- **Staging**: `helm/values.yaml` - 3 replicas, basic resources
- **Production**: `helm/values.prod.yaml` - 5+ replicas, full resources, security

## 📚 API Reference

### Core Endpoints

#### AgentCard (RFC 8615)
```http
GET /.well-known/agent-card.json
```
Returns the agent card with skills, registrations, and URI endpoints.

#### Agent Registration
```http
POST /api/v1/agent/register
Headers:
  Agent-Address: eip155:167000:0x...
  Signature: 0x...
Content-Type: application/json

{
  "agent_address": "eip155:167000:0x...",
  "agent_domain": "agent.example.com",
  "agent_card": { ... },
  "signature": "0x..."
}
```

#### Feedback Management
```http
# List feedback with pagination
GET /api/v1/feedback?page=1&page_size=20&agent_server_id=123

# Submit feedback (requires authentication)
POST /api/v1/feedback
Headers:
  Agent-Address: eip155:167000:0x...
  Signature: 0x...

# Get specific feedback
GET /api/v1/feedback/{feedback_auth_id}
```

#### Validation System
```http
# Get validation requests (DataHash -> DataURI mapping)
GET /api/v1/validations/requests

# Submit validation response
POST /api/v1/validations/responses
Headers:
  Agent-Address: eip155:167000:0x...
  Signature: 0x...
```

#### Reputation & Verification
```http
# Get reputation score
GET /api/v1/reputation/score?agent_address=eip155:167000:0x...

# Verify agent signature
POST /api/v1/agent/verify
```

### Authentication

All POST endpoints require Ethereum signature authentication:

1. **EIP-712 Signing**: Structure data according to EIP-712 standard
2. **Headers**: Include `Agent-Address` and `Signature` 
3. **CAIP-10 Format**: Use `eip155:chainId:address` format
4. **Replay Protection**: Signatures are tracked to prevent reuse

### Rate Limiting

- **Public endpoints**: 100 requests/minute per IP
- **Authenticated endpoints**: 1000 requests/minute per agent
- **Rate limit headers** included in responses

## 🔍 Monitoring

### Health Checks
```http
GET /health
```
Returns service status for Kubernetes probes.

### Metrics
```http
# Prometheus format
GET /metrics

# JSON format
GET /metrics/json
```

Key metrics tracked:
- Request count and duration by endpoint
- Database connection status and query performance
- Cache hit/miss rates
- System resources (CPU, memory, disk)
- Business metrics (agent count, feedback volume)

### Logging

Structured JSON logs include:
- **Request tracing** with correlation IDs
- **Security events** for authentication failures
- **Performance metrics** for slow operations
- **Business events** for audit trails

## 🛡️ Security

### Implemented Protections
- ✅ **Input validation** via Pydantic schemas
- ✅ **SQL injection prevention** with parameterized queries
- ✅ **XSS prevention** via proper JSON encoding
- ✅ **Rate limiting** per endpoint and client
- ✅ **Signature replay prevention**
- ✅ **Request size limits** (100KB for feedback)
- ✅ **CORS configuration**
- ✅ **Network policies** in Kubernetes

### Security Headers
- `X-Request-ID` for request tracing
- `X-Process-Time` for performance monitoring
- Custom rate limit headers

## 📊 Performance

### Benchmarks (Target SLA)
- **Response Time**: <100ms p99 for cached requests
- **Throughput**: 1000+ concurrent connections
- **Availability**: 99.9% uptime
- **Scale**: Support 1M agents, 10M feedback records

### Optimization Features
- Connection pooling (DB: 20 connections, Redis: 10)
- Multi-level caching with appropriate TTLs
- Database indexes on all query paths
- Async/await for all I/O operations
- Batch operations where possible

## 🔄 CI/CD

### GitHub Actions
```yaml
# .github/workflows/ci.yml
- Build and test Docker image
- Run security scans
- Deploy to staging
- Run integration tests
- Deploy to production (on tag)
```

### Available Commands
```bash
# Development
npm run dev          # Start development server
npm run test         # Run test suite
npm run type-check   # TypeScript checking

# Production
npm run docker:build # Build production image
npm run helm:install # Deploy with Helm
npm run migrate      # Run database migrations
```

## 🐛 Troubleshooting

### Common Issues

**Database Connection**:
```bash
# Check PostgreSQL connectivity
kubectl exec -it postgres-pod -- psql -U agent_user -d agent_db -c "SELECT 1;"
```

**Redis Cache**:
```bash
# Check Redis connectivity
kubectl exec -it redis-pod -- redis-cli -a password ping
```

**Signature Verification**:
```bash
# Verify Web3 provider connection
curl -X POST https://rpc.taiko.xyz \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### Logs and Debugging
```bash
# View application logs
kubectl logs -f deployment/erc8004-webserver

# Check specific security events
kubectl logs -f deployment/erc8004-webserver | jq '.security_event'

# Monitor performance
kubectl logs -f deployment/erc8004-webserver | jq '.performance_event'
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup
```bash
# Install dependencies
pip install -r requirements.txt

# Setup pre-commit hooks
pre-commit install

# Run tests
pytest tests/ -v --cov=app

# Start development server
uvicorn app.main:app --reload
```

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/taikoxyz/taiko-mono/issues)
- **Security**: security@taiko.xyz
- **Documentation**: [Full API Documentation](./API.md)
- **Deployment Guide**: [Kubernetes Deployment](./DEPLOYMENT.md)

---

Built with ❤️ for the Taiko ecosystem