# preconfirmation-driver

A preconfirmation integration library for Taiko, combining P2P network participation with embedded driver communication via channels.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   Preconfirmation driver node                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────────┐    ┌───────────────┐  │
│  │  Sidecar     │───>│  P2P Client      │───>│  Embedded     │  │
│  │  JSON-RPC    │    │  (gossip, sync)  │    │  Driver       │  │
│  └──────────────┘    └──────────────────┘    └───────────────┘  │
│        ▲                     │                      │           │
│        │                     ▼                      ▼           │
│  External          Commitment/TxList        Execution Engine    │
│  Clients           Validation              (block production)   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### Preconfirmation driver node (`PreconfirmationDriverNode`)

The main orchestrator that combines:

- **EmbeddedDriverClient**: Channel-based communication with the driver (no serialization overhead)
- **PreconfirmationClient**: P2P network operations (gossip, commitment validation, tip catch-up)
- **PreconfRpcServer**: Preconfirmation sidecar JSON-RPC API for external clients

### RPC API

Preconfirmation sidecar JSON-RPC methods:

| Method                        | Description                                      |
| ----------------------------- | ------------------------------------------------ |
| `preconf_publishCommitment`   | Publish a signed preconfirmation commitment      |
| `preconf_publishTxList`       | Publish an encoded transaction list (RLP + zlib) |
| `preconf_getStatus`           | Get current node status                          |
| `preconf_tip`                 | Get preconfirmation tip block number             |
| `preconf_canonicalProposalId` | Get last canonical proposal ID                   |
