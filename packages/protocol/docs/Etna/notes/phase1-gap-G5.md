# G5: What are the practical proof-aggregation and proving-economics limits? Known: codec allows 65,535 transitions per prove, ring buffer allows 21,599 unfinalized proposals, client batch size defaults to 1 with a 30-min forced flush, verifiers ignore proposalAge, and prove() writes state before verifying. Unknown: real L1 gas of prove() as n grows (hashCommitment is 9+3n words) and of the external Groth16/PLONK verifiers, Raiko's aggregation caps and per-lane latency for RISC0/SP1/SGX, and how provers are compensated today (no on-chain reward while whitelisted; livenessBond=0; actualProver self-declared).

All paths are relative to `/home/user/taiko-mono`. `P/` = `packages/protocol/`, `GO/` = `packages/taiko-client/`, `RS/` = `packages/taiko-client-rs/`. Line numbers were read from the working tree on 2026-09-30.

## Short answer

1. **The 65,535-transition codec bound is never the binding limit.** Two tighter bounds exist on-chain: a prove must cover a contiguous range ending below `nextProposalId` and starting at or before `lastFinalizedProposalId + 1` (`P/contracts/layer1/core/impl/Inbox.sol:797-806`), and the ring buffer refuses proposals once `nextProposalId - lastFinalizedProposalId >= 21_600` (`Inbox.sol:591-593`; `P/contracts/layer1/mainnet/MainnetInbox.sol:18`), so at most 21,599 unfinalized proposals can ever exist. Before either bound is reached, the L1 block gas limit binds (section 2).
2. **Measured L1 gas of `prove()` in the repo is linear at ~768 gas per extra transition on top of ~82k, but it is measured with a no-op verifier.** `P/snapshots/shasta-prove.json:2-6` records 82,220 (n=1), 82,986 (2), 83,747 (3), 85,278 (5), 89,130 (10); the verifier in that harness is `MockProofVerifier.verifyProof(...) external pure { }` (`P/test/layer1/core/inbox/mocks/MockContracts.sol:18-20`). The two external ZK verifiers (RISC0 Groth16 router `0x8EaB…`, SP1 PLONK gateway `0x3B60…`, `P/script/layer1/core/DeployShastaMainnet.s.sol:25,28`) are only ever `vm.mockCall`ed in tests (`P/test/layer1/verifiers/Risc0Verifier.t.sol:94-98`; `P/test/layer1/verifiers/SP1Verifier.t.sol:99`), so **their real gas is not measurable from this repo**. The repo does contain one real figure for the SGX leaf: `verifyProof` is "constant ~7,696 gas regardless of instance count" (`P/contracts/layer1/verifiers/sgx-verifier-daybreak-audit.md:377-378, 410-411`).
3. **Raiko's aggregation caps and per-lane latency are not in this repo.** The Go client sends the entire proof buffer as one `POST /v4/proof/proposal` request with `aggregate: true` and no client-side cap other than the buffer size (`GO/prover/proof_producer/compose_proof_producer.go:204-226, 361-371`); Raiko is an external service (`taikoxyz/raiko2`, `P/script/layer1/proposals/Proposal0019.md:275-279`). The only latency-related constants are a 10-minute request timeout, a 10-second poll, and a RISC0→SP1 fallback that triggers when the RISC0 lane falls 30 proposals behind finalization (`GO/cmd/flags/prover.go:36-42, 68-78, 120-126`). Generation times are exported as Prometheus gauges, not constants (`GO/internal/metrics/metrics.go:104-152`).
4. **Provers are not compensated on-chain today, and nothing about the prover is economically verified.** `Inbox.prove` contains no payment; its only prover-crediting path is the late-proof liveness settlement (`Inbox.sol:356-359, 729-744`; `P/contracts/layer1/core/libs/LibBonds.sol:148-170`), which is dormant for two independent reasons: it is skipped while the whitelist is enabled (`Inbox.sol:356-359`) and `livenessBond` is 0 (`MainnetInbox.sol:38` → `LibBonds.sol:158-159` returns on `debited == 0`). Even when active it is a slash of the *proposer* split 50/50 with the prover, not a reward. `actualProver` is whatever the client puts in the commitment (`GO/prover/proof_submitter/transaction/builder.go:45` sets it to `txOpts.From`), the contract never compares it to `msg.sender` (`Inbox.sol:337, 386`). The whitelist has one prover at deploy and is edited by the admin multisig (`DeployShastaMainnet.s.sol:32-34`; `P/contracts/layer1/core/impl/ProverWhitelist.sol:45-48, 74-95`).
5. **The "~2h cadence" is unenforced intent.** `provingWindow: 4 hours, // internal target is still to submit every ~2 hours` and `maxProofSubmissionDelay: 3 minutes` (`MainnetInbox.sol:40, 43`) are read only inside the dormant `_processLivenessBond` (`Inbox.sol:729-744`), and `permissionlessProvingDelay: 5 days` (`:42`) is never read outside the constructor and `getConfig` (`Inbox.sol:99, 165, 539`). The Go client does use `provingWindow` off-chain: it waits `provingWindow + 72 s` before proving another proposer's proposal (`GO/prover/event_handler/util.go:18, 57-65`; `GO/prover/event_handler/proposal.go:150-181`).
6. **There is no Rust prover** (`RS/crates/` holds `bindings driver proposer protocol rpc test-harness whitelist-preconfirmation-driver` only), so there is no Go/Rust divergence to report on proving.

## 1. On-chain aggregation bounds

### 1.1 Codec bound: 65,535 transitions

`P/contracts/layer1/core/libs/LibCodec.sol:68-69`:

```solidity
P.checkArrayLength(c.transitions.length);
ptr = P.packUint16(ptr, uint16(c.transitions.length));
```

`P/contracts/layer1/core/libs/LibPackUnpack.sol:312-314`: `require(_length <= type(uint16).max, LengthExceedsUint16());`. Decoding reads the same 2-byte length and allocates `new IInbox.Transition[](transitionsLength)` (`LibCodec.sol:90-92`). Encoded size is `130 + 58·n` bytes (`LibCodec.sol:110-121`; `P/contracts/layer1/core/libs/LibTransitionCodec.sol:11` `TRANSITION_SIZE = 58`).

### 1.2 Ring buffer bound: 21,599 unfinalized proposals

`MainnetInbox.sol:15-18`:

```solidity
/// Sized for worst-case throughput (1 proposal per L1 slot) over 3 days without finalization:
///   _RING_BUFFER_SIZE = (3 days × 86_400) / 12 = 21_600
uint48 private constant _RING_BUFFER_SIZE = 21_600;
```

`Inbox.sol:591-593`: `require(_ringBufferSize > _nextProposalId - _lastFinalizedProposalId, NotEnoughCapacity());` — strict, so the maximum backlog is 21,599. The Go client mirrors this as `MaxProposals() = RingBufferSize - 1` (`GO/pkg/config/protocol_config.go:50-56`) and sizes its channels with it (`GO/prover/prover.go:120, 225`). Devnet uses 100 (`P/contracts/layer1/devnet/DevnetInbox.sol:16`).

### 1.3 Range rules

`Inbox.sol:797-806`:

```solidity
uint256 firstUnfinalizedId = _state.lastFinalizedProposalId + 1;
numProposals_ = _commitment.transitions.length;
require(numProposals_ > 0, EmptyBatch());
require(_commitment.firstProposalId <= firstUnfinalizedId, FirstProposalIdTooLarge());
lastProposalId_ = _commitment.firstProposalId + numProposals_ - 1;
require(lastProposalId_ < _state.nextProposalId, LastProposalIdTooLarge());
require(lastProposalId_ >= firstUnfinalizedId, LastProposalAlreadyFinalized());
```

So one `prove` covers a contiguous range; the largest possible range is the full backlog of 21,599 proposals (plus already-finalized overlap). The Go builder enforces contiguity before sending (`builder.go:109-116`) and waits until the parent of the lowest proposal is finalized (`GO/prover/proof_submitter/proof_submitter.go:420-426`), so proofs are strictly serial per prover.

## 2. L1 gas of `prove()` as n grows

### 2.1 What the repo measures

`P/test/layer1/core/inbox/InboxProve.t.sol:18-92` runs `_proveWithGas(input, "shasta-prove", "prove_single" | "prove_batch_2" | ... | "prove_batch_10")`. The helper brackets only the `inbox.prove` call (`P/test/layer1/core/inbox/InboxTestBase.sol:284-286`):

```solidity
if (bytes(_benchName).length > 0) vm.startSnapshotGas(_profile, _benchName);
inbox.prove(encodedInput, bytes("proof"));
if (bytes(_benchName).length > 0) vm.stopSnapshotGas();
```

with `/// forge-config: default.isolate = true` (`InboxProve.t.sol:4`), so storage is cold. Results (`P/snapshots/shasta-prove.json:2-6`):

| n | gas | delta/transition |
| --: | --: | --: |
| 1 | 82,220 | — |
| 2 | 82,986 | 766 |
| 3 | 83,747 | 761 |
| 5 | 85,278 | 766 |
| 10 | 89,130 | 770 |

The whole-test numbers in `P/gas-reports/layer1-contracts.txt:90-93, 104` (215,343 for single up to 856,019 for batch10) include the harness that builds and encodes the input and are not L1 costs.

Caveats that make these numbers a floor:

- The verifier is `MockProofVerifier` (`InboxTestBase.sol:35, 80, 106`; `MockContracts.sol:18-20`), so no sub-proof decoding, no leaf hashing, and no external Groth16/PLONK call is included.
- `snapshotGas` excludes the transaction's intrinsic and calldata gas. Calldata is `130 + 58·n` bytes for the input (`LibCodec.sol:110-121`) plus the two sub-proofs.
- The `_proof` argument is the 5-byte string `"proof"` (`InboxTestBase.sol:285`).

### 2.2 Where the per-transition cost comes from

Per transition `prove` (a) copies 58 calldata bytes into memory because `decodeProveInput` takes `bytes memory` (`Inbox.sol:325`; `LibCodec.sol:76-79`), (b) allocates one `Transition` struct plus its array slot (`LibCodec.sol:92-95`), (c) writes 3 words into the hash buffer (`P/contracts/layer1/core/libs/LibHashOptimized.sol:52, 71-78`):

```solidity
uint256 totalWords = 9 + transitionsLength * 3;
...
for (uint256 i; i < transitionsLength; ++i) {
    IInbox.Transition memory transition = transitions[i];
    EfficientHashLib.set(buffer, base, bytes32(uint256(uint160(transition.proposer))));
    EfficientHashLib.set(buffer, base + 1, bytes32(uint256(transition.timestamp)));
    EfficientHashLib.set(buffer, base + 2, transition.blockHash);
    base += 3;
}
```

and (d) keccaks the buffer once (`LibHashOptimized.sol:80`). Storage work is independent of n: one `_coreState` write (`Inbox.sol:380`), one `saveCheckpoint` (`:364-370`), one ring-buffer read (`:349`), one whitelist call (`:337`), one `Proved` event (`:382-387`). That is consistent with the measured ~768 gas/transition being all memory and hashing.

### 2.3 Extrapolation (derived, not measured in the repo)

The following uses the EVM memory-expansion formula (3 gas per word plus words²/512) and 16 gas per non-zero calldata byte; both are general EVM facts, not something the repo models. Memory touched per transition is roughly `3` (hash buffer) + `4` (decoded array slot + struct) + `~1.8` (calldata copy) ≈ 8.8 words:

| n | memory words | memory gas | linear exec (768·n) | calldata (58·16·n) | rough total |
| --: | --: | --: | --: | --: | --: |
| 100 | ~880 | ~4k | 77k | 93k | ~0.26M |
| 1,000 | ~8.8k | ~0.18M | 0.77M | 0.93M | ~2M |
| 5,000 | ~44k | ~3.9M | 3.8M | 4.6M | ~12M |
| 10,000 | ~88k | ~15.4M | 7.7M | 9.3M | ~32M |
| 15,000 | ~132k | ~34M | 11.5M | 13.9M | ~60M |

So the quadratic memory term makes a single `prove` infeasible somewhere around 8k–12k transitions at a 36M-gas L1 block, well below both the 21,599 ring-buffer bound and the 65,535 codec bound. The exact ceiling needs a forge measurement against the real verifier chain, which the repo does not contain. Note also that `_data` is decoded before any validation (`Inbox.sol:325`), so an oversized input burns the whole memory cost before reverting.

### 2.4 Verifier-side gas: what is and is not measured

- `ComposeVerifier.verifyProof` ABI-decodes `SubProof[]`, loops over exactly the supplied sub-proofs and calls each leaf (`P/contracts/layer1/verifiers/compose/ComposeVerifier.sol:68-89`); `ZkRequiredVerifier` requires exactly two (`P/contracts/layer1/verifiers/compose/ZkRequiredVerifier.sol:37-48`). Compose-level tests with mocked leaves cost ~28k (`layer1-contracts.txt:5-11`).
- SGX leaf: `verifyProof` requires an 89-byte proof and does one instance lookup, one public-input hash and one `ECDSA.recover` (`P/contracts/layer1/verifiers/SgxVerifier.sol:459-480`); the Daybreak audit measured "constant ~7,696 gas for 1 / 50 / 200 registered instances" (`sgx-verifier-daybreak-audit.md:377-378, 410-411`); the test-level figure is 96,109 (`layer1-contracts.txt:364`).
- RISC0 leaf: two allowlist SLOADs, two hashes, one sha256, then `riscoGroth16Verifier.staticcall(IRiscZeroVerifier.verify(seal, aggregationImageId, journalDigest))` (`P/contracts/layer1/verifiers/Risc0Verifier.sol:62-80`). The test mocks the remote call (`Risc0Verifier.t.sol:94-98`) and measures 65,594 (`layer1-contracts.txt:261`).
- SP1 leaf: same shape, `sp1RemoteVerifier.staticcall(ISP1Verifier.verifyProof(aggregationProgram, publicValues, _proof[64:]))` (`P/contracts/layer1/verifiers/SP1Verifier.sol:64-83`); the test mocks the remote (`SP1Verifier.t.sol:99`) and measures 64,318 (`layer1-contracts.txt:267`).
- The mainnet remote verifiers are only addresses in a deploy script (`DeployShastaMainnet.s.sol:25` `r0Groth16Verifier = 0x8EaB2D97…`, `:28` `sp1PlonkVerifier = 0x3B604117…`). No test, snapshot, gas report, or doc in the repo records their gas. **This is the missing number**: the Groth16 pairing check and the PLONK verification dominate a real `prove` and are independent of n.
- Important for aggregation economics: verifier gas is **per proof, not per transition**. One `prove` pays the two remote verifications once regardless of n, so per-proposal L1 cost falls as `(fixed_verifier_cost + 82k)/n + ~768 + calldata`.

### 2.5 State is written before verification

`Inbox.sol:364-398`: `saveCheckpoint` (`:364-370`), `_coreState = state` (`:380`) and `emit Proved` (`:382-387`) precede `_proofVerifier.verifyProof(...)` (`:394-398`). Since every leaf reverts on failure (`P/contracts/layer1/verifiers/IProofVerifier.sol:9`), the ordering is safe, but a failing proof pays for the full decode, hashing, checkpoint write and event before reverting; the Go client treats such reverts as unretryable and re-queues the proposals (`GO/prover/prover.go:311-352`; `GO/prover/proof_submitter/transaction/sender.go:66-75`).

## 3. Verifiers ignore `proposalAge`

`Inbox.sol:336, 394-396` computes `proposalAge = block.timestamp - commitment.transitions[offset].timestamp` (unchecked) and passes it only for single-proposal proofs. Every leaf discards it: `Risc0Verifier.sol:50` `uint256, /* _proposalAge */`, `SP1Verifier.sol:51`, `SgxVerifier.sol:460`; `ComposeVerifier.sol:83` merely forwards it. The interface says the parameter exists to let verifiers treat "prover-killer" proposals differently (`IProofVerifier.sol:10-15`); no implementation does, so age carries no economic or acceptance consequence.

## 4. Client-side aggregation (Go; there is no Rust prover)

### 4.1 Buffer, batch size, forced flush

- One `ProofBuffer` per proof type (`sgx`, `risc0`, `sp1`), each sized `ZKVMProofBufferSize` (`GO/prover/init.go:99-107`; `GO/prover/config.go:143`), which is `--prover.zkvm.batchSize` default `1` (`GO/cmd/flags/prover.go:151-158`).
- `--prover.forceBatchProvingInterval` default `30m` (`prover.go:142-149`). The aggregation predicate (`proof_submitter.go:460-472`):

```go
if uint64(buffer.Len()) < buffer.MaxLength &&
    (buffer.Len() == 0 || time.Since(buffer.LastItemAt()) <= s.forceBatchProvingInterval) {
    return false
}
```

  The timer is measured from the **last** insert (`GO/prover/proof_producer/proof_buffer.go:55-57, 94-99`), so with `batchSize > 1` a steady stream of proofs arriving more often than every 30 minutes only aggregates when the buffer is full; the forced flush fires after a 30-minute gap. A monitor goroutine re-evaluates every minute (`GO/prover/proof_submitter/proof_buffer_monitor.go:19, 55-64`).
- Proofs that arrive out of order are cached and flushed into the buffer when contiguous and when capacity allows (`proof_submitter.go:342-365`; `proof_buffer_monitor.go:180-190`); the buffer rejects writes beyond `MaxLength` (`proof_buffer.go:51-53`).
- With the default `batchSize = 1`, every proposal is proven and landed individually; the "aggregate" Raiko request is still issued, but for one proposal (`compose_proof_producer.go:139-241`).

### 4.2 Raiko request shape and caps

`AggregateProofsByType` reads the entire buffer (`proof_submitter.go:492-496`) and calls `producer.Aggregate` (`:503`). `ComposeProofProducer.Aggregate` fires the primary and companion aggregation requests in parallel (`compose_proof_producer.go:194-226`); each is one `POST {raiko}/v4/proof/proposal` with `{proof_type, aggregate: true, proposals: [...], prover}` (`:361-371`). The client validates only that non-aggregation requests carry exactly one proposal (`:343-345`). No client-side maximum on proposals per aggregation exists. Raiko-side caps (proposals per aggregation, queue depth, GPU count) live in `taikoxyz/raiko2` and are not in this repository; the closest artefacts are the release manifests cited by the DAO proposals (`Proposal0019.md:275-289`; `Proposal0021.md:1-12`).

### 4.3 Lane selection and latency signals

- Primary lane defaults to RISC0 and falls back to SP1 when `proposalID > lastFinalizedProposalId + maxRisc0ProofProposalDistance` (default 30; `prover.go:68-78`; `proof_submitter.go:314-322`; `GO/prover/proof_submitter/risc0_sp1_fallback.go:92-132`), clearing the RISC0 backlog via `POST /v4/prover/clear` and polling `GET /v4/prover/status?proof_type=risc0` until `data.clean` (`GO/prover/proof_producer/risc0_backlog.go:35-75`). This is the only quantitative statement about relative lane speed in the repo: the code assumes RISC0 can lag by tens of proposals and SP1 is the faster catch-up lane.
- Companion lane: SGX-geth by default, RISC0 in `--prover.zkOnlyProofs` mode (`proof_submitter.go:295-298`; `prover.go:98-111`); `--prover.forceSGXProof` swaps the primary to SGX-reth (`prover.go:87-97`).
- Timeouts: `--raiko.requestTimeout` 10 min per request (`prover.go:36-42`; `compose_proof_producer.go:306`), `--prover.proofPollingInterval` 10 s (`prover.go:120-126`) driving a constant back-off on `work_in_progress` / `registered` statuses (`GO/prover/proof_producer/common.go:40-45`; `proof_submitter.go:204-245`). No constant states expected proof generation time; it is observed via gauges (`metrics.go:104-152`).
- The only latency *model* in the repo is the zk-gas spec: 4 GPUs, 384 blocks per proposal, a "~12 hours" target deadline, with a table down to "2 hours → 7.2B zk gas budget" (`P/docs/zk_gas_spec.md:419-432`), self-declared a placeholder (`:434`).
- Operational evidence: Proposal0019 says proving ran on the `RISC0 + SP1` pair while SGX instances were unregistered (`Proposal0019.md:121-123`) and that every image rotation discards in-flight proofs (`:184-188, 384-388`); Proposal0021 rotated again for a RISC0 guest performance change (`Proposal0021.md:10-12`).

### 4.4 L1 gas limit

`--tx.gasLimit` defaults to `0` = "using gas estimation" (`GO/cmd/flags/txmgr.go:82-88`), threaded to `ProveBatchesGasLimit` (`config.go:134`; `init.go:119`) and into `bind.TransactOpts{GasLimit: s.gasLimit}` (`sender.go:49`). The client imposes no cap on prove size; the L1 block gas limit is the cap.

### 4.5 Who proves what

`DesignatedProver: meta.GetProposer(), // Designated prover is always the proposer for Shasta.` (`proof_submitter.go:191`). A prover only proves proposals whose proposer is itself or in `--prover.localProposerAddresses` (`GO/prover/event_handler/proposal_handler.go:68-71`), unless `--prover.proveUnassignedProposals` (default false, `prover.go:50-56`) is set, in which case it waits until `timestamp + provingWindow + 72 s` (`util.go:18, 57-65`; `proposal.go:174-178`). This "assignment" exists only in the client; the contract has no designated prover (section 5.3).

### 4.6 Rust client

`RS/crates/` contains `bindings driver proposer protocol rpc test-harness whitelist-preconfirmation-driver`; no prover crate, no `prove` transaction builder. All proving behaviour above is Go-only.

## 5. Prover compensation today

### 5.1 No on-chain reward

`Inbox.prove` (`Inbox.sol:321-400`) transfers nothing to the prover. The `Proved` event records `actualProver` (`:382-387`; `P/contracts/layer1/core/iface/IInbox.sol:183-188`) but no token flow references it.

### 5.2 The liveness path is a dormant proposer slash, not a reward

`Inbox.sol:356-359`:

```solidity
// Bond transfers only apply when whitelist is not enabled.
if (!isWhitelistEnabled) {
    _processLivenessBond(commitment, offset);
}
```

`_checkProver` returns `true` whenever the whitelist address is set and `proverCount > 0` (`Inbox.sol:771-779`; `ProverWhitelist.sol:98-107`), which is the mainnet state (`P/contracts/layer1/mainnet/LibL1Addrs.sol:39`; `DeployShastaMainnet.s.sol:33-34`). Independently, `livenessBond: 0` (`MainnetInbox.sol:38`) makes `settleLivenessBond` a no-op: `uint64 debited = _debitBond($, _payer, _livenessBond); if (debited == 0) return;` (`LibBonds.sol:158-159`). When it does run, the payer is `transitions[offset].proposer`, the payee `actualProver`, and only `debited / 2` is credited; the other half is emitted as `slashedAmount` and stays in the contract (`Inbox.sol:740-742`; `LibBonds.sol:161-169`). Deadline: `max(timestamp + provingWindow, lastFinalizedTimestamp + maxProofSubmissionDelay)` (`Inbox.sol:731-733`). `minBond: 0` also disables the proposer bond gate (`MainnetInbox.sol:37`; `Inbox.sol:604-607`).

### 5.3 `actualProver` is self-declared

`IInbox.sol:130-131` `/// @notice The actual prover who generated the proof. address actualProver;`. The Go builder sets `Commitment: shastaBindings.IInboxCommitment{ActualProver: txOpts.From}` (`builder.go:45`). On-chain the gate is on `msg.sender` only (`Inbox.sol:337`), `actualProver` is hashed into the commitment (`LibHashOptimized.sol:63`) and emitted (`Inbox.sol:386`), never compared to the sender. A future reward keyed on `actualProver` would therefore be attributable to any address the submitter chooses.

### 5.4 Whitelist

