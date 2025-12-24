# Taiko Permissionless Preconfirmations – P2P Specification

This document specifies the Taiko permissionless preconfirmations gossip. It describes topics, message formats, signing and authorization, and the required sidecar behaviors. It is written in an “eth-like” style using normative language.

Status: Draft

Scope: This spec covers preconfirmation metadata and raw transaction list (txlist) distribution over P2P. Live operation gossips SignedCommitments and txlists; catch‑up uses libp2p req/resp for commitments and on‑demand txlist retrieval.

## 1. Terminology

- L1 slot: A consensus-slot on L1. Each L1 slot is subdivided into L2 slots.
- L2 slot: A sub-interval (e.g., 2 seconds) within which a preconfer may publish a preconfirmation.
- Preconfer: The L1 proposer (or fallback) elected for a given L2 slot to provide preconfirmations.
- Preconfirmation (preconf): A commitment to an L2 block’s content (rawTxListHash + anchor block number + block parameters) and anchor reference for that L2 slot.
- EOP: End Of Preconfirmation window marker. An EOP-only preconf signals skipping the window without committing an L2 block.
- URC / Lookahead: The on-chain/off-chain indexable schedule used to elect preconfers per slot.
- Slasher: The address authorized to slash misbehavior for the preconfirmation protocol.

## 2. Topics

Sidecars MUST publish and subscribe to the following live gossip topics:

1. `/taiko/<chainID>/0/preconfirmationCommitments`
    - Payload: raw SSZ-encoded `SignedCommitment` (no snappy compression).
    - Purpose: live, authoritative preconfirmation metadata feed.
2. `/taiko/<chainID>/0/rawTxLists`
    - Payload: `RawTxListGossip` (see §3.4) — includes `rawTxListHash`, and compressed `txlist` bytes.
    - Purpose: live distribution of raw txlists referenced by commitments.

Sidecars SHOULD deprecate the following legacy topics when operating in permissionless mode (MUST NOT publish to them):

- `/taiko/<chainID>/0/preconfBlocks`
- `/taiko/<chainID>/0/responsePreconfBlocks`
- `/taiko/<chainID>/0/requestPreconfBlocks`
- `/taiko/<chainID>/0/requestEndOfSequencingPreconfBlocks`

Note: The `preconfirmationCommitments` topic previously existed for compatibility; in permissionless mode it is the primary live feed of preconfirmation metadata. Deterministic catch‑up of commitments and txlists is provided via req/resp protocols in §11–§12 (not via PubSub request/response topics).

## 3. Message Types and SSZ Encodings

All integers below denoted as `uint256` are serialized as 32-byte little‑endian values (LE32). Hashes are 32‑byte big‑endian as usual. SSZ is used for serialization of the structures in this specification.

### 3.1 Preconfirmation

```
Preconfirmation := container {
  eop: bool,                               # true if this preconf marks EOP
  blockNumber: uint256,                    # L2 block number being preconfirmed
  timestamp: uint256,                      # L2 block timestamp
  gasLimit: uint256,                       # L2 block gas limit
  coinbase: Bytes20,                       # fee recipient for the block
  anchorBlockNumber: uint256,              # L1 block number chosen as the anchor
  rawTxListHash: Bytes32,                  # keccak256(rawTxList(this block))
  parentPreconfirmationHash: Bytes32,      # keccak256(SSZ(Preconfirmation(parent)))
  submissionWindowEnd: uint256,            # unix timestamp of the end of the preconf window of the current preconfer
  proverAuth: Bytes20,                     # prover authorization for the block
  proposalId: uint256                      # proposal identifier for the block
}
```

Notes:

- `eop=true` denotes an EOP-only preconf **iff** no transaction list is provided for the slot (`rawTxListHash == 0x00`).
- `anchorBlockNumber` is the L1 block number (anchor ID) selected for this block’s anchor transaction.
- `parentPreconfirmationHash` links to the parent commitment and is computed as `keccak256(SSZ(Preconfirmation(parent)))` (excluding the parent signature). It is part of the signing preimage for this block.
- The additional block parameters (`timestamp`, `gasLimit`, `coinbase`, `proverAuth`, `proposalId`) are part of the commitment and subject to slashing if contradicted on L1.

### 3.2 PreconfCommitment

```
PreconfCommitment := container {
  preconf: Preconfirmation,
  slasherAddress: Bytes20                # PRECONFER_SLASHER_ADDRESS
}
```

### 3.3 SignedCommitment

```
SignedCommitment := container {
  commitment: PreconfCommitment,
  signature: Bytes65                     # secp256k1 signature over SSZ(commitment)
}
```

