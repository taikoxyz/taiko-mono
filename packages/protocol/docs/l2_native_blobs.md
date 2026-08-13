# L2-Native Ephemeral Blobs

This document specifies **ephemeral native blob support** for Taiko Alethia: accepting EIP-4844 type-3 (blob-carrying) transactions on the L2 itself, with blob bodies retained and served by Taiko's node network for a bounded window and **never posted to L1**.

- **Status**: Draft for review
- **Target**: the next hard fork after Unzen (placeholder `V7` throughout; fork gate `IsV7(timestamp)`)
- **Depends on**: Unzen (Cancun+Prague+Osaka EVM on L2, zk-gas metering), Shasta derivation
- **Related**: [#19832 — Explore L2 blob support](https://github.com/taikoxyz/taiko-mono/issues/19832), [Derivation.md](./Derivation.md), [zk_gas_spec.md](./zk_gas_spec.md)

The key words MUST, MUST NOT, SHOULD, and MAY are to be interpreted as described in RFC 2119.

---

## 1. Motivation

Ethereum's blob support decomposes into (a) a small EVM surface, (b) a mechanical fee market, and (c) a large availability apparatus that lives in the consensus layer. Unzen already shipped (a) on Taiko L2 — `BLOBHASH`, `BLOBBASEFEE`, and the KZG point-evaluation precompile are live, zk-gas-metered features, and L2 headers carry `blobGasUsed`/`excessBlobGas` (pinned to zero). Type-3 transactions are excluded at exactly one point: the block sealer skips them.

Enabling them natively gives Taiko:

- **Price-independent data availability**: a fee lane whose floor and ceiling Taiko controls, insulated from L1 blob-fee spikes.
- **Preconfirmation-speed availability**: blob data usable by consumers in ~2s, vs 12s L1 slots plus batch cadence.
- **A DA product for L3s and data-heavy applications** (rollups settling on Taiko, coprocessor inputs, orderbook/game state, preconfirmation metadata) inside Taiko's own trust envelope — today such users must pay L2 execution gas for calldata (which then also lands in Taiko's L1 blobs) or leave the trust zone for an external DA committee.
- **Completed Osaka equivalence**: post-Unzen, the blob transaction is the single Osaka feature Taiko rejects. No production L2 accepts type-3 transactions today; Taiko would be the first.

### Non-goals

- **No L1-grade availability claim for blob bodies.** Bodies are guaranteed by Taiko's bonded operator set and retention policy (§7), not by Ethereum consensus. This is explicitly a different, documented guarantee tier.
- **No re-posting of bodies to L1** (the "design A" alternative, §14). Re-posted blobs cost L1 blob gas again and, at full rate, would consume a large share of total L1 blobspace.
- **No change to the rollup's security model.** State derivation from L1 remains complete and deterministic without any blob body (§2).

## 2. Core invariant

> **Execution state never depends on blob bodies — only on `blobVersionedHashes` carried inside transaction envelopes.**

This is EIP-4844's own design and it transfers verbatim to L2:

1. A type-3 transaction's canonical RLP encoding (the form that enters txlists and therefore L1 blobs via the proposal manifest) contains the versioned hashes but **no sidecar**. Today's manifest encoding of a type-3 transaction is already correct.
2. The state transition function reads only the hashes (`BLOBHASH`, intrinsic blob-gas accounting). Two nodes with the same txlist compute identical state whether or not either ever saw a blob body.
3. Therefore **L2 block derivation and proving MUST NOT depend on blob-body availability**. A lost body strands the application that paid for it; it cannot fork the chain, halt derivation, or make a proposal unprovable.

Consequence: unlike L1 — where `is_data_available()` gates block import in fork choice — availability on Taiko is enforced *before* inclusion (preconfirmation policy, §6) and *after* inclusion by operator obligation (§7), never by the derivation pipeline.

## 3. Constants

