# ERC-8004 Off-Chain Storage Server API Documentation

Complete API reference for the ERC-8004 compliant off-chain storage server.

## 📋 Table of Contents

1. [Authentication](#authentication)
2. [RFC 8615 AgentCard Endpoint](#rfc-8615-agentcard-endpoint)
3. [Agent Management](#agent-management)
4. [Feedback Management](#feedback-management)
5. [Validation System](#validation-system)
6. [Reputation System](#reputation-system)
7. [Health & Monitoring](#health--monitoring)
8. [Error Responses](#error-responses)
9. [Rate Limiting](#rate-limiting)

## 🔐 Authentication

All POST endpoints (except health checks) require Ethereum signature verification.

### Headers Required
- `Authorization: Bearer <message_to_be_signed>`
- `Agent-Address: <CAIP-10_address>`
- `Signature: <ethereum_signature>`

### Address Format (CAIP-10)
```
eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8
```

### EIP-712 Signature Example
```javascript
const domain = {
  name: "ERC8004-OffChainStorage",
  version: "1",
  chainId: 167000,
  verifyingContract: "0x0000000000000000000000000000000000000000"
};

const types = {
  AgentRegistration: [
    { name: "agentAddress", type: "address" },
    { name: "agentDomain", type: "string" },
    { name: "agentCardHash", type: "bytes32" },
    { name: "timestamp", type: "uint256" }
  ]
};

const message = {
  agentAddress: "0x742d35Cc...",
  agentDomain: "agent.example.com",
  agentCardHash: "0x...",
  timestamp: 1234567890
};

const signature = await wallet._signTypedData(domain, types, message);
```

---

## 🏠 RFC 8615 AgentCard Endpoint

### Get Agent Card
Returns the agent card in RFC 8615 compliant format.

**Endpoint**: `GET /.well-known/agent-card.json`

**Response**:
```json
{
  "name": "AI Trading Agent",
  "description": "Automated cryptocurrency trading agent with risk management",
  "version": "1.2.0",
  "skills": [
    {
      "skillId": "crypto-trading",
      "description": "Execute cryptocurrency trades with risk management",
      "inputs": {
        "symbol": "string",
        "amount": "number",
        "strategy": "string"
      },
      "outputs": {
        "transactionId": "string",
        "executedPrice": "number",
        "status": "string"
      }
    }
  ],
  "registrations": [
    {
      "agentId": 12345,
      "agentAddress": "eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8",
      "signature": "0x1a2b3c4d5e6f7890abcdef..."
    }
  ],
  "trustModels": ["reputation", "stake", "tee"],
  "FeedbackDataURI": "https://agent.taiko.xyz/api/v1/feedback",
  "ValidationRequestsURI": "https://agent.taiko.xyz/api/v1/validations/requests",
  "ValidationResponsesURI": "https://agent.taiko.xyz/api/v1/validations/responses"
}
```

**Caching**: 5 minutes TTL

---

## 🤖 Agent Management

### Register Agent
Register or update an agent in the system.

**Endpoint**: `POST /api/v1/agent/register`

**Headers**:
- `Agent-Address: eip155:167000:0x...`
- `Signature: 0x...`

**Request Body**:
```json
{
  "agent_address": "eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8",
  "agent_domain": "agent.example.com",
  "agent_card": {
    "name": "AI Trading Agent",
    "description": "Automated cryptocurrency trading agent",
    "version": "1.2.0",
    "skills": [...],
    "registrations": [...],
    "trustModels": ["reputation", "stake"],
    "FeedbackDataURI": "https://agent.example.com/api/v1/feedback",
    "ValidationRequestsURI": "https://agent.example.com/api/v1/validations/requests",
    "ValidationResponsesURI": "https://agent.example.com/api/v1/validations/responses"
  },
  "signature": "0x1a2b3c4d5e6f7890abcdef..."
}
```

**Response**:
```json
{
  "agent_id": 123,
  "agent_address": "eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8",
  "agent_domain": "agent.example.com",
  "agent_card": { ... },
  "signature": "0x1a2b3c4d...",
  "created_at": "2024-01-01T00:00:00.000Z",
  "updated_at": "2024-01-01T00:00:00.000Z",
  "is_active": true
}
```

### Verify Agent Signature
Verify an agent's signature and registration status.

**Endpoint**: `POST /api/v1/agent/verify`

**Request Body**:
```json
{
  "message": "Hello, World!",
  "signature": "0x1a2b3c4d5e6f7890abcdef...",
  "address": "eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8"
}
```

**Response**:
```json
{
  "valid": true,
  "registered": true,
  "agent_domain": "agent.example.com",
  "verified_at": "2024-01-01T12:00:00.000Z"
}
```

---

## 📝 Feedback Management

### List Feedback
Get paginated list of feedback with optional filtering.

**Endpoint**: `GET /api/v1/feedback`

**Query Parameters**:
- `page` (int): Page number (default: 1)
- `page_size` (int): Items per page (default: 20, max: 100)
- `agent_server_id` (int): Filter by server agent ID
- `agent_skill_id` (string): Filter by skill ID
- `min_rating` (int): Minimum rating (0-100)
- `max_rating` (int): Maximum rating (0-100)

**Example**: `GET /api/v1/feedback?page=1&page_size=10&min_rating=80`

**Response**:
```json
{
  "items": [
    {
      "id": 1,
      "FeedbackAuthID": "eip155:167000:0x123...",
      "AgentSkillId": "crypto-trading",
      "TaskId": "trade-btc-001",
      "contextId": "session-abc123",
      "Rating": 95,
      "ProofOfPayment": {
        "txHash": "0xabc123...",
        "amount": "100",
        "token": "USDC"
      },
      "Data": {
        "completionTime": 30,
        "accuracy": 0.98
      },
      "signature": "0x1a2b3c...",
      "created_at": "2024-01-01T12:00:00.000Z",
      "ipfs_hash": "QmYwAPJzv5CZsnA..."
    }
  ],
  "total": 150,
  "page": 1,
  "page_size": 10,
  "total_pages": 15
}
```

**Caching**: 1 minute TTL

### Submit Feedback
Submit new feedback for an agent (requires authentication).

**Endpoint**: `POST /api/v1/feedback`

**Headers**:
- `Agent-Address: eip155:167000:0x...`
- `Signature: 0x...`

**Request Body**:
```json
{
  "FeedbackAuthID": "eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8",
  "AgentSkillId": "crypto-trading",
  "TaskId": "trade-btc-001",
  "contextId": "session-abc123",
  "Rating": 95,
  "ProofOfPayment": {
    "txHash": "0xabc123def456...",
    "amount": "100",
    "token": "USDC"
  },
  "Data": {
    "completionTime": 30,
    "accuracy": 0.98,
    "notes": "Excellent execution with minimal slippage"
  }
}
```

**Response**:
```json
{
  "id": 1,
  "FeedbackAuthID": "eip155:167000:0x742d35Cc...",
  "AgentSkillId": "crypto-trading",
  "TaskId": "trade-btc-001",
  "contextId": "session-abc123",
  "Rating": 95,
  "ProofOfPayment": { ... },
  "Data": { ... },
  "signature": "0x1a2b3c4d...",
  "created_at": "2024-01-01T12:00:00.000Z",
  "ipfs_hash": "QmYwAPJzv5CZsnA..."
}
```

### Get Specific Feedback
Retrieve specific feedback by auth ID.

**Endpoint**: `GET /api/v1/feedback/{feedback_auth_id}`

**Example**: `GET /api/v1/feedback/eip155:167000:0x742d35Cc...`

**Response**: Same as feedback item in list response.

---

## ✅ Validation System

### Get Validation Requests
Returns DataHash -> DataURI mapping for active validation requests.

**Endpoint**: `GET /api/v1/validations/requests`

**Response**:
```json
{
  "requests": {
    "0xa1b2c3d4e5f6...": "https://storage.agent.com/validation-data/abc123.json",
    "0x1a2b3c4d5e6f...": "https://storage.agent.com/validation-data/def456.json",
    "0xabcdef123456...": "https://storage.agent.com/validation-data/ghi789.json"
  }
}
```

### Submit Validation Request
Submit a new validation request (requires authentication).

**Endpoint**: `POST /api/v1/validations/requests`

**Headers**:
- `Agent-Address: eip155:167000:0x...`
- `Signature: 0x...`

**Request Body**:
```json
{
  "data_hash": "0xa1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890",
  "agent_validator_id": 456,
  "data_uri": "https://storage.agent.com/validation-data/abc123.json",
  "validation_data": {
    "type": "trade_execution",
    "parameters": {
      "symbol": "BTC/USDT",
      "expectedPrice": 45000,
      "tolerance": 0.005
    }
  },
  "expires_at": "2024-01-02T12:00:00.000Z"
}
```

**Response**:
```json
{
  "id": 1,
  "data_hash": "0xa1b2c3d4e5f67890...",
  "agent_validator_id": 456,
  "agent_server_id": 123,
  "data_uri": "https://storage.agent.com/validation-data/abc123.json",
  "validation_data": { ... },
  "created_at": "2024-01-01T12:00:00.000Z",
  "expires_at": "2024-01-02T12:00:00.000Z"
}
```

### Get Validation Responses
Retrieve validation responses, optionally filtered by data hash.

**Endpoint**: `GET /api/v1/validations/responses`

**Query Parameters**:
- `data_hash` (string): Filter by specific data hash

**Example**: `GET /api/v1/validations/responses?data_hash=0xa1b2c3d4...`

**Response**:
```json
[
  {
    "id": 1,
    "data_hash": "0xa1b2c3d4e5f67890...",
    "agent_validator_id": 456,
    "response": 85,
    "evidence": {
      "validation_method": "price_comparison",
      "data_sources": ["coinbase", "binance", "kraken"],
      "confidence": 0.92
    },
    "validator_signature": "0x1a2b3c4d...",
    "created_at": "2024-01-01T12:30:00.000Z",
    "ipfs_hash": "QmValidation123..."
  }
]
```

### Submit Validation Response
Submit a validation response (validators only, requires authentication).

**Endpoint**: `POST /api/v1/validations/responses`

**Headers**:
- `Agent-Address: eip155:167000:0x...`
- `Signature: 0x...`

**Request Body**:
```json
{
  "data_hash": "0xa1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890",
  "response": 85,
  "evidence": {
    "validation_method": "price_comparison",
    "data_sources": ["coinbase", "binance", "kraken"],
    "confidence": 0.92,
    "notes": "Price execution within acceptable tolerance"
  }
}
```

**Response**:
```json
{
  "id": 1,
  "data_hash": "0xa1b2c3d4e5f67890...",
  "agent_validator_id": 456,
  "response": 85,
  "evidence": { ... },
  "validator_signature": "0x1a2b3c4d...",
  "created_at": "2024-01-01T12:30:00.000Z",
  "ipfs_hash": "QmValidation123..."
}
```

---

## ⭐ Reputation System

### Get Reputation Score
Calculate and retrieve reputation score for an agent.

**Endpoint**: `GET /api/v1/reputation/score`

**Query Parameters**:
- `agent_address` (string, required): Agent address in CAIP-10 format

**Example**: `GET /api/v1/reputation/score?agent_address=eip155:167000:0x742d35Cc...`

**Response**:
```json
{
  "agent_address": "eip155:167000:0x742d35Cc6c9C42bC4Cc7C9f9F7e4f8F8F8F8F8F8",
  "reputation_score": 87.5,
  "feedback_count": 145,
  "average_rating": 89.2,
  "calculated_at": "2024-01-01T12:00:00.000Z"
}
```

**Caching**: 30 seconds TTL

**Reputation Calculation**:
- Base score: 50.0 (for agents with no feedback)
- Confidence factor: min(feedback_count / 10, 1.0)
- Final score: average_rating × confidence_factor + 50.0 × (1 - confidence_factor)

---

## 🏥 Health & Monitoring

### Health Check
Kubernetes liveness and readiness probe endpoint.

**Endpoint**: `GET /health`

**Response**:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T12:00:00.000Z",
  "services": {
    "database": "healthy",
    "redis": "healthy",
    "web3": "healthy"
  },
  "version": "1.0.0"
}
```

### Prometheus Metrics
Metrics in Prometheus format for monitoring.

**Endpoint**: `GET /metrics`

**Response**: Prometheus format text
```
# HELP erc8004_requests_total Total number of HTTP requests
# TYPE erc8004_requests_total counter
erc8004_requests_total{method="GET",endpoint="/api/v1/feedback",status_code="200"} 1523

# HELP erc8004_request_duration_seconds HTTP request duration in seconds
# TYPE erc8004_request_duration_seconds histogram
erc8004_request_duration_seconds_bucket{method="GET",endpoint="/api/v1/feedback",le="0.1"} 1200
...
```

### JSON Metrics
Application metrics in JSON format.

**Endpoint**: `GET /metrics/json`

**Response**:
```json
{
  "total_agents": 1250,
  "total_feedback": 15683,
  "total_validation_requests": 892,
  "total_validation_responses": 756,
  "average_reputation": 78.3,
  "uptime_seconds": 259200,
  "timestamp": "2024-01-01T12:00:00.000Z",
  "system": {
    "memory": {
      "used": 536870912,
      "available": 1073741824,
      "total": 2147483648,
      "percent": 25.0
    },
    "cpu_percent": 15.2,
    "disk": {
      "used": 5368709120,
      "free": 10737418240,
      "total": 16106127360,
      "percent": 33.3
    }
  }
}
```

---

## ❌ Error Responses

All errors follow consistent format:

```json
{
  "error": "ValidationError",
  "message": "Invalid agent address format",
  "timestamp": "2024-01-01T12:00:00.000Z",
  "request_id": "req_abc123def456"
}
```

### Common Error Types

| Status Code | Error Type | Description |
|-------------|------------|-------------|
| 400 | ValidationError | Request validation failed |
| 401 | AuthenticationError | Invalid or missing signature |
| 403 | AuthorizationError | Insufficient permissions |
| 404 | NotFound | Resource not found |
| 409 | Conflict | Resource already exists |
| 422 | UnprocessableEntity | Invalid request data |
| 429 | RateLimitExceeded | Rate limit exceeded |
| 500 | InternalServerError | Server error |

### Authentication Errors

```json
{
  "error": "AuthenticationError",
  "message": "Invalid signature",
  "timestamp": "2024-01-01T12:00:00.000Z",
  "request_id": "req_abc123"
}
```

### Validation Errors

```json
{
  "error": "ValidationError",
  "message": "Field validation failed",
  "timestamp": "2024-01-01T12:00:00.000Z",
  "request_id": "req_abc123",
  "details": {
    "field": "agent_address",
    "error": "Must be valid CAIP-10 format"
  }
}
```

---

## 🚦 Rate Limiting

Rate limits are applied per client IP and endpoint.

### Limits
- **Public endpoints**: 100 requests/minute per IP
- **Authenticated endpoints**: 1000 requests/minute per agent address

### Headers
Response headers include rate limit information:
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 995
X-RateLimit-Reset: 1704110400
Retry-After: 60
```

### Rate Limit Exceeded Response
```json
{
  "error": "RateLimitExceeded",
  "message": "Rate limit exceeded",
  "timestamp": "2024-01-01T12:00:00.000Z",
  "request_id": "req_abc123"
}
```

---

## 📊 Response Formats

### Pagination
All list endpoints support pagination:

```json
{
  "items": [...],
  "total": 150,
  "page": 1,
  "page_size": 20,
  "total_pages": 8
}
```

### Timestamps
All timestamps are in ISO 8601 format with UTC timezone:
```
2024-01-01T12:00:00.000Z
```

### IPFS Hashes
Data integrity hashes are generated for all stored records:
```
QmYwAPJzv5CZsnAHb1baHyNNQyrHeKRoMEMBBw1BzSQ6KA
```

---

## 🔄 Versioning

API versioning is handled through URL paths:
- Current version: `/api/v1/`
- Future versions: `/api/v2/`, etc.

Breaking changes will be introduced in new versions while maintaining backward compatibility for existing versions.