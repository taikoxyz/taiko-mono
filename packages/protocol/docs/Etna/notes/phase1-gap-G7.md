# G7: What are the Unzen fork semantics? Derivation.md does not describe Unzen beyond the 768-block cap and still says difficulty = keccak(parent.difficulty, number) and SHASTA_FORK_TIME is 'not scheduled', while the Rust driver requires header.difficulty == 0 pre-Unzen and non-zero (= block_zk_gas_used, per an unimplemented zk-gas spec) post-Unzen, and the Go preconf path has no difficulty gate (the referenced pkg/preconf/validation.go does not exist). Fork timestamps live only in the external alethia-reth chainspec.

Studied at taiko-mono commit `7c0e9740980fc897d9ecab355f5bfec9ec047940` (2026-09-30). External code was read from the pinned dependencies actually used by the build: taiko-geth `v1.18.1-0.20260924044618-8e98046bfd6a` (Go module cache, `go.mod:308`), the taikoxyz optimism fork `v0.0.0-20260420065638-5490c5186828` (Go module cache), and alethia-reth rev `0fb47d966f290c032e0ce88bdc8877121768d253` (`packages/taiko-client-rs/Cargo.toml:77`, `Cargo.lock:69-71`; `crates/chainspec/src/hardfork.rs` fetched from GitHub at that rev).

## Short answer

"Unzen" is two coupled things:

1. **An L1 governance upgrade (Proposal0019)** with *no timestamp gating*: it re-enables forced inclusions, swaps the Inbox's immutable verifier for `ZkRequiredVerifier` (every batch needs at least one ZK proof) and rotates trusted proving images. No Solidity code is timestamp-gated on Unzen (`Proposal0019.md:1-8,30-32`; `grep -i unzen` over `packages/protocol/contracts` hits only a `MainnetVerifier.sol` deprecation comment).
2. **An L2 timestamp hardfork** (`TaikoHardfork::Unzen` / `ChainConfig.UnzenTime`) that changes the execution layer and, through it, block headers:
   - Cancun + Prague + Osaka are activated at the Unzen timestamp (`taiko_genesis.go:44-48`; alethia-reth `hardfork.rs:148-150`), so every Unzen header carries `parentBeaconBlockRoot = 0x0`, `requestsHash = EMPTY_REQUESTS_HASH`, `blobGasUsed = 0`, `excessBlobGas = 0` and blob transactions are forbidden (`consensus.go:249-279,380-385`).
   - **zk-gas metering** is switched on (`state_processor.go:88-91`, `taiko_worker.go:263-266`) with `BLOCK_ZK_GAS_LIMIT = 100_000_000` and `TX_INTRINSIC_ZK_GAS = 243_000` (`taiko_zk_gas_unzen.go:10,16`, matching `zk_gas_spec.md:11-12`). Block building stops at the first non-anchor tx that would exceed the limit (`taiko_worker.go:297-309`), and import rejects a body that extends past the truncation point (`state_processor.go:186-194`).
   - **`header.difficulty` is repurposed to carry `block_zk_gas_used`**: the builder sets `env.header.Difficulty = zkGasMeter.BlockZkGasUsed()` (`taiko_worker.go:337-339`); block processing rejects a header whose difficulty differs from the recomputed value (`state_processor.go:195-201`); pre-Unzen difficulty must be exactly 0 (`consensus.go:176-183`).
   - The **per-derivation-source block cap** rises from 192 to 768, keyed on the proposal's L1 timestamp (`Derivation.md:163-165`; Go `engine_unzen.go:25-31`, `source_fetcher.go:149`; Rust `constants.rs:244-252`, `pipeline/mod.rs:375-376`).

Because difficulty is now execution-dependent, the Engine API and the preconfirmation gossip both had to grow a side-channel for it: `getPayloadV2.blockValue` transports it back into `newPayloadV2.headerDifficulty` (Go `engine_unzen.go:43-62`; Rust `engine.rs:254-282`), and the SSZ gossip envelope grew an optional 32-byte `HeaderDifficulty` slot flagged by `flags0 & 0x02` (`codec.rs:184-230,257-280`; optimism fork `ssz.go:467-491,535-572`). **Only the Rust receiver validates that slot against the fork schedule; the Go receiver does not** (details in section 6).

Fork timestamps do not live *only* in alethia-reth: taiko-geth carries an identical hard-coded schedule that the Go client uses. Both say Mainnet Shasta = `1_775_135_700` (2026-04-02 13:15 UTC), Mainnet Unzen = `1_786_021_200` (2026-08-06 13:00 UTC), Hoodi Shasta = `1_770_296_400`, Hoodi Unzen = `1_781_787_600` (2026-06-18 13:00 UTC), devnet 0/0 (`taiko_genesis.go:22-28`; alethia-reth `hardfork.rs:74-75,84-85,94-95`). `Derivation.md:380` ("SHASTA_FORK_TIME: Hoodi/Mainnet: not scheduled") is stale on both networks.

## 1. Fork activation: where and how it is decided

### Rust client
- The `protocol` crate imports the hardfork tables from alethia-reth (`constants.rs:6-8`: `use alethia_reth_chainspec::hardfork::{TAIKO_DEVNET_HARDFORKS, TAIKO_HOODI_HARDFORKS, TAIKO_MAINNET_HARDFORKS, TaikoHardfork}`) and resolves them per chain ID (`constants.rs:180-190`), returning `ForkConfigError::UnsupportedChainId` for anything but devnet/Hoodi/mainnet.
- `unzen_active_for_chain_timestamp(chain_id, ts)` is `ts >= fork_timestamp`, `false` for `ForkCondition::Never`, and an error for any other condition kind (`constants.rs:234-242`).
- Devnet only: a process-global `OnceLock` override set from `--devnet-unzen-timestamp` / `DEVNET_UNZEN_TIMESTAMP` (`constants.rs:65-80,203-213`; `flags/common.rs:87-94`; `commands/driver.rs:54`). It must match alethia-reth's `--devnet-unzen-timestamp` (`flags/common.rs:92`).
- alethia-reth `hardfork.rs:70-95` (fetched at the pinned rev) hard-codes: mainnet `Shasta Timestamp(1_775_135_700)`, `Unzen Timestamp(1_786_021_200)`; Hoodi `Shasta Timestamp(1_770_296_400)`, `Unzen Timestamp(1_781_787_600)`; devnet both `Timestamp(0)`. `hardfork.rs:114-123,147-150` derives Cancun/Prague/Osaka from the Unzen activation ("Taiko executes Unzen with Osaka").

### Go client
- `rpc.IsUnzen(chainID, ts)` builds the built-in genesis for the chain ID via `core.TaikoGenesisBlock` and asks `genesis.Config.IsUnzen(ts)`; unknown chain IDs yield `false` (`engine_unzen.go:14-22`). `ChainConfig.IsUnzen` is a plain timestamp comparison on `UnzenTime` (`params/config.go:504,919-922`).
- taiko-geth `core/taiko_genesis.go:22-28`: `MainnetShastaTime = 1_775_135_700`, `HoodiShastaTime = 1_770_296_400`, `DevnetUnzenTime = 0`, `MainnetUnzenTime = 1_786_021_200 // 2026-08-06 13:00:00 UTC`, `HoodiUnzenTime = 1_781_787_600`; lines 43-48 and 65-70 set `ShastaTime`, `UnzenTime` and `CancunTime = PragueTime = OsakaTime = UnzenTime`.
- Consequence: the Go and Rust clients agree on the schedule, but the Go devnet Unzen time is hard-coded to 0 while the Rust devnet time is overridable.

### Solidity / docs
- No contract reads a fork timestamp; Proposal0019 states "The fork activates at proposal execution. There is no in-contract timestamp gating" (`Proposal0019.md:30-32`). `Derivation.md:380` still lists `SHASTA_FORK_TIME` as "not scheduled" and has no `UNZEN_FORK_TIME` row at all.

## 2. Header semantics: what `difficulty` and `mixHash` actually are

### What Derivation.md says
- `Derivation.md:47`: difficulty is "A random number seed".
- `Derivation.md:275`: `metadata.difficulty = keccak(abi.encode(parent.metadata.difficulty, metadata.number))`.
- `Derivation.md:302`: metadata `difficulty` maps to header field `difficulty`.
- `Derivation.md:314`: `mixHash` "Set to `prevRandao` as per EIP-4399".

### What both clients do (pre- and post-Unzen alike)
The keccak chain is computed and written into **`mixHash`/`prevRandao`**, not `difficulty`, and its input is the parent's **header** `difficulty`:
- Rust `payload.rs:438-439`: `let parent_mix_hash = B256::from(state.header.difficulty.to_be_bytes::<32>()); let mix_hash = calculate_shasta_mix_hash(parent_mix_hash, block_number);` with `calculate_shasta_mix_hash = keccak256(abi.encode(parentMixHash, blockNumber))` (`payload_helpers.rs:29-35`); `mix_hash` is then passed as the payload attribute (`payload.rs:467,513`) and checked against `block.header.mix_hash` (`payload.rs:836-839`).
- Go `common.go:480`: `mixHash, err := encoding.CalculateShastaMixHash(parent.Difficulty, blockID)`; the preconf API does the same with `parent.Difficulty()` (`api.go:168-171`); `CalculateShastaMixHash` is `keccak256(abi.encode(parentDifficulty, blockNum))` (`encoding/input.go:153-160`); the value goes into `PayloadAttributes.Random`/`BlockMetadata.MixHash` (`common.go:133-143`).
- The EL never derives difficulty from that: `Taiko.CalcDifficulty` returns 0 (`consensus.go:427-429`) and `Prepare` sets `header.Difficulty = 0` (`consensus.go:295-303`).

So the doc's "difficulty" rule is really the mixHash rule, and pre-Unzen `header.difficulty` is always 0 (enforced: `consensus.go:176-180`; Go driver `common.go:372-376`; Rust driver `payload.rs:803-807`).

### Post-Unzen: `difficulty == block_zk_gas_used`
- Builder: `taiko_worker.go:337-339` `// CHANGE(taiko): set header difficulty to finalized block zk gas for Unzen. if zkGasMeter != nil { env.header.Difficulty = new(big.Int).SetUint64(zkGasMeter.BlockZkGasUsed()) }`; `Finalize` leaves it alone when Unzen is active (`consensus.go:314-318`).
- Importer: `state_processor.go:195-201` `recomputed := new(big.Int).SetUint64(cfg.ZkGasMeter.BlockZkGasUsed()); if header.Difficulty.Cmp(recomputed) != 0 { return nil, fmt.Errorf("zk gas difficulty mismatch: ...") }`.
- Header verification: `consensus.go:176-183` `// Unzen repurposes difficulty for zk gas; only enforce zero before Unzen.` and, when Unzen is active, `verifyUnzenHeaderFields` (`consensus.go:249-279`) requires `RequestsHash == EmptyRequestsHash`, `ParentBeaconRoot == 0x0`, `BlobGasUsed == 0`, `ExcessBlobGas == 0`.
- Side effect on the mixHash chain: because both drivers feed the parent's header difficulty into `calculate_shasta_mix_hash`, from the first Unzen block on the "random seed" chain is seeded by the parent's zk gas used, i.e. `mixHash_n = keccak(abi.encode(uint256(zk_gas_used_{n-1}), n))`. Neither doc describes this.
- Both drivers' "is this canonical block the one we would derive" checks are fork-gated identically: Rust `payload.rs:775-807` (`unzen_active` -> `difficulty == 0` is a mismatch, `blob_gas_used/excess_blob_gas == Some(0)`, `parent_beacon_block_root == Some(0)`, `requests_hash == Some(EMPTY_REQUESTS_HASH)`; else difficulty must be 0 and the four fields must be `None`); Go `common.go:372-408` (same checks via `rpc.IsUnzen(cli.L2.ChainID, block.Time())`). Note neither driver checks *which* non-zero difficulty value is right; that is left to the EL's recomputation.

### What "zk gas" is
- Spec: `zk_gas_spec.md:11-12` constants, `zk_gas_spec.md:113-134` block loop (abort offending tx, skip the rest, keep earlier txs), `zk_gas_spec.md:417-434` Appendix C rationale (100M is "a placeholder and will almost certainly change", derived from 4 GPUs / 384 blocks per proposal / 12 h deadline).
- The spec never mentions `difficulty` or the block header at all (`grep -ci difficulty zk_gas_spec.md` = 0). The "difficulty = block_zk_gas_used" mapping exists only in code comments (`payload.go:23-29`; `ingress.rs:276-278`) and in taiko-geth.
- The claim that the spec is "unimplemented" is true for taiko-mono itself (no zk-gas code in the repo) but not for the EL the Go client is built against: taiko-geth ships the Unzen schedule (`core/vm/taiko_zk_gas_unzen.go:10-45`, `core/vm/taiko_zk_gas.go:27-47`), meters opcodes/precompiles (`core/vm/evm.go:258,367,455,528,609`), and enforces the header invariant (`state_processor.go:186-201`). alethia-reth's executor was not inspected beyond its chainspec; the taiko-geth comments call it "the Rust reference block-executor" (`state_processor.go:189`, `consensus.go:259-263`).

## 3. Engine API transport of the Unzen difficulty

- taiko-geth `BlockToExecutableData` sets `blockValue = block.Difficulty()` and `data.HeaderDifficulty = block.Difficulty()` whenever difficulty > 0 (`beacon/engine/types.go:443-447`). `ExecutableDataToBlock` uses `HeaderDifficultyOrZero()` for `Difficulty` and, when `HeaderDifficulty != nil`, forces `requestsHash = empty`, `beaconRoot = 0`, `blobGasUsed = excessBlobGas = 0` (`types.go:348-374`). The V2 `newPayload` fast path does the same (`eth/catalyst/api.go:951-969`) and is only allowed for Unzen payloads that carry `HeaderDifficulty` (`api.go:839-841`).
- Go driver: `EngineClient.GetPayload` runs `NormalizeExecutableData(chainID, envelope.ExecutionPayload, envelope.BlockValue)` (`engine.go:100-110`), which for `IsUnzen(chainID, payload.Timestamp)` errors on a nil `blockValue` and copies it into `HeaderDifficulty` (`engine_unzen.go:43-62`). Beacon sync uses the same helper (`beaconsync/syncer.go:100-101`).
- Rust driver: `unzen_header_difficulty(chain_id, ts, block_value)` returns `Some(block_value)` iff Unzen is active (`engine.rs:254-256`, note `.unwrap_or(false)` swallows unsupported-chain errors); `envelope_into_submission` comments "Taiko Unzen reuses `getPayloadV2.blockValue` to transport the original `header.difficulty` back into `newPayloadV2.headerDifficulty`" (`engine.rs:258-282`). The sidecar field is serialized as a decimal `u64` for taiko-geth compatibility and values above `u64::MAX` are rejected (`auth.rs:58-65,71-86`). Checkpoint import passes the sealed header's difficulty explicitly (`beacon.rs:127,143-146`).

## 4. Derivation cap: 192 -> 768

- Doc: `Derivation.md:163-165` ("Before Unzen: DERIVATION_SOURCE_MAX_BLOCKS = 192; At/after Unzen: UNZEN_DERIVATION_SOURCE_MAX_BLOCKS = 768"), `Derivation.md:368-369`.
- Go: `manifest.go:17-20` (`ProposalMaxBlocks = 192`, `UnzenProposalMaxBlocks = 768`); `rpc.DerivationSourceMaxBlocks` selects on `IsUnzen(chainID, proposalTimestamp)` (`engine_unzen.go:25-31`); used at `source_fetcher.go:149-157` (too many blocks -> default payload).
- Rust: `constants.rs:22-25`; `derivation_source_max_blocks_for_chain_timestamp` returns 768 when active and **falls back to 192 on `Err`** (`constants.rs:244-252`); used at `pipeline/mod.rs:375-376`.
- Both proposers deliberately keep the 192 cap: Go `proposer.go:320-324` (`manifest.ProposalMaxBlocks`), Rust `transaction_builder.rs:110-116` ("Proposer intentionally keeps the stricter Shasta cap").

## 5. Gossip wire format: `HeaderDifficulty`

- Rust `codec.rs:28-44` documents the envelope; `encode_envelope_ssz` emits `flags0 |= 0x02` and a 32-byte big-endian slot after the parent beacon root only when `header_difficulty` is `Some(non-zero)` (`codec.rs:184-224`); decode mirrors it (`codec.rs:257-280`).
- Go (optimism fork) `op-service/eth/ssz.go:27,467-491,535-572` does the same (comments spell it "Uzen"); `types.go:212,270-273` rebuilds the header with `difficulty = HeaderDifficulty` when non-zero, otherwise 0. The gossip layer in `op-node/p2p` has no Unzen/HeaderDifficulty logic at all (grep returned nothing).
- Senders always populate it from the sealed header: Rust `handlers.rs:174-175`, `ingress.rs:276-280`; Go `util.go:71-73` (only when `> 0`), `util.go:104,131`.

## 6. Receiver validation: Rust vs Go differ

### Rust whitelist-preconfirmation-driver
- Every ingested envelope (topic `preconfBlocks` or `responsePreconfBlocks`) runs `validate_execution_payload_for_preconf` and then `validate_envelope_header_difficulty(chain_id, execution_payload.timestamp, header_difficulty)` before caching (`ingress.rs:135-152`).
- `validation.rs:105-132`: `present = header_difficulty.map(|v| !v.is_zero()).unwrap_or(false)`; `(unzen, present) == (true, false)` -> error "unzen active ... but envelope is missing header difficulty"; `(false, true)` -> error "unzen inactive ... but envelope carries non-zero header difficulty". This is a *presence* check keyed on the fork schedule, not a value check.
- The gossiped value is otherwise **not used to build the block**: `driver_payload_from_envelope` passes only the execution payload, tx list, parent beacon root, forced-inclusion flag and signature (`cache_import.rs:18-33`); the block is rebuilt through the normal engine round trip (`engine.rs:168-230`), where the EL recomputes zk gas and the driver reads it back from `blockValue`. If the resulting hash differs from the operator-signed `block_hash`, the envelope is purged from the response cache but the produced block still advances the unsafe head (`cache_import.rs:186-208`).

### Go taiko-client
- `pkg/preconf/` contains only `payload.go` (`ls`); the comment "see pkg/preconf/validation.go for the fork-gated presence check" (`payload.go:27-28`) points at a file that does not exist.
- `driver/preconf_blocks/*.go` never calls `rpc.IsUnzen` (grep count 0 in every file) and `ValidateExecutionPayload` checks only timestamp, fee recipient, gas limit, base fee, extra data, one compressed tx list, and the anchor tx (`server.go:956-1010`). `HeaderDifficulty` is only logged (`server.go:316`) and copied into `preconf.Envelope` (`server.go:1505`, `:1030`).
- `InsertPreconfBlockFromEnvelope` logs `envelope.HeaderDifficulty` (`common.go:672`) and then rebuilds the block from parent hash, timestamp, fee recipient, `PrevRandao`, extra data, base fee and tx list (`common.go:722-786`); `createExecutionPayloadsMetaData` has no difficulty field (`interface.go:28-41`). The returned header is the locally built block (`common.go:793`); no comparison with the envelope's `BlockHash` is made in that path.
- Net effect: on Go, an Unzen-era envelope with a missing/zero `HeaderDifficulty`, or a pre-Unzen envelope with a non-zero one, is accepted and re-executed; the only place the field matters for hash reconstruction is the optimism fork's `ExecutionPayloadEnvelope.CheckBlockHash`-style header rebuild (`types.go:270-273`), which the Go driver does not invoke on ingress. On Rust, the same envelopes are rejected before caching.

## 7. Doc vs code discrepancies (explicit list)

| Claim in docs | Reality in code |
| --- | --- |
| `Derivation.md:275` `metadata.difficulty = keccak(parent.difficulty, number)`; `:302` maps it to header `difficulty` | Both clients put that keccak into `mixHash`/`prevRandao` (`payload.rs:438-439`; `common.go:480`; `encoding/input.go:153-160`). Header `difficulty` is 0 pre-Unzen (`consensus.go:176-180`) and `block_zk_gas_used` post-Unzen (`taiko_worker.go:337-339`; `state_processor.go:195-201`). |
| `Derivation.md:47` difficulty is "a random number seed" | Post-Unzen it is an execution-dependent gas counter; the random-seed role belongs to `mixHash`, whose chain is now seeded by the parent's zk gas. |
| `Derivation.md:380` `SHASTA_FORK_TIME` "Hoodi/Mainnet: not scheduled"; no Unzen time listed | Shasta 1_770_296_400 (Hoodi) / 1_775_135_700 (mainnet); Unzen 1_781_787_600 / 1_786_021_200 (`taiko_genesis.go:22-28`; alethia-reth `hardfork.rs:74-75,84-85`). |
| `Derivation.md:163-165,368-369` only Unzen change is the 768 cap | Unzen also activates Cancun/Prague/Osaka header fields, bans blob txs, adds zk-gas truncation and the difficulty invariant (sections 2-3). |
| `zk_gas_spec.md` | Never states that `header.difficulty` carries the counter; the mapping is only in `payload.go:23-29`, `ingress.rs:276-278` and taiko-geth. |
| `payload.go:27` "see pkg/preconf/validation.go" | File does not exist; Go has no such check. |
| Question premise "fork timestamps live only in the external alethia-reth chainspec" | They also live in taiko-geth `core/taiko_genesis.go:22-28`; the two external schedules agree. Nothing in taiko-mono itself carries them. |