Encoding rules:
- `SignedCommitment` is SSZ‑encoded (bool → 1 byte; LE32 encoding for `uint256`; hashes/addresses/signature copied as raw bytes). The signature is NOT part of the signing preimage.
- On the wire, `SignedCommitment` MUST be sent as raw SSZ bytes (no additional compression or envelope).

### 3.4 RawTxList Gossip Message

For live distribution of txlists, sidecars MUST use the following container on `/rawTxLists`:

```
RawTxListGossip := container {
  rawTxListHash:      Bytes32,   # keccak256(compressed RLP(tx list))
  txlist:             bytes      # compressed RLP(tx list); compression per chain config (e.g., zlib)
}
```

Rules:
- Receivers MUST verify `keccak256(txlist) == rawTxListHash` before storing.
- The message does not require a signature; authenticity is derived from the content hash and subsequent commitment verification.
- Implementations SHOULD cap the maximum `txlist` size per chain config.

## 4. Signing and Authorization

### 4.1 Signing

- Domain: The signing domain MUST be a 32‑byte domain separator `DOMAIN_PRECONF` defined by chain configuration. Deployments MAY reuse the block‑payload domain where a separate preconf domain is not defined.
- Preimage: The signature is computed over SSZ‑encoded `PreconfCommitment` (i.e., `commitment`, excluding the `signature` field).
- Curve/Encoding: secp256k1 ECDSA with 65‑byte compact encoding (r||s||v).

### 4.2 Authorization

Upon receiving a `SignedCommitment`, validators MUST:

1. Recover the signer address from `signature` and the signing hash of `commitment`.
2. Determine the elected preconfer for the slot that includes `preconf.submissionWindowEnd` via the URC/lookahead schedule.
3. Verify that the recovered signer equals the elected preconfer’s address for that slot. If not, REJECT.
4. Verify `commitment.slasherAddress == PRECONFER_SLASHER_ADDRESS` (chain parameter). If not, REJECT.

## 5. Validation Rules

Given a `SignedCommitment sc` with `c = sc.commitment` and `p = c.preconf` (validated against the locally indexed lookahead schedule, not via real‑time on‑chain queries):

MUST REJECT if any of the following hold:

- Signature invalid per section 4.1/4.2.
- `c.slasherAddress != PRECONFER_SLASHER_ADDRESS`.
- `p.submissionWindowEnd` does not equal the expected slot end timestamp according to the local schedule.
- Parent consistency fails:
    - `p.parentPreconfirmationHash` does not equal the local canonical head’s `PreconfirmationHash`.
- Block parameter validation fails:
    - `p.blockNumber` does not follow the local canonical head (e.g., not parent.blockNumber + 1).
    - `p.timestamp`, `p.gasLimit`, `p.coinbase`, `p.proverAuth`, or `p.proposalId` violate the chain’s derivation rules (e.g., timestamp drift bounds, gas limit progression, correct coinbase/prover authorization per lookahead/URC configuration).

Missing parents:

- If the referenced parent commitment is not yet known locally (e.g., commitments 101–102 arrive before 100), implementations SHOULD buffer the child as pending and MUST NOT reject or penalize it until the parent is available. Once the parent is known, only reject if the expected parent hash does not match; otherwise continue validation.

EOP-only handling:
- If `p.eop == true` and the local sidecar does not expect a transaction list for this slot (`rawTxListHash == 0x00`), the sidecar MUST treat this as a handoff signal (advance the expected preconfer to the next committer per schedule). Any further non-EOP preconfs by the same committer for the same window SHOULD be considered misbehavior (basis for slashing evidence; outside this P2P scope).

Client execution checks (out of P2P):
- Before executing the L2 block, the client MUST ensure that `keccak256(txlist) == p.rawTxListHash`.

## 6. Sidecar Behavior

### 6.1 Publishing

The elected preconfer for each L2 slot SHOULD:
- Publish the `RawTxListGossip` on `/taiko/<chainID>/0/rawTxLists` (for non‑EOP slots), and
- Publish the `SignedCommitment` on `/taiko/<chainID>/0/preconfirmationCommitments` before `submissionWindowEnd`.

For EOP‑only slots, the preconfer MUST publish only the `SignedCommitment` with `eop=true` (no txlist).

Ordering: Sidecars MAY publish the txlist first (or concurrently) and the commitment immediately after. Receivers cache by `rawTxListHash` and link when the commitment arrives.

### 6.2 Reception

Upon receiving a `SignedCommitment`:

1. Validate per section 5.
    - If the local lookahead schedule for `p.submissionWindowEnd` is not yet available (e.g., still syncing the lookahead), implementations MAY buffer the commitment as “pending schedule”; during this phase they SHOULD only enforce hash‑chain linkage via `parentPreconfirmationHash` and defer all other validation until the schedule is known (or drop per local policy). No on‑chain lookups are required in
    the hot path.
2. If valid and `eop=false`, the client SHOULD look up the txlist by `p.rawTxListHash` in its local cache (populated by `/rawTxLists`) or via §12, verify the hash, reconstruct the L2 block (anchorTx from `p.anchorBlockNumber` + txlist) using the committed block parameters (`timestamp`, `gasLimit`, `coinbase`, `proverAuth`, `proposalId`), execute, and advance local L2 head.
3. If valid and `eop=true` and:
    1.  **`rawTxListHash != 0x0`, d**o the same execution flow as in step (2), **and then** update local schedule state to reflect handoff to the next committer.

    2. **`rawTxListHash == 0x00`**, no execution is required. Update local schedule state to reflect handoff to the next committer for subsequent slots.


Startup and catch‑up:
- After beacon‑syncing the L2 execution engine to the latest on‑chain tip, sidecars SHOULD synchronize missing preconfirmation metadata via the req/resp commitment sync (§11), then subscribe for live updates on `/preconfirmationCommitments`.
- If the sidecar lacks required txlists for validated commitments (e.g., due to downtime and no local cache), it SHOULD fetch the missing txlists by hash using the req/resp rawTxList retrieval (§12) or an equivalent non‑P2P path.

### 6.3 Reorgs

On L1 reorgs affecting any `anchorBlockNumber` in the executed range, implementations SHOULD re-fetch the anchor hash for the affected anchors, reconstruct anchor transactions, and re-execute the impacted L2 blocks to restore canonical consistency.

## 7. Gossip and DoS Considerations

- Message formats: raw SSZ `SignedCommitment` (commitments) and `RawTxListGossip` (txlists).
- Message identification: Implementations SHOULD select a stable message ID function (e.g., hash of topic + payload) suitable for deduplication.
- Rate limiting: Implementations SHOULD enforce per‑peer rate limiting and short duplicate windows to limit spam.
- Deduplication: Implementations SHOULD deduplicate commitments per `(slot, signer)` and per `(blockNumber, rawTxListHash)`; txlists per `rawTxListHash`.
- Size caps: Implementations MUST enforce a maximum txlist size and discard oversized `RawTxListGossip` messages.
- Self‑messages: Implementations MUST ignore messages originating from the local sidecar.
- Peer scoring: Implementations MUST integrate gossipsub peer scoring feedback to penalize peers whose messages fail validation (e.g., wrong signer for the slot), to reduce repeated spam from misbehaving peers.

### 7.1 Gossipsub Scoring Profile

The following scoring profile is normative for all preconfirmation topics unless overridden by network configuration:

- Enable gossipsub v1.1 scoring with application feedback.
- App feedback MUST apply a negative delta on validation failure (bad signature, wrong slot signer, hash mismatch, oversized txlist) and a small positive delta on acceptance/forward; defaults: ‑1 per failure (cap ‑4 per 10s per peer), +0.05 per acceptance (with a cap).
- Parameters (defaults to be exposed/configurable but supported):
    - decay: ~0.9 per 10s tick; `appScore` clamp: [‑10, +10]; `topicWeight` : 1.0.
    - `invalidMessageDeliveriesWeight`: 2.0 (dominant); `invalidMessageDeliveriesDecay`: 0.99; cap at ‑20 (networks MAY remove the cap entirely to accelerate eviction).
    - `firstMessageDeliveriesWeight`: 0.5; `firstMessageDeliveriesDecay`: 0.999; cap at 20.
    - `timeInMeshQuantum`: 1s; `timeInMeshCap`: 3600s.
- Enforcement MUST drop peers below score ‑1, prune below ‑2, and ban (disconnect + ignore) below ‑5 sustained >30s (or stricter).
- Implementations MUST NOT penalize buffered commitments awaiting lookahead availability; only score once validation can definitively succeed/fail.

## 8. Parameters and Constants

- `PRECONFER_SLASHER_ADDRESS`: chain parameter; the address authorized for slashing.
- `DOMAIN_PRECONF`: 32‑byte signing domain value for preconfirmation commitments. Deployments MAY reuse the block‑payload domain if a separate value is not defined.
- Slot timing and `submissionWindowEnd` derivation MUST match the chain’s URC/lookahead schedule and configuration (e.g., L2 slot length and L1 slot boundaries).

## 9. Backward Compatibility

