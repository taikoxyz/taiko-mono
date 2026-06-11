# preconfirmation-driver

A preconfirmation integration library for Taiko, combining P2P network participation with event-syncer-backed driver integration.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                  Preconfirmation driver runner                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────────┐    ┌───────────────┐  │
│  │  Sidecar     │───>│  P2P Client      │───>│  Event Syncer │  │
│  │  JSON-RPC    │    │  (gossip, sync)  │    │  Driver Client│  │
│  └──────────────┘    └──────────────────┘    └───────────────┘  │
│        ▲                     │                      │           │
│        │                     ▼                      ▼           │
│  External          Commitment/TxList        Execution Engine    │
│  Clients           Validation              (block production)   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Agent Documentation

For preconfirmation, event-sync, and custom-table guardrails used across `taiko-client-rs`, read:

- `docs/agents/whitelist-preconfirmation-invariants.md`
- `docs/agents/event-scan-reorg-and-preconf-flow.md`
- `docs/agents/alethia-reth-custom-tables-and-beacon-sync-gaps.md`
- `docs/agents/reference-map.md`

## Components

### Preconfirmation driver runner (`PreconfirmationDriverRunner`)

The main orchestrator that combines:

- **EventSyncerDriverClient**: Feeds validated preconfirmation payloads into the driver's event syncer
- **PreconfirmationClient**: P2P network operations (gossip, commitment validation, tip catch-up)
- **PreconfRpcServer**: Preconfirmation sidecar JSON-RPC API for external clients

### RPC API

Preconfirmation sidecar JSON-RPC methods:

| Method                       | Description                                           |
| ---------------------------- | ----------------------------------------------------- |
| `preconf_publishBlock`       | Publish a preconfirmation block (commitment + txlist) |
| `preconf_getStatus`          | Get current node status                               |
| `preconf_tip`                | Get preconfirmation tip block number                  |
| `preconf_getPreconfSlotInfo` | Get slot info (signer, window end) for a timestamp    |