`DeployShastaMainnet.s.sol:32-34`: `proverManager = LibL1Addrs.MULTISIG_ADMIN_TAIKO_ETH; provers = [0xa5cb34B75bD72f15290ef37A01F06183E8036875]`. `whitelistProver` is `onlyOwnerOrProverManager` (`ProverWhitelist.sol:45-48, 74-95`). The comment `minBond: 0, // During prover whitelist, bonds are not necessary` (`MainnetInbox.sol:37`) states the design intent: while access is permissioned, economics are off.

### 5.5 What revenue exists at all

The only value flows the protocol creates are proposer-side: 75 % of L2 basefee to coinbase (`MainnetInbox.sol:45`; `IInbox.sol:38-39` `basefeeSharingPctg`) and forced-inclusion fees pushed to `msg.sender` of `propose` (`Inbox.sol:595-596, 710`). Because the Go client's designated prover is the proposer (`proof_submitter.go:191`), proving is implicitly funded from proposing revenue, off-chain. Nothing in the code prices a proof.

### 5.6 Docs vs code

- `P/docs/tokenomics-whitepaper.tex` (dated Dec 6, 2023, `:15`) describes Liveness, Validity and Contestation bonds, proof tiers, and forfeited bonds redirected to a treasury (`:29-31, 39`). The current `Inbox` has one liveness bond, no contest, no tiers, and the slashed half is never transferred (`LibBonds.sol:161-169`). The whitepaper is not a description of current economics.
- `P/docs/tokenomics_objective_metrics.md:11` targets "an equilibrium between proposer fees and prover rewards"; no prover reward exists in code.
- `P/docs/contestable_validity_rollup.md:91-95` ("Prover Fees", assignment-based payment) describes a removed design.
- `P/gas-reports/LibProveInputCodec.md:5-10` reports scenarios with "Blob Hashes per proposal"; the current `ProveInput` has no blob hashes (`LibCodec.sol:61-72`), so that report is stale relative to the codec it names.
- `GO/cmd/flags/prover.go:144` refers to `prover.batchSize`; the actual flag is `prover.zkvm.batchSize` (`:152`).

## 6. The "~2h cadence" and `provingWindow`

`MainnetInbox.sol:40-43`:

```solidity
provingWindow: 4 hours, // internal target is still to submit every ~2 hours
// Allows the security council time to intervene if a bug is found.
permissionlessProvingDelay: 5 days,
maxProofSubmissionDelay: 3 minutes, // We want this to be lower than the expected cadence
```

`provingWindow` and `maxProofSubmissionDelay` are used only in `_processLivenessBond` (`Inbox.sol:729-744`), dormant per 5.2; `permissionlessProvingDelay` is stored and returned but never read in a gate (`Inbox.sol:99, 165, 539`). `IInbox.sol:33-34` documents `maxProofSubmissionDelay` as "Must be shorter than the expected proposal cadence to prevent backlog growth", again intent. The only enforced cadence-related limit is the 21,599-proposal ring buffer, i.e. ~3 days at one proposal per slot (`MainnetInbox.sol:16-17`), after which `propose` reverts `NotEnoughCapacity` (`Inbox.sol:591-593`).

## 7. What cannot be answered from the repo

1. Real L1 gas of the RISC0 Groth16 router (`0x8EaB…`) and SP1 PLONK gateway (`0x3B60…`) calls (`DeployShastaMainnet.s.sol:25, 28`); all tests mock them (`Risc0Verifier.t.sol:94-98`; `SP1Verifier.t.sol:99`). Needs a mainnet-fork forge measurement with a real proof.
2. `prove()` gas for n > 10 with a real verifier; only n ∈ {1,2,3,5,10} with a no-op verifier are snapshotted (`shasta-prove.json:2-6`). Section 2.3 is an extrapolation.
3. Raiko's maximum proposals per aggregation, queue limits, GPU fleet, and per-lane proof times for RISC0/SP1/SGX; the repo only has the request/response contract (`compose_proof_producer.go:24-40, 361-371`; `common.go:16-59`) and the fallback distance of 30 proposals (`prover.go:75`).
4. How the whitelisted prover is paid (any off-chain arrangement with Taiko Labs); the only on-chain evidence is that no payment path exists (section 5).
5. Sub-proof calldata sizes for RISC0/SP1 (needed for a full per-`prove` cost); the SGX proof is 89 bytes (`SgxVerifier.sol:467`), the ZK proofs are opaque `bytes` (`Risc0Verifier.sol:58-59`; `SP1Verifier.sol:58-60, 79`).

## Claims index