- Permissionless mode MUST NOT publish to legacy preconf block topics. Sidecars MAY continue to subscribe during migration but SHOULD treat them as deprecated.
- The `preconfirmationCommitments` topic is the primary and sufficient channel for permissionless preconf metadata.

## 10. Req/Resp Preconfirmation Sync

This section defines a libp2p stream‑based request/response commitment catch‑up mechanism for sidecars that start or rejoin the network after missing preconfirmation gossip. It transfers only preconfirmation metadata (SignedCommitment), not txlists.

### 10.1 Protocol IDs

All requests are libp2p stream-based req/resp methods (eth-like). Suggested protocol ID namespace:

- `/taiko/<chainID>/preconf/1/get_head`
- `/taiko/<chainID>/preconf/1/get_commitments_by_number`

### 10.2 Messages (SSZ)

GetHead (no request body):

```
PreconfHead := container {
  blockNumber:      uint256,
  submissionWindowEnd: uint256,
}
```

GetCommitmentsByNumber (request):

```
GetCommitmentsByNumberRequest := container {
  startBlockNumber: uint256,   # inclusive
  maxCount:        uint32      # DoS‑bounded, e.g., ≤ 256
}
```

GetCommitmentsByNumber (response):

```
GetCommitmentsByNumberResponse := container {
  commitments: List[SignedCommitment],  # bounded by MAX_COMMITMENTS_PER_RESPONSE
}
```

Constraints:
- Responders MUST cap `maxCount` and the total response bytes.
- Receivers MUST validate each `SignedCommitment` per §5.

### 10.2.1 Transport Framing and Encoding

- Each request and response is a single SSZ container, sent as one length‑delimited frame on the libp2p stream. A varint length prefix (per libp2p) MUST bound the frame size.
- Default encoding is raw SSZ. Networks MAY negotiate SSZ+compression (e.g., ssz_snappy) as an extension; if enabled, both request and response MUST use the same encoding.
- Chunking: Responses SHOULD fit within a single frame under the configured `MAX_COMMITMENTS_PER_RESPONSE` and byte caps. If chunking is implemented, each chunk MUST be a valid `GetCommitmentsByNumberResponse` with a non‑overlapping subrange.

### 10.3 Behavior

Requester (catch‑up):
- After beacon‑sync, call `get_head` to discover peer preconf head P.
- If `P > local_onchain_tip`, page `get_commitments_by_number{ start = local_onchain_tip+1, maxCount = CAP }` until caught up.
- For each commitment, validate (§5); for any missing txlist, retrieve by hash via §11; then reconstruct and execute.

Responder:
- Rate‑limit per peer; deduplicate repeated requests; respond with ordered commitments up to limits.

### 10.4 DoS and Limits

- Apply per‑peer rate limits and response byte caps.
- Ignore stale/malformed ranges.

## 11. Req/Resp RawTxList Retrieval

This section defines a libp2p stream‑based request/response txlist catch‑up mechanism for sidecars that missed raw txlists while offline. It retrieves only txlists by their content hash. Live operation SHOULD rely on the preconfer’s publication of txlists; this mechanism is for backfill.

### 11.1 Protocol ID

- `/taiko/<chainID>/preconf/1/get_raw_txlist`

### 11.2 Messages

GetRawTxList (request):

```
GetRawTxListRequest := container {
  rawTxListHash: Bytes32
}
```

GetRawTxList (response):

```
GetRawTxListResponse := container {
  rawTxListHash:      Bytes32,   # echo of request key
  txlist:             bytes      # compressed RLP(tx list); compression per chain config (e.g., zlib)
}
```

Constraints:
- Responders MUST ensure `keccak256(txlist) == rawTxListHash` before serving.
- Responders SHOULD cap the maximum response size per chain config (e.g., `BlockMaxTxListBytes`).

### 11.2.1 Transport Framing and Encoding

- Each request and response is a single SSZ container (request) or length‑delimited binary (response) on the libp2p stream.
- The `txlist` field carries compressed RLP bytes; compression algorithm is defined by chain configuration (e.g., zlib). The outer message is not additionally compressed unless peers negotiate a compression extension (e.g., ssz_snappy for the container sans `txlist`).
- A varint length prefix (per libp2p) MUST bound each frame.

### 11.3 Behavior

Requester:
- For each validated commitment lacking a local txlist, call `get_raw_txlist{ rawTxListHash }`.
- Verify `keccak256(txlist) == rawTxListHash`, store by hash, reconstruct and execute using `anchorBlockNumber` from the related commitment.

Responder:
- Serve available txlists keyed by hash; rate‑limit and deduplicate per peer/hash.

### 11.4 DoS and Limits

- Apply per‑peer rate limits and response byte caps.
- Reject malformed/oversized responses.