| Name | Value | Notes |
| --- | --- | --- |
| `BLOB_BYTES` | `131_072` | 4096 field elements × 32 bytes, unchanged from EIP-4844 |
| `GAS_PER_BLOB` | `131_072` | unchanged from EIP-4844 |
| `TARGET_BLOBS_PER_BLOCK` | `1` | launch value; tunable per fork (§13) |
| `MAX_BLOBS_PER_BLOCK` | `3` | launch value; tunable per fork |
| `MAX_BLOBS_PER_TX` | `3` | equals `MAX_BLOBS_PER_BLOCK` |
| `TARGET_BLOB_GAS_PER_BLOCK` | `131_072` | `TARGET_BLOBS_PER_BLOCK × GAS_PER_BLOB` |
| `MAX_BLOB_GAS_PER_BLOCK` | `393_216` | `MAX_BLOBS_PER_BLOCK × GAS_PER_BLOB` |
| `MIN_BLOB_BASE_FEE` | `1` wei | absolute floor |
| `BLOB_BASE_FEE_UPDATE_FRACTION` | `2_225_331` | ≈ +12.5% per full block at sustained max, mirroring L1's per-block max growth rate (§5) |
| `BLOB_BASE_COST` | `8_192` | EIP-7918-style reserve-floor coupling to the execution base fee (§5) |
| **`BLOB_RETENTION_SECONDS_MIN`** | **`6_291_456`** | **≈ 72.8 days = 4 × Ethereum's `MIN_EPOCHS_FOR_BLOB_SIDECARS_REQUESTS` (4096 epochs × 384 s). Design requirement: at least 4× L1's retention window.** |
| `BLOB_RETENTION_SECONDS_DEFAULT` | `7_776_000` | 90 days; default node configuration, MUST be ≥ `BLOB_RETENTION_SECONDS_MIN` for serving nodes |
| `MAX_BLOB_TXS_PER_ACCOUNT_POOL` | `16` | blobpool per-account cap (upstream geth default) |

Versioned-hash version byte remains `0x01` (`0x01 ‖ sha256(kzg_commitment)[1:]`); KZG parameters (BLS12-381, the EF ceremony trusted setup) are unchanged from L1. Sidecars use the **pre-Fusaka single-proof format** (`blob ‖ commitment ‖ proof`) at launch — cell proofs exist to enable sampling, which is a later phase (§7.3); the wrapper format version byte in `eth_sendRawTransaction` follows whichever format the execution client's pool accepts, and clients MUST accept the single-proof form.

## 4. Consensus rules (provable, fork-gated on `IsV7`)

### 4.1 Transaction validity

A type-3 transaction is valid in a V7+ block iff it satisfies Osaka rules verbatim:

1. `to != nil`; `len(blobVersionedHashes) ∈ [1, MAX_BLOBS_PER_TX]`; every hash has version byte `0x01`.
2. `maxFeePerBlobGas ≥ block.blobBaseFee` and the sender can cover `blobGasUsed × maxFeePerBlobGas` in the balance check, alongside execution gas.
3. Blob gas used by the block ≤ `MAX_BLOB_GAS_PER_BLOCK`.
4. The **anchor transaction is never type-3** (unchanged anchor validation).
5. Type-3 transactions in blocks with `timestamp < V7_TIME` remain invalid (current behavior).

### 4.2 Header validity

For V7+ blocks, `blobGasUsed` and `excessBlobGas` MUST be computed per EIP-4844 with the §3 schedule:

```
header.blobGasUsed  = sum(len(tx.blobVersionedHashes) × GAS_PER_BLOB for tx in block)
header.excessBlobGas = calc_excess_blob_gas(parent, ...)   # EIP-4844 + §5 reserve floor
```

The driver's current "must be zero" assertions (`packages/taiko-client/driver/chain_syncer/event/blocks_inserter/common.go:400-407`) become "must match the computed values" at the fork gate. `parentBeaconBlockRoot` remains pinned to the zero hash (there is no beacon chain on L2); `requestsHash` remains the empty-requests hash.

### 4.3 Derivation rules

1. Block import and derivation from L1 MUST NOT require blob bodies (§2). There is **no availability precondition** anywhere in the derivation pipeline.
2. The manifest `SignedTransaction` schema ([Derivation.md](./Derivation.md)) is extended with the type-3 fields `maxFeePerBlobGas` and `blobVersionedHashes` (canonical RLP envelope — no sidecar). Txlist byte accounting (`maxBytesPerTxList`) is unchanged: bodies never count, so a blob transaction costs L1 DA only its ~small envelope.
3. **Forced-inclusion sources MUST NOT contain type-3 transactions at launch.** A forced-inclusion manifest containing one is treated like any other invalid source content (replaced by the default source manifest, per Derivation.md's per-source isolation). Rationale: forced inclusion exists for censorship resistance, which for blob bodies would require L1-posted data (design A); guaranteeing it is deferred (§15). This restriction MUST be documented prominently to users: if all preconfers censor blob transactions, there is no forced path for them.
4. Blocks derived without preconfirmation (L1-only sync) execute type-3 transactions normally using the envelope hashes; the local sidecar store records a gap for later backfill (§7.2).

### 4.4 zk-gas

No new zk-gas dimension is required: bodies are never proven, `blobhash`/`blobbasefee` already carry Unzen multipliers (13/15), and the point-evaluation precompile is priced at 859 ([zk_gas_spec.md](./zk_gas_spec.md)). Type-3 envelope processing (hash-array handling, blob-gas accounting) is covered by standard per-transaction intrinsic zk-gas; the V7 zk-gas schedule revision SHOULD confirm parity against the reference REVM table for Osaka's blob-gas checks.

## 5. Blob fee market

A second EIP-1559-style lane, exactly as on L1, with Taiko-chosen parameters:

```
blob_base_fee = fake_exponential(MIN_BLOB_BASE_FEE, excess_blob_gas, BLOB_BASE_FEE_UPDATE_FRACTION)
```

- `excess_blob_gas` accumulates `parent.excessBlobGas + parent.blobGasUsed − TARGET_BLOB_GAS_PER_BLOCK`, floored at 0.
- **Reserve floor (EIP-7918-style)**: when `BLOB_BASE_COST × block.baseFee > GAS_PER_BLOB × blob_base_fee` (i.e. blob base fee < execution base fee / 16), the excess update switches to `+ blobGasUsed × (MAX − TARGET) / MAX`, so the blob fee cannot decay to economic irrelevance relative to execution gas. With Taiko's small execution base fee this floor is intentionally low — the product is *cheap*; spam protection comes from the exponential lane and the per-block cap (§12.2), not the floor.
- `BLOB_BASE_FEE_UPDATE_FRACTION = 2_225_331` gives ≈ ×1.125 per fully-utilized block — the same per-block max growth as L1. Taiko blocks are ~6× more frequent than L1 slots, so in wall-clock the market reacts ~6× faster; this is deliberate (faster spam shutdown, §12.2).
- **Fee routing**: blob fees follow the same `basefeeSharingPctg` split as the execution base fee (share to coinbase, remainder per protocol treasury rules). The coinbase share compensates the proposer/preconfer for the storage-and-serving obligation it takes on (§7.1).

`BLOBBASEFEE` returns the real lane price from the fork onward (it currently returns 1 wei, `excessBlobGas = 0`).

## 6. Data flow

```mermaid
sequenceDiagram
    participant U as User / L3 batcher
    participant EL as taiko-geth / taiko-reth (blobpool)
    participant P as Preconfer (driver + sealer)
    participant N as Taiko nodes (preconf P2P)
    participant S as Sidecar store (per node)
    participant L1 as L1 Shasta inbox

    U->>EL: eth_sendRawTransaction (wrapped: tx + blobs + commitments + proofs)
    EL->>EL: pool validation (hash↔commitment↔proof)
    P->>EL: txPoolContentWithMinTip
    P->>EL: engine_getBlobsV2(versionedHashes)
    EL-->>P: sidecars for included type-3 txs
    P->>N: preconf envelope = payload + blobSidecars[]
    N->>N: validate count/order + recompute hash per sidecar
    N->>S: persist sidecars (retention ≥ 72.8d)
    P->>L1: propose(manifest)  — envelopes only, hashes inside, no bodies
    Note over L1: L1 sees 32-byte hashes; bodies never leave the Taiko network
    U->>S: GET /blobs/{versionedHash} (any serving node, until pruned)
```

Steps in prose:

1. **Submission.** Users submit wrapped blob transactions to any Taiko RPC. The execution client's blobpool validates commitments/proofs against versioned hashes and holds the sidecars (upstream geth/reth machinery, already present).
2. **Selection.** The sealer includes type-3 envelopes like any transaction (removing the current skip at `taiko-geth/miner/taiko_worker.go:277-281`), subject to §4 limits. After building a payload, the driver pulls sidecars for the included hashes from the local pool via `engine_getBlobsV2` (already implemented upstream in taiko-geth).
3. **Preconf propagation.** The preconfirmation envelope gains a `blobSidecars` field. Receiving nodes MUST verify, for each type-3 transaction, that sidecars are present, ordered, and that `versioned_hash(commitment) == tx.blobVersionedHashes[i]` — the exact check the driver already runs against L1 blob servers (`packages/taiko-client/pkg/rpc/blob_datasource.go:210-218`). An envelope failing this MUST NOT be propagated or imported as a preconfirmed block. This extends `ValidateExecutionPayload` (`packages/taiko-client/driver/preconf_blocks/server.go:923-962`) and the Rust ingress validation.
4. **Persistence & serving.** Nodes persist validated sidecars to a local store and serve them (§7.2) for at least the retention window, then prune.
5. **L1 proposal.** Unchanged. The manifest carries canonical envelopes; **no inbox, wrapper, or forced-inclusion contract changes are required**.

Worst-case added preconf bandwidth: `MAX_BLOBS_PER_BLOCK × BLOB_BYTES = 384 KiB` per ~2s block ≈ 1.6 Mbit/s — negligible for operator-grade preconfers.

## 7. Availability guarantee and retention

### 7.1 Guarantee tier at launch: bonded-operator custody

The availability guarantee is: **a preconfer MUST NOT include a type-3 transaction whose sidecars it does not possess, and MUST retain and serve every sidecar it includes for at least `BLOB_RETENTION_SECONDS_MIN`.** Because preconf P2P validation (§6.3) refuses envelopes without sidecars, every honest node that preconf-imported the block also holds the bodies — custody is the natural by-product of validation.

Today's preconfer set (Nethermind, Chainbound, Gattaca — whitelisted on-chain and bonded) is the guarantee's anchor: withholding or refusal to serve within the window is attributable operator misbehavior, subject to the same governance/ejection/slashing framework as other preconfirmation faults. This is deliberately a **committee-grade DA guarantee** — the same trust class as Arbitrum AnyTrust, and stronger than several shipping alternatives (Base Appchains commit batch data to S3). It MUST be documented as such; it is not L1 consensus DA.

Data withholding is not generally attributable on-chain (a node claiming "I asked and got nothing" cannot prove the negative). Launch accepts governance-grade evidence (signed requests, monitoring probes by other operators); a protocol-native challenge is out of scope (§15).

### 7.2 Retention and serving

- **Requirement (this design's headline parameter): the network MUST retain and serve blob bodies for at least `BLOB_RETENTION_SECONDS_MIN = 6_291_456 s ≈ 72.8 days — 4× Ethereum's 18.2-day sidecar window.`** Taiko out-retains L1 by design; retention length is a product feature.
- Node roles:
  - **Serving nodes** (preconfers MUST; public RPC providers SHOULD): retain ≥ the minimum window (default config 90 days) and expose the serving API.
  - **Other full nodes MAY prune at any time** — bodies are never needed for derivation (§2). Retention is a service role, not a validity requirement.
- **Serving API** (mirrors the interface the driver already consumes from L1 blob servers, so client code is reused):
  - `GET /blobs/{versionedHash}` → `{ blob, kzg_commitment, kzg_proof }` (existing blob-server shape, `packages/taiko-client/pkg/rpc/blob_datasource.go:243`)
  - `GET /taiko/v1/blob_sidecars/{l2BlockNumber}` → all sidecars for a block (bulk sync/backfill)
- **Backfill.** A node that imported blocks from L1 derivation without bodies (preconf outage, fresh sync inside the window) SHOULD backfill its store from serving peers via the bulk endpoint. Gaps beyond the window are expected and harmless.
- **Archival.** The existing blob-indexer service (built for Fusaka L1 cell-proof serving, #20446) is extended to archive L2 blobs beyond the window; third-party archival (Blobscan-style indexers, EthStorage) is complementary and permissionless — anyone can archive, since bodies are public and hash-committed.

### 7.3 Upgrade path: custody-and-sampling

When the operator set decentralizes and demand justifies it, the guarantee can graduate to PeerDAS-style sampling: erasure-extend blobs, distribute column sidecars with cell proofs across node custody groups, and replace full-download validation with sampling. The cell/column machinery is battle-tested upstream since Fusaka. This phase changes §6.3's wrapper to the cell-proof format and is out of scope for V7.

## 8. Execution-client changes

| Area | Change | Where |
| --- | --- | --- |
| Sealer | Remove the type-3 skip, gated on `IsV7`; enforce §4 caps during selection; blob txs count blob gas, not txlist bytes | `taiko-geth/miner/taiko_worker.go:277-281`, `commitL2Transactions` |
| Pool (pre-V7 hygiene) | **Immediately** (independent of this design): reject type-3 at the pool while `!IsV7`. Post-Unzen the blobpool is Cancun-active and `Pending()` is called without `OnlyPlainTxs` (`taiko_worker.go:74-79, 377`), so a blob tx can today enter a proposed txlist only to be dropped by every sealer — the proposer pays L1 DA for dead bytes | `taiko-geth/core/txpool/validation.go` (taiko gate) |
| Pool (V7) | Enable blobpool acceptance; per-account cap `MAX_BLOB_TXS_PER_ACCOUNT_POOL`; accept single-proof wrapper | upstream blobpool, config |
| Fee market | Activate the §3/§5 schedule via `TaikoChainConfig.BlobScheduleConfig` (the field already exists, currently carrying inert L1 defaults — replace with Taiko entries keyed to V7) | `taiko-geth/params/taiko_config.go:81-87` |
| Headers | Real `blobGasUsed`/`excessBlobGas` computation post-fork | upstream + fork gate |
| APIs | `txPoolContentWithMinTip` unchanged (envelopes only); `engine_getBlobsV2` already present and becomes the sidecar hand-off to the driver | `taiko-geth/eth/catalyst` |
| Nethermind (devnet) | Flip `"BlobsSupport": "Disabled"` → enabled at V7; add Taiko blob schedule to chainspec | `packages/taiko-client/internal/docker/nodes/nmc/taiko-devnet.cfg:9-11`, chainspec template |

The taiko-reth migration (in progress) inherits all of the above from upstream reth's complete 4844 implementation; reth is the natural vehicle for this fork.

## 9. Client (driver / proposer / preconf) changes

| Area | Change | Where |
| --- | --- | --- |
| Preconf envelope | Add `blobSidecars` (Go + Rust codecs); validation per §6.3 | `packages/taiko-client/driver/preconf_blocks/server.go:923-962`; `packages/taiko-client-rs/crates/whitelist-preconfirmation-driver/src/importer/{ingress,validation}.rs`, `codec.rs` |
| Import | Relax the `== 0` pins on blob header fields at the fork gate; verify against computed values | `packages/taiko-client/driver/chain_syncer/event/blocks_inserter/common.go:378-407` |
| Sidecar store | New component: persist / prune / serve / backfill per §7.2; reuses the KZG re-derivation code | new; validation code from `packages/taiko-client/pkg/rpc/blob_datasource.go:173-218` |
| Proposer | No structural change (canonical RLP already excludes sidecars). Manifest schema/docs gain the two type-3 fields (§4.3.2) | `packages/taiko-client/bindings/manifest/manifest.go`; Derivation.md |
| Prover (raiko) | No body proving. STF gains Osaka blob-gas validity rules — inherited from revm/reth. zk-gas already priced (§4.4) | raiko STF config |
| L1 contracts | **None required.** Optional later: availability-attestation/bond registry (§15) | — |

## 10. Wallets, tooling, RPC

- viem/ethers/alloy already construct and send type-3 transactions; pointing them at a Taiko RPC works once the pool accepts them. Docs + examples needed (blob fee estimation via `eth_blobBaseFee`, which activates with the lane).
- Explorer support: a Blobscan-style view over the sidecar stores (the blob-indexer already speaks the format).
- `eth_getBlockByNumber` etc. expose `blobGasUsed`/`excessBlobGas` per upstream behavior; receipts expose `blobGasPrice`/`blobGasUsed` for type-3 txs.

## 11. Semantics vs L1 (documentation requirement)

This table MUST appear in user-facing docs:

| Property | Ethereum L1 | Taiko L2 (this design) |
| --- | --- | --- |
| Tx type, hashes, opcodes, precompile | EIP-4844 / Osaka | identical |
| Fee lane | excess-blob-gas market, 7918 floor | identical mechanism, Taiko schedule (§3) |
| Who guarantees bodies | consensus: block import gated on availability (PeerDAS sampling) | bonded preconfer set + serving policy; import never gated |
| Retention | 4096 epochs ≈ 18.2 days | **≥ 72.8 days (4×), default 90 days** |
| Forced inclusion of blob txs | n/a (L1 is the base layer) | **not supported at launch** (§4.3.3) |
| Body loss consequence | impossible for canonical blocks | possible if all obligated operators fail; chain unaffected, buyer refunded nothing |

## 12. Security considerations

### 12.1 Withholding grief

A malicious preconfer could include a type-3 tx and withhold the body. Bounded impact: the chain is unaffected (§2); the buyer paid blob fees for nothing. Mitigations: preconf P2P refuses sidecar-less envelopes (so withholding requires the preconfer to also fork its preconf announcements — detectable by other operators); monitoring probes against the serving API; governance ejection/slashing. Residual risk equals the committee honesty assumption and is documented (§11).

### 12.2 Storage/bandwidth DoS

- Hard ingest ceiling: `MAX_BLOBS_PER_BLOCK × BLOB_BYTES / 2 s = 192 KiB/s ≈ 16.6 GB/day`, i.e. ≤ ~1.21 TB over the minimum window — the mathematical bound, not the expected state.
- Sustained-max is self-extinguishing: each fully-utilized block adds `(MAX−TARGET) × GAS_PER_BLOB = 262_144` to `excess_blob_gas`, multiplying the price by ≈ 1.125; ~195 consecutive full blocks (≈ 6.5 minutes) multiply it by 10¹⁰. The exponential lane, not the floor, is the anti-spam mechanism — same as L1, reacting ~6× faster in wall-clock.
- Steady state at 100% of target: `TARGET_BLOBS_PER_BLOCK × BLOB_BYTES / 2 s = 64 KiB/s ≈ 5.5 GB/day` → ≈ 403 GB per 72.8-day window (≈ 497 GB at the 90-day default). Serving nodes SHOULD provision ≥ 1 TB for the blob store; non-serving nodes carry nothing.
- Per-account pool caps and the standard blobpool eviction rules bound mempool exposure.

### 12.3 Interaction with zk-gas block truncation

Unzen's zk-gas meter can truncate a block mid-list. Truncation semantics for type-3 txs are identical to any tx: an excluded tx contributes no blob gas and its sidecars are not gossiped for that block. `excessBlobGas` accounting uses post-truncation `blobGasUsed` only.

### 12.4 Censorship

With no forced-inclusion path for type-3 (§4.3.3), a censoring preconfer set can exclude blob txs entirely. Users retain the trivial fallback that exists today: posting data as calldata (censorship-resistant via forced inclusion, at calldata prices). Accepting this asymmetry at launch is a documented trade-off; §15 sketches the design-A hybrid that would close it.

### 12.5 Equivalence drift

This design intentionally makes Taiko a superset of Osaka behavior gated on a Taiko fork, with one semantic difference (availability tier) that cannot be observed by the EVM. Contracts written against L1 blob semantics (e.g. proof-of-equivalence verifiers using `0x0A`) behave identically.

## 13. Rollout

| Phase | Content | Gate |
| --- | --- | --- |
| 0 (now) | Hygiene: pool-reject type-3 pre-V7 (§8 row 2); update stale docs (docs.taiko.xyz FAQ still describes a Shanghai EVM); reopen #19832 referencing this spec | — |
| 1 | Spec review (this document), parameter sign-off (`TARGET/MAX`, retention default, update fraction) | protocol + client teams |
| 2 | Devnet: taiko-reth + Rust driver implementation; `--taiko.devnet-v7-time 0`; Nethermind chainspec flip; bandwidth/storage soak at max utilization | internal devnet |
| 3 | Hoodi testnet fork; explorer + blob-indexer integration; L3 pilot (an OP-stack or Taiko-stack L3 posting via L2 blobs) | Hoodi |
| 4 | Mainnet V7 activation; preconfer serving obligations added to operator agreements | governance |
| 5+ | Sampling upgrade (§7.3); forced-inclusion hybrid (§15); RIP submission for cross-rollup standardization of L2 blob semantics | later forks |

## 14. Alternatives considered

- **A — re-posted blobs (L1-inherited availability).** Bodies appended to the proposal's L1 blobs; prover adds a KZG proof-of-equivalence per blob linking the re-posted body to the L2 versioned hash. Full L1 security, but users pay L1 blob gas again (never cheaper than using L1 directly), and at scale it consumes L1 blobspace — the objection that helped close the one prior attempt at L2 blob support (op-specs PR #383). Kept as a possible paid add-on for L3s that require L1-grade DA; composable with this design per-transaction later.
- **C — external DA (Celestia/EigenDA/EthStorage pointer).** Imports a third-party trust zone and token; not "native". EthStorage remains interesting as post-window archival (§7.2).
- **Do nothing.** L3s and data-heavy apps on Taiko keep paying L2 execution gas for calldata that also lands in L1 blobs, or leave the trust envelope; Taiko's Osaka equivalence stays incomplete at exactly one transaction type.

## 15. Open questions

1. Fork name and timestamp for `V7`; whether Nethermind ships it simultaneously (devnet chainspec suggests yes).
2. Launch parameters: is `TARGET 1 / MAX 3` right? A single L3 posting one blob per ~2 blocks consumes half the target; raising to 2/4 doubles the §12.2 storage bound.
3. Forced-inclusion hybrid: per-transaction design-A (body carried in the forced-inclusion L1 blob + equivalence proof) to close §12.4 — worth the prover complexity?
4. Protocol-native availability attestations/bonds (k-of-n signed custody receipts recorded cheaply on L1) vs. governance-grade enforcement — needed before permissionless preconfers.
5. Should blob-fee coinbase share be split among *all* serving nodes rather than the including preconfer (serving is network-wide, inclusion is individual)?
6. RIP submission timing: standardize before or after mainnet ship.

## Appendix A — retention arithmetic

```
Ethereum window   = MIN_EPOCHS_FOR_BLOB_SIDECARS_REQUESTS × SECONDS_PER_EPOCH
                  = 4096 × 384 s = 1_572_864 s ≈ 18.2 days
Taiko minimum     = 4 × 1_572_864 s = 6_291_456 s ≈ 72.8 days   (BLOB_RETENTION_SECONDS_MIN)
Taiko default     = 7_776_000 s = 90 days                        (BLOB_RETENTION_SECONDS_DEFAULT)
```

## Appendix B — manifest `SignedTransaction` delta

Two fields join the documented schema (encoding is the canonical Osaka envelope; no wrapper, no sidecar):

| Field | Type | Present when |
| --- | --- | --- |
| `maxFeePerBlobGas` | `uint256` | `txType == 0x03` |
| `blobVersionedHashes` | `bytes32[]` | `txType == 0x03` |