| # | Claim | Evidence |
| --- | --- | --- |
| 1 | Codec caps transitions at 65,535 via `checkArrayLength` and `uint16` length | `P/contracts/layer1/core/libs/LibCodec.sol:68-69, 90-92`; `P/contracts/layer1/core/libs/LibPackUnpack.sol:312-314` |
| 2 | Encoded ProveInput is 130 + 58·n bytes | `LibCodec.sol:110-121`; `P/contracts/layer1/core/libs/LibTransitionCodec.sol:11` |
| 3 | Ring buffer 21,600, strict capacity check → 21,599 unfinalized | `P/contracts/layer1/mainnet/MainnetInbox.sol:15-18`; `P/contracts/layer1/core/impl/Inbox.sol:591-593` |
| 4 | Go `MaxProposals` = ringBufferSize − 1 | `GO/pkg/config/protocol_config.go:50-56`; `GO/prover/prover.go:120, 225` |
| 5 | Devnet ring buffer 100 | `P/contracts/layer1/devnet/DevnetInbox.sol:16` |
| 6 | Prove range rules (contiguous, ≤ lastFinalized+1, < nextProposalId, must advance) | `Inbox.sol:797-806` |
| 7 | Go builder enforces contiguity; waits for parent finalization | `GO/prover/proof_submitter/transaction/builder.go:109-116`; `GO/prover/proof_submitter/proof_submitter.go:420-426` |
| 8 | Prove gas snapshots 82,220 / 82,986 / 83,747 / 85,278 / 89,130 for n = 1/2/3/5/10 | `P/snapshots/shasta-prove.json:2-6` |
| 9 | Snapshot brackets only `inbox.prove`; isolate mode; `"proof"` placeholder | `P/test/layer1/core/inbox/InboxTestBase.sol:284-286`; `P/test/layer1/core/inbox/InboxProve.t.sol:4, 18-92` |
| 10 | Snapshot verifier is a no-op mock | `P/test/layer1/core/inbox/mocks/MockContracts.sol:18-20`; `InboxTestBase.sol:35, 80, 106` |
| 11 | Whole-test gas 215,343 … 856,019 includes harness | `P/gas-reports/layer1-contracts.txt:90-93, 104` |
| 12 | hashCommitment buffer is 9 + 3n words, one keccak | `P/contracts/layer1/core/libs/LibHashOptimized.sol:52, 71-80` |
| 13 | Decode copies calldata to memory and allocates n structs before validation | `Inbox.sol:325`; `LibCodec.sol:76-95` |
| 14 | Per-prove storage work independent of n | `Inbox.sol:337, 349, 364-370, 380, 382-387` |
| 15 | ComposeVerifier loops sub-proofs; ZkRequired needs exactly two | `P/contracts/layer1/verifiers/compose/ComposeVerifier.sol:68-89`; `P/contracts/layer1/verifiers/compose/ZkRequiredVerifier.sol:37-48` |
| 16 | Compose tests ~28k with mocks | `layer1-contracts.txt:5-11` |
| 17 | SGX verifyProof: 89-byte proof, ECDSA recover; ~7,696 gas constant | `P/contracts/layer1/verifiers/SgxVerifier.sol:459-480`; `P/contracts/layer1/verifiers/sgx-verifier-daybreak-audit.md:377-378, 410-411`; `layer1-contracts.txt:364` |
| 18 | Risc0Verifier staticcalls Groth16 router; test mocks it; 65,594 | `P/contracts/layer1/verifiers/Risc0Verifier.sol:62-80`; `P/test/layer1/verifiers/Risc0Verifier.t.sol:94-98`; `layer1-contracts.txt:261` |
| 19 | SP1Verifier staticcalls PLONK gateway; test mocks it; 64,318 | `P/contracts/layer1/verifiers/SP1Verifier.sol:58-83`; `P/test/layer1/verifiers/SP1Verifier.t.sol:99`; `layer1-contracts.txt:267` |
| 20 | Mainnet remote verifier addresses; no gas measured in repo | `P/script/layer1/core/DeployShastaMainnet.s.sol:25, 28` |
| 21 | State written before verify; verifier must revert on failure | `Inbox.sol:364-398`; `P/contracts/layer1/verifiers/IProofVerifier.sol:9` |
| 22 | Go treats reverted prove as unretryable and re-queues | `GO/prover/prover.go:311-352`; `GO/prover/proof_submitter/transaction/sender.go:66-75` |
| 23 | proposalAge computed unchecked, passed only for single-proposal proofs | `Inbox.sol:322, 336, 394-396` |
| 24 | All leaf verifiers ignore proposalAge; compose forwards it | `Risc0Verifier.sol:50`; `SP1Verifier.sol:51`; `SgxVerifier.sol:460`; `ComposeVerifier.sol:83`; `IProofVerifier.sol:10-15` |
| 25 | One ProofBuffer per type sized by batchSize (default 1) | `GO/prover/init.go:99-107`; `GO/prover/config.go:143`; `GO/cmd/flags/prover.go:151-158` |
| 26 | Forced flush 30 min measured from last insert; monitor every minute | `prover.go:142-149`; `proof_submitter.go:460-472`; `GO/prover/proof_producer/proof_buffer.go:55-57, 94-99`; `GO/prover/proof_submitter/proof_buffer_monitor.go:19, 55-64` |
| 27 | Out-of-order proofs cached and flushed; buffer overflow error | `proof_submitter.go:342-365`; `proof_buffer_monitor.go:180-190`; `proof_buffer.go:51-53` |
| 28 | Aggregate reads whole buffer; single Raiko request; no client cap | `proof_submitter.go:492-503`; `GO/prover/proof_producer/compose_proof_producer.go:139-241, 343-345, 361-371` |
| 29 | Raiko request/response schema; statuses | `compose_proof_producer.go:24-40`; `GO/prover/proof_producer/common.go:16-59` |
| 30 | RISC0→SP1 fallback distance 30; backlog control-plane | `prover.go:68-78`; `proof_submitter.go:314-322`; `GO/prover/proof_submitter/risc0_sp1_fallback.go:92-132`; `GO/prover/proof_producer/risc0_backlog.go:35-75` |
| 31 | Companion/primary lane selection | `proof_submitter.go:285-298`; `prover.go:79-111` |
| 32 | Raiko request timeout 10 min; polling 10 s | `prover.go:36-42, 120-126`; `compose_proof_producer.go:306`; `proof_submitter.go:204-245` |
| 33 | Generation times only as metrics | `GO/internal/metrics/metrics.go:104-152`; `common.go:127-176` |
| 34 | zk-gas spec latency model is a placeholder (4 GPUs, 12 h, 2 h row) | `P/docs/zk_gas_spec.md:419-434` |
| 35 | Proving ran on RISC0+SP1 during SGX gap; rotations discard in-flight proofs | `P/script/layer1/proposals/Proposal0019.md:121-123, 184-188, 384-388`; `Proposal0021.md:10-12` |
| 36 | Prove tx gas limit defaults to estimation | `GO/cmd/flags/txmgr.go:82-88`; `config.go:134`; `init.go:119`; `sender.go:49` |
| 37 | Designated prover = proposer (client-only); proveUnassigned waits provingWindow + 72 s | `proof_submitter.go:191`; `GO/prover/event_handler/proposal_handler.go:68-71`; `GO/prover/event_handler/util.go:18, 57-65`; `GO/prover/event_handler/proposal.go:150-181`; `prover.go:50-56` |
| 38 | No Rust prover | `RS/crates/` listing (bindings, driver, proposer, protocol, rpc, test-harness, whitelist-preconfirmation-driver) |
| 39 | prove() has no payment; Proved event carries actualProver | `Inbox.sol:321-400, 382-387`; `P/contracts/layer1/core/iface/IInbox.sol:183-188` |
| 40 | Liveness settlement skipped while whitelist enabled | `Inbox.sol:356-359, 771-779`; `P/contracts/layer1/core/impl/ProverWhitelist.sol:98-107` |
| 41 | livenessBond 0 → settle returns on debited == 0 | `MainnetInbox.sol:38`; `P/contracts/layer1/core/libs/LibBonds.sol:158-159` |
| 42 | Settlement is proposer slash, half to prover, half retained | `Inbox.sol:729-744`; `LibBonds.sol:148-170` |
| 43 | minBond 0 disables proposer bond gate | `MainnetInbox.sol:37`; `Inbox.sol:604-607` |
| 44 | actualProver self-declared; client uses txOpts.From; never compared to msg.sender | `IInbox.sol:130-131`; `builder.go:45`; `Inbox.sol:337, 386`; `LibHashOptimized.sol:63` |
| 45 | One whitelisted prover at deploy; manager = admin multisig; owner-or-manager edits | `DeployShastaMainnet.s.sol:32-34`; `ProverWhitelist.sol:45-48, 74-95`; `P/contracts/layer1/mainnet/LibL1Addrs.sol:39` |
| 46 | Only value flows are proposer-side (basefee share, FI fees) | `MainnetInbox.sol:45`; `IInbox.sol:38-39`; `Inbox.sol:595-596, 710` |
| 47 | Whitepaper (2023) describes bonds/tiers/treasury not in code | `P/docs/tokenomics-whitepaper.tex:15, 29-31, 39`; `LibBonds.sol:161-169` |
| 48 | Objective-metrics doc assumes prover rewards; contestable doc describes removed fees | `P/docs/tokenomics_objective_metrics.md:11`; `P/docs/contestable_validity_rollup.md:91-95` |
| 49 | LibProveInputCodec gas report is stale vs current codec | `P/gas-reports/LibProveInputCodec.md:5-10`; `LibCodec.sol:61-72` |
| 50 | Flag help text names non-existent `prover.batchSize` | `prover.go:144, 152` |
| 51 | provingWindow/maxProofSubmissionDelay only in dormant settlement; permissionlessProvingDelay never gated | `MainnetInbox.sol:40-43`; `Inbox.sol:99, 165, 539, 729-744`; `IInbox.sol:33-34` |
| 52 | Ring buffer sized as 3 days at one proposal per slot | `MainnetInbox.sol:16-17` |