## 8. What cannot be answered from taiko-mono alone

- The authoritative zk-gas/difficulty rule for the Rust execution client (alethia-reth's block executor) is not in the repo; only its chainspec was read. taiko-geth's comments assert equivalence with "the Rust reference block-executor" (`state_processor.go:189`), which is unverified here.
- No test in taiko-mono asserts the Go receiver's behaviour on a mismatched `HeaderDifficulty` (Go tests only construct envelopes with `HeaderDifficulty: common.Big1`, e.g. `queue_test.go:23`, `cache_test.go:43`).

## Claims index

1. Unzen L1 side is Proposal0019 with no in-contract timestamp gating: `packages/protocol/script/layer1/proposals/Proposal0019.md:1-8,30-32`; only Solidity mention is a deprecation note `packages/protocol/contracts/layer1/mainnet/MainnetVerifier.sol:8,13`.
2. Rust fork tables come from alethia-reth: `packages/taiko-client-rs/crates/protocol/src/shasta/constants.rs:6-8,180-190`; pinned rev `packages/taiko-client-rs/Cargo.toml:77`, `packages/taiko-client-rs/Cargo.lock:69-71`.
3. Rust Unzen activation predicate and error/`Never` handling: `constants.rs:234-242`; fork condition lookup with devnet override: `constants.rs:65-80,203-213`; CLI flag `packages/taiko-client-rs/bin/client/src/flags/common.rs:87-94`, applied at `bin/client/src/commands/driver.rs:54`.
4. alethia-reth schedule (external, rev 0fb47d9): `crates/chainspec/src/hardfork.rs:74-75` (mainnet Shasta 1_775_135_700, Unzen 1_786_021_200), `:84-85` (Hoodi 1_770_296_400 / 1_781_787_600), `:94-95` (devnet 0/0), `:114-123,147-150` (Cancun/Prague/Osaka = Unzen).
5. Go activation predicate: `packages/taiko-client/pkg/rpc/engine_unzen.go:14-22`; taiko-geth `params/config.go:504,919-922`; schedule `core/taiko_genesis.go:22-28,43-48,55-59,65-70` (module `/root/go/pkg/mod/github.com/taikoxyz/taiko-geth@v1.18.1-0.20260924044618-8e98046bfd6a`, pinned by `/home/user/taiko-mono/go.mod:308`).
6. Derivation.md statements: `packages/protocol/docs/Derivation.md:47` (random seed), `:163-165` (cap), `:275` (difficulty formula), `:302` (header mapping), `:314` (mixHash), `:368-369` (constants), `:380` (SHASTA_FORK_TIME not scheduled).
7. Rust mixHash computed from parent header difficulty: `packages/taiko-client-rs/crates/driver/src/derivation/pipeline/shasta/pipeline/payload.rs:438-439`, helper `packages/taiko-client-rs/crates/protocol/src/shasta/payload_helpers.rs:29-35`, used at `payload.rs:467,513`, checked at `payload.rs:836-839`.
8. Go mixHash computed from parent difficulty: `packages/taiko-client/driver/chain_syncer/event/blocks_inserter/common.go:480`; `packages/taiko-client/driver/preconf_blocks/api.go:168-171`; `packages/taiko-client/bindings/encoding/input.go:153-160`; fed to engine at `common.go:133-143`.
9. EL difficulty rules: taiko-geth `consensus/taiko/consensus.go:176-183` (zero pre-Unzen, `verifyUnzenHeaderFields` after), `:249-279` (Unzen header fields), `:295-303` (`Prepare` sets 0), `:314-334` (`Finalize`), `:366-385` (parent beacon root required, blob txs banned), `:427-429` (`CalcDifficulty` = 0).
10. Difficulty = zk gas used: taiko-geth `miner/taiko_worker.go:263-266` (meter gated on `IsUnzen`), `:297-309` (truncate on limit), `:337-339` (set difficulty); `core/state_processor.go:88-98` (meter + blob ban on import), `:140-155` (truncate), `:186-201` (body-length and difficulty invariants).
11. zk-gas constants and schedule: taiko-geth `core/vm/taiko_zk_gas_unzen.go:10,16,20-45`; `core/vm/taiko_zk_gas.go:27-47`; spec `packages/protocol/docs/zk_gas_spec.md:11-12,113-134,417-434`; spec has zero occurrences of "difficulty".
12. Rust canonical-block fork-gated checks: `payload.rs:775-807` (inside `verify_canonical_block`, `payload.rs:674`); Go equivalent `common.go:372-408`.
13. Engine API transport of difficulty: taiko-geth `beacon/engine/types.go:135,139-143,348-374,443-447`; `eth/catalyst/api.go:839-841,951-969`; Go driver `packages/taiko-client/pkg/rpc/engine.go:100-110`, `engine_unzen.go:43-62`, `packages/taiko-client/driver/chain_syncer/beaconsync/syncer.go:100-101`; Rust `packages/taiko-client-rs/crates/driver/src/sync/engine.rs:232-282`, `packages/taiko-client-rs/crates/rpc/src/auth.rs:58-65,71-86`, `packages/taiko-client-rs/crates/driver/src/sync/beacon.rs:127,143-146`.
14. Derivation cap selection: Go `packages/taiko-client/bindings/manifest/manifest.go:17-20`, `engine_unzen.go:25-31`, `packages/taiko-client/driver/chain_syncer/event/derivation/source_fetcher.go:149-157`; Rust `constants.rs:22-25,244-252`, `packages/taiko-client-rs/crates/driver/src/derivation/pipeline/shasta/pipeline/mod.rs:375-376`; proposers keep 192: `packages/taiko-client/proposer/proposer.go:320-324`, `packages/taiko-client-rs/crates/proposer/src/transaction_builder.rs:110-116`.
15. Gossip envelope format: Rust `packages/taiko-client-rs/crates/whitelist-preconfirmation-driver/src/codec.rs:28-44,184-224,257-280`; Go optimism fork `op-service/eth/ssz.go:27,467-491,535-572`, `op-service/eth/types.go:212,270-273` (module `/root/go/pkg/mod/github.com/taikoxyz/optimism@v0.0.0-20260420065638-5490c5186828`); no HeaderDifficulty/Unzen logic in `op-node/p2p`.
16. Senders populate HeaderDifficulty from the sealed header: Rust `whitelist-preconfirmation-driver/src/api/service/handlers.rs:174-175`, `importer/ingress.rs:276-280`; Go `packages/taiko-client/driver/preconf_blocks/util.go:71-73,104,131`.
17. Rust receiver presence check: `whitelist-preconfirmation-driver/src/importer/validation.rs:105-132`, invoked at `importer/ingress.rs:135-152`; gossiped value not used for building: `importer/cache_import.rs:18-33`; hash-mismatch purge: `cache_import.rs:186-208`.
18. Go receiver has no gate: `packages/taiko-client/pkg/preconf/` contains only `payload.go` (comment at `payload.go:23-29` references missing `validation.go`); zero `IsUnzen` calls in `packages/taiko-client/driver/preconf_blocks/*.go`; `server.go:956-1010` (`ValidateExecutionPayload`), `:316`, `:1030`, `:1505` (logging/copying only); `common.go:672,722-786,793`; `packages/taiko-client/driver/chain_syncer/event/blocks_inserter/interface.go:28-41` (no difficulty field).
19. Go tests only build envelopes with `HeaderDifficulty: common.Big1`: `packages/taiko-client/driver/preconf_blocks/queue_test.go:23`, `cache_test.go:43`.
20. Prior audit note flagging the same doc/code contradiction: `packages/protocol/docs/Etna/00-current-protocol-summary.md:431-432`.
