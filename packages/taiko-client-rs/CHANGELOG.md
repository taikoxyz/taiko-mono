# Changelog

## Unreleased

### Etna specification alignment (#22422)

- **BREAKING:** the consensus parameters follow START-10-21: `block.max_bytes` = 1,572,864 + 4,096 × n_max (2,097,152 at n_max = 128), no gas limit, evidence age limits of 16 blocks and 3 min, and zero evidence bytes in every block (CONS-3.1-10). The initial and recovery genesis, InitChain, the recovery plan check and checkpoint import (the header consensus hash and the per-block byte bound) take them from the deployment's n_max, and import windows follow the shorter age limits. Older geneses are refused. `etna-comet-import install` takes the authenticated `--n-max` and refuses a genesis with other parameters.
- A rotation's FinalizeBlock returns only the difference from the set in force (COMM-4.3-13): a leaver at power 0, a new member or changed power at its new power, and no entry for an unchanged key and power. Stock CometBFT reaches the same validator state, so valStateHash is unchanged.
- **BREAKING:** the committee record commits its members with one ABI hash, `setHash = keccak256(abi.encode(bytes32("ETNA_SET_V1"), l2ChainId, k, SetMember[]))` (ENC-A-39a), instead of the tagged Merkle set root, so every record hash changes. `CommitteeRecord::set_root` is now `set_hash`, also in the persisted app state, lander journals, recovery plans and the `abci-committee-record --json` report. App state moves to schema 21 and lander journals to schema 20; older ones are refused.
- **BREAKING:** Etna headers derive their EIP-4396 base fee with a 4 s block-time target (ENC-A-10a), for every Etna block including S + 1; Unzen derivation keeps alethia-reth's 2 s. `protocol` adds `ETNA_BLOCK_TIME_TARGET` and `calculate_next_etna_block_eip4396_base_fee_for_parent`. The execution engine must apply the same target.
- **BREAKING:** the selection minimum is the registry's immutable `minStake` (COMM-4.3-3, START-10-12/14): `ChainParams::s_min` is now `min_stake`, eligibility is `effStake >= min_stake`, the committee config hash takes it as its fifth word, and `validate` requires `min_stake >= vp_unit` and `4096 × min_stake > 10^27`. The chain-config TOML key `s_min` and the recovery plan's `deployment.s_min` are now `min_stake`; old keys are refused. The devnet built-in minimum is 4,700,000 TAIKO, the devnet registry default (`DEFAULT_REGISTRY_MIN_STAKE`, so K = floor(10^27 / minStake) = 212 fits the measured recovery capacity F = 212), and the unit, real-contract and Docker fixtures stake at least that per validator.
- Registry witnesses follow COMM-4.3-2 and ENC-A-38: a checkpoint count above 4096 and a nonempty entry list ending in an empty slot are refused, interior empty slots are the all-zero entry, and the count can shrink after withdrawal (STAKE-4.1-36). `RegistryEntry::is_empty_slot` and `committee::MAX_REGISTRY_SLOTS` are new in abci and etna-core.

### Checkpoint trust, signing gate and anchor finality (Etna specification #22422)

- A trusted node follows the Inbox's latest checkpoint and `recoveryGeneration` in its own finalized L1 view, whether or not a proposal adopts them (SYNC-9-6a). A checkpoint above the last matched one, read there or proven by a proposal's or a committed block's anchor, makes trust `catching_up` until the node has reached it and its EL hash and slot 285 record (read at the same finalized L1 block, retried there while unavailable) match; a match restores trust without an operator. A conflicting EL or Comet hash, or a larger generation, revokes trust at once: `/trust` reports `halted`, nothing more is signed, the process keeps running and the generic fatal record makes the next start refuse. An unavailable latest-checkpoint read keeps the matched result, and pauses those reads for 1 s doubling up to 30 s; a failed read never clears a pending target.
- Trust compares the EL hash alone while the latest checkpoint is the generation's origin (S or a recovery origin c) and both hashes from the first landing on (SYNC-9-5, RECOV-8.4-14a). The EL hash is compared as soon as the node holds the target height, so a startup mismatch halts even while the slot 285 record is unavailable.
- **BREAKING:** the trust snapshot (`/trust` and the private control socket, schema still 1) gains `eligible_height`, set exactly while `ready` to the durable committed boundary plus one (SYNC-9-10), and `target.comet_hash` is `null` until the slot 285 record is read; `target` also carries `forced_head`.
- **BREAKING:** on a switching network every trust grant checks that `fork_timestamp` equals the switching EtnaInbox's immutable `etnaForkTime()`, read by `eth_call` at the finalized L1 block's hash (SYNC-9-5a). The L2 SignalService `beaconRootsFrom()` check and `Engine::beacon_roots_from` are removed.
- CONS-3.4-16: a proposal whose anchor proves a checkpoint above the parent leaves trust catching up until the chain reaches it, and one whose hash conflicts at a held height revokes trust. The proposer no longer falls back to its parent's anchor on such a checkpoint: it proposes nothing, and `abci_proposal_fallbacks_total{reason="checkpoint_conflict"}` is no longer counted.
- `ProcessProposal` rejects at once an anchor its own L1 node has not finalized, including when that node is unreachable or times out, instead of waiting (CONS-3.3-5, RECOV-8-5); a decided block's `FinalizeBlock` still waits. The proposer keeps its parent's anchor for `--anchor.hold` (`ABCI_ANCHOR_HOLD`, default 12 s; `AppOptions::anchor_hold`) after its own L1 first shows a newer finalized block, while that anchor stays fresh and within back-pressure (CONS-3.3-4).
- The app worker checks a newly begun signer session or a newly pending target before its next queued request, so a session the signer begins before Comet's handshake `Info` is verified before stock replays a refused step (SYNC-9-12).
- The app establishes the boundary it reports before it opens its ABCI socket, independently of `Info` and every later CometBFT callback (CONS-3.1-9): with signing closed, it re-executes the committed blocks the EL lacks from its retained execution bodies and checks the EL's canonical hash at the committed head (and an imported store's execution floor). Missing material is reported with the height that lacks it (the new `AbciError::ExecutionInputMissing`, the trust reason and the log) and retried without opening the socket; a contradiction is a safety halt that records fatal evidence and runs the halt hook before CometBFT can connect (`ServerError::Alignment`). Stock CometBFT keeps retrying its ABCI dial meanwhile. The handshake `Info` of each later connection set still reconciles as a defense. `AbciHandler::align_before_serving` is new.
- `Commit` and the handshake `Info` log the height, app hash, local EL hash and validator-state hash (`abci::AppHashReport`), what an operator compares with a header AppHash after CometBFT stops on a mismatch (SYNC-9-5c).

### Guarded signer and supervisor for the Etna specification #22422

- The signer accepts only `unix://` and stock `noise://<comet-peer-id>@<ip>:<port>` transports and refuses bare `tcp://` (START-10-6). Noise pins both peer IDs: Comet's listener pins the signer's transport key, and the signer pins the libp2p ID of Comet's persistent node key. `etna-signer transport-keygen --transport-key P` creates the transport key and prints its peer ID; serving with Noise takes `--transport-key`. The supervisor derives both IDs from `ETNA_SIGNER_TRANSPORT_KEY` and `<comet-home>/config/node_key.json`, and requires a Unix `run/` of mode 0700.
- The signer always connects to Comet promptly and answers PubKey and Ping while trust is closed; `--await-trust` is removed. A connection whose session the app cannot begin is exposed without one, and its first signing request begins it. A pending trust decision is held for at most 3.5 s, polling every 100 ms (SYNC-9-6a), so a restarted Comet's replayed step is signed once the fresh session passes; a halted app, another chain ID and another height are refused at once (SYNC-9-12).
- Ready trust replies carry `eligible_height`, the only height the app admits for signing: the one after its durable committed boundary, `initial_height` before the first commit, or s + 1 after a 5.4 import at s. The signer refuses every other height, and a ready reply without it, before FilePV changes the HRS (SYNC-9-10). The app must add this field to its trust snapshot.
- The supervisor restarts the signer and Comet together after a refusal once trust is Ready, and again after another refusal; a crashed signer restarts with its pair. A Comet that exits before the signer connected, as after a missed 3 s accept of the first GetPubKey, is started again with the same signer state and no latch. A session the app replaced no longer restarts Comet.
- Validators must run `p2p.pex = false`, `p2p.max_num_inbound_peers = 0`, `p2p.unconditional_peer_ids` equal to `ETNA_P2P_INBOUND_PEER_IDS`, no seeds or seed mode, `rpc.unsafe = false` and the stock (non-libp2p) switch (START-10-6, LIMIT-12-2). Every pinned setting is checked at its effective values: each config.toml spelling, every `CMT_*` override and no Comet argv flag; a `CMTHOME`/`TMHOME` off the configured home is refused.
- The supervisor deletes the pending-evidence store, `<db_dir>/evidence.db`, with Comet stopped before every Comet start, and nothing else (CONS-3.1-10, LIMIT-12-22).
- The full-node launcher `script/start_etna_full_node.py`, which sentries use too, makes the same two checks before it execs Comet, holding its writer lease: the executable's sha256 must be the one `comet-manifest.json` (or `ETNA_COMET_MANIFEST`) pins for the platform (CONS-3.1-1), and `<db_dir>/evidence.db`, and nothing else, is deleted (CONS-3.1-10, LIMIT-12-22). It execs the exact file it hashed. The shared checks live in `script/etna_comet_guard.py`, which the image and the recovery runtime stage beside the launcher; an `ETNA_COMET_MANIFEST` is now required wherever a full node runs a non-official build.
- Validators run the official CometBFT v0.40.0 executable (CONS-3.1-1). `comet-manifest.json` pins, for linux/amd64, `/usr/bin/cometbft` of `cometbft/cometbft:v0.40.0` (index `sha256:0703fb88…`, platform manifest `sha256:53421974…`) by its sha256 `5fbb1bf5…`, with the source commit, build recipe, flags and enforced configuration; the image copies that executable and the supervisor checks its digest before every Comet start (`ETNA_COMET_MANIFEST` names another manifest). linux/arm64 is unsupported for validators: upstream's release has no assets and its arm64 image holds the same x86-64 executable, so the arm64 image keeps a development source build that the supervisor refuses. `script/build_stock_comet.sh` copies the official executable on linux/amd64 and otherwise writes a test manifest for its source build.

### Signer continuity (Etna specification #22422)

- **BREAKING:** the signer state is schema 2 (RECOV-8.2-1/2): stock FilePV's HRS fields plus, in the same file and the same atomic write, `schema`, `chain_id`, the bound `store_instance`, the height `floor` and the last signature's `replay` binding. `init-state` writes the unsigned schema-2 state. The stock FilePV state of earlier signers and every other schema are refused with exit 3, without migration. The signer applies stock FilePV's HRS rules through stock `CheckHRS`, sign bytes and extension signing (checked against stock FilePV request for request) and writes the state itself, still under the durable inflight marker, so a step still costs four fsyncs.
- **BREAKING:** `etna-signer` requires `--supervisor-socket`: the supervisor's private channel in its run directory (`ETNA_SUPERVISOR_RUN_DIR`, default `<app-store>/supervisor`, mode 0700), authenticated both ways by kernel peer credentials (RECOV-8.2-2, START-10-6). Over it the supervisor reports the Comet process it started (PID and kernel start time) and the home's store instance ID; on a Unix transport the signer checks that the connection's listener is that process.
- Every Comet home carries a store instance ID in `data/etna-store-instance` (32 lowercase hex characters, mode 0600). The supervisor writes a fresh one before starting a home without one, `etna-comet-import install` and `abci-import` write one into every imported home, and `abci-recover install` into every recovered generation's home (it keeps its own on an interrupted rerun).
- For a key that has signed at H, the first signing request of a session with a changed or absent store binding, or with a Comet process other than the one this signer last admitted (any restart of the pair), durably raises the minimum signable height to H + 1 before anything is signed; it never decreases and refuses proposals, nil votes and retries alike, without restarting Comet. A never-used key binds to the store instance first. A restart on the same store instance resumes the last signed height only through a confirmed same-height replay (below).
- Same-height replay (RECOV-8.2-2, SYNC-9-12/13): every fresh signature records its replay binding (the predecessor's `#ENDHEIGHT` marker, the predecessor block hash and the length and SHA-256 of the flushed WAL bytes after the marker), which the supervisor computes with `etna-signer wal-binding` run as the Comet UID; the signer never reads Comet's files. Before each pair start the supervisor checks the saved binding against the stopped stores and WAL with stock `SearchForEndHeight` and the stock decoder (`etna-signer wal-preflight`, `comet-head`, goleveldb stores only) and pins the startup prefix. In the replay that its log observer sees opening, the request repeating the saved vote (stock's timestamp-only retry included) gets the saved signature and confirms it, and higher HRS at that height are then signed and bound to the startup prefix. Without confirmation fresh signing at that height stays closed; an unconfirmed request outside the replay, a missing marker, a damaged prefix or other stores raise the floor. A torn WAL tail after the bound input keeps the height closed while stock repairs it, and the supervisor then restarts the pair. Independent confirmation of a restored round and lock is not implemented: after a proposal, the height stays closed.
- `etna_validator.py stop-on-precommit [--timeout S]` arms the running supervisor's signer for a planned ruleset upgrade during a pause (START-10.1-14b, RECOV-8.2-2): the signer persists and returns its next precommit, nil or block, as its last signature and refuses every later request, or closes at once when its last signature already is a precommit; the supervisor then stops Comet and the signer, records the outcome in `stop-on-precommit.done` and stays quiescent. The supervisor channel gains the `stop` and `stopped` ops.
- The supervisor's log observer (START-10-6) needs `log_format = "json"` and the consensus module at Info, without argv overrides: it then owns a fresh pipe for each Comet process's stdout, forwards every line to its own stdout and follows `Catchup by replaying consensus messages`, `Replay: Done` and the WAL repair and replay-error records. Any other setting is reported at startup as `etna_supervisor_log_observer_disabled` and keeps same-height replay closed, so every restart fences the last signed height.

### Contracts, execution engine and switch for #22422

- **BREAKING:** pin the protocol to #22286 at `2f496d31b` and regenerate the lander artifacts, the SignalService binding (`usesBeaconRoots` replaces `beaconRootsFrom`) and the shared vectors, now schema 9; the vector tests refuse schema 8. The real-contract fixtures follow the new ABI: the EtnaInbox `Config` drops `originWriter` and adds `recoveryCapacity` (the devnet default F = 212), `CommitteeConfig` drops `sMin`, `recover` takes strictly increasing bond ids as exclusions, `scheduleRules` and `scheduleStop` take the expected generation first, `forfeit` takes a bond id and the SignalService constructor takes `bool usesBeaconRoots`. The vector tests check ENC-A-39a set hashes and the registry checkpoint sequence whose count shrinks after withdrawal.
- The Etna start is written once (START-10-5c): corrected switching starts are gone. Generation zero's origin must name S, every recovery witness must show the deployment's start, hash and state root unchanged, and a recovery at c = S starts from the start write's own anchor. A recovery in the start write's L1 block, whose deployment proof at `L1_0` already shows the next generation, is accepted.
- The lander builds the first landing from S without reading the Unzen Inbox: the permissionless start write `setOrigin(S)` already requires closed, fully proven Unzen proposals (START-10-5a, LAND-6.1-8a), and `land` no longer checks Unzen state. Checkpoint import at s = S still compares the SignalService checkpoint at S with the start record (DATA-5.3-4). The [handoff runbook](docs/unzen-etna-handoff.md#writing-the-etna-start) shows the start write as `cast send … 'setOrigin(uint48)' S` from any account.
- Pin alethia-reth to #248 at `ad58432` (a 4 s EIP-4396 target for every Etna block, base-fee sharing 100). `protocol` re-exports its `ETNA_BLOCK_TIME_TARGET` and `SHASTA_BLOCK_TIME_TARGET` and takes the target from its `block_time_target`. The Dockerfile's EL source build, the default EL image tag, the EL import helper and the Docker harness's EL inputs follow.
- `abci-recover install` also refuses a validator template without the P2P pins (START-10-6, LIMIT-12-2): `p2p.pex = false` and `p2p.max_num_inbound_peers = 0` set explicitly, and no seeds, seed mode, unsafe RPC or libp2p switch.
- The Docker harness connects each validator's signer over Noise (`noise://<signer-peer-id>@…`, one `transport-keygen` key per validator) instead of bare `tcp://`, writes the validator P2P settings with the other validators as the only, unconditional, inbound peers and passes them as `ETNA_P2P_INBOUND_PEER_IDS`. Its supervisors check Comet against a test `ETNA_COMET_MANIFEST`: one pinning the `/bin/sh` container wrapper in Docker mode, and `script/build_stock_comet.sh`'s for a native source build.

### Checkpoint import for the Etna specification #22422

- Checkpoint import refuses evidence in the window: every Comet block has an empty evidence list (CONS-3.1-10), so a window block whose header commits evidence is an authenticated contradiction once the landed chain links it and halts the import, and one off the landed chain rejects the package (DATA-5.4-2/5). `etna-comet-import` refuses a window block with evidence too. The window rule is unchanged under the new limits: every height within 16 blocks or 3 min of s, by Comet header times, the latest anchor carrier and the committee switch and derivation heights, ending at the origin or at a w past both limits.
- `etna-comet-import install` creates the evidence database empty and no longer records committed-evidence markers or runs a temporary stock pool. It writes s's own commit under the block-commit key C:s as well as the seen commit SC:s, so stock light-client evidence verification at height s finds its signed header. Every full validator set it stores, historical ones included, must pass stock `ValidateBasic`, store a member as proposer and survive a protobuf round trip. Before publication it checks, at every window height, stock `LoadBlockMeta`, `LoadBlockCommit` and the validator lookup against the authenticated header and time, the height's own commit and its set, stock `LoadValidators` at every stored full set and every height still inside the evidence age limits, and an empty evidence database (DATA-5.4-3). The import package format is unchanged at schema 2.
- `etna-comet-import repair-first-block` repairs a home whose stock handshake stops on a generation's first block when `initial_height` is above 1 (CONS-3.1-9): run offline with Comet stopped, the signer fenced and the app serving `--app`, it copies `data/` to `--backup`, writes a fresh `data/etna-store-instance`, verifies the stored block and seen commit (or a `--peer-export` from `export-first-block`) against the genesis chain_id, height, empty evidence and more than 2/3 of the genesis committee's power for the full BlockID, and applies exactly that block with the stock handshake's own steps (InitChain and `ApplyBlock` against the app, or the replay of the kept FinalizeBlock response when the app already committed). It never accepts another block for the height; a contradiction exits 2. The runbook covers the single-node and committee-wide cases (`docs/first-block-repair.md`).
- `repair-first-block` no longer applies the first block with a damaged seen commit: when the stored seen commit does not certify the stored block, a `--peer-export` commit for the same BlockID that does is installed as the seen commit (`"source": "peer_commit"`), and without one the repair stops. Every refusal (store shape, certificate, the app's height and kept response) now precedes the first store write and app call; a failure after the first write leaves a block store that a rerun completes from, and a rerun after the state was saved also replaces a damaged seen commit from a peer export (CONS-3.1-9).
- `repair-first-block` writes the fresh store instance ID only after every check passed and immediately before it changes the stores, so a refused repair and a rerun that only checks no longer fence the signer; its report's `store_instance` is empty when the run changed nothing (RECOV-8.2-2).
- `etna-comet-import verify-export` compares the stored proposers of the stock snapshot's `Validators` and `NextValidators` in full (key, power and priority), not only their addresses (DATA-5.4-8).

### Etna specification simplification (#22412)

- `app_hash` is appHash(blockHash, valStateHash): the block's EL hash and the CometBFT validator state after it (CONS-3.1-8, ENC-A-29b). InitChain, FinalizeBlock, Info, every genesis document and an imported node's stock stores use it; proof-side block checks no longer compare it with the parent EL hash (PROOF-6.2-42).
- Checkpoint trust compares only the EL and Comet hashes of the three-word slot 285 record (SYNC-9-5); it no longer compares or waits for a landed validator state.
- Landings end at any height above their parent: the statement has 21 words (672 bytes), `LandInput` has 8 fields, and the cut list holds one four-word leaf per height in (p, h), none when h = p+1. A competing landing at c is checked at leaf c−p−1.
- The batch cap is min(`--max-blocks`, `maxBatchBlocks`) with no rounding, and any U in 1..=65,536 is accepted.
- `scheduleStop` takes one `uint48` time, and a planned stop refuses every block whose parent's timestamp is at or after it, at any height.
- The app records the validator state at every committed height and keeps the records from one height below the trust checkpoint; `/val_state/<h>` answers any retained height. The lander no longer queries it and drops `lander_validator_state_mismatches_total`.
- Checkpoint import takes the validator-state preimage after s − 1, checks it against header(s)'s app_hash and validator hashes, and applies block s's updates once (DATA-5.4-3). Packages use schema 2; export reads `/val_state/<s−1>` or the archive, which now keeps every height.
- Registry reads follow lowest-empty-slot admission (STAKE-4.1-14a).
- Pin the protocol to `7cd9606af6` and regenerate the lander artifacts and the schema-8 shared vectors. The conformance record maps the specification at `2e6763e21b`.
- Bump the app state from schema 19 to 20 and lander journals from 18 to 19.
- etna-core: `verify_body_at_origin`, `verify_structure` and `verify_structure_at_origin` drop the `parent_el_hash` parameter, and `GRID_INTERVAL` and `GenesisRecord::is_grid_height` are removed (from abci too). Callers must adapt.

### Exact landings for the import producer check

- `taiko-client lander --land-to <HEIGHT>` lands exactly one batch from the latest checkpoint to HEIGHT through the normal selection, leaves and journal, without the batch collection wait, and exits 0 once that landing is confirmed. It exits nonzero when the latest checkpoint is or becomes at or above HEIGHT, when HEIGHT lies more than the batch cap above it, when the blocks do not fit one batch, or on a signal. It has no environment variable.
- `etna-comet-import snapshot-height --comet-state-dir DIR` prints the height x of a stopped stock state snapshot as JSON. An import producer lands x + 1 with `--land-to` and exports that checkpoint, so its snapshot is exactly at s − 1 (DATA-5.4-8, [procedure](docs/checkpoint-import.md#stock-snapshot-for-the-producer-check)). `verify-export` names both heights when the snapshot is at another height.

### Recovery from a settled chain that differs from the node's own

- Recovery InitChain points the EL at c's authenticated hash, as at the Etna start, before it compares c. An EL that holds another block at c or at c − 1, or none, is missing data: InitChain waits with trust closed and retries, instead of halting, until the EL serves the settled blocks (RECOV-8.1-7, RECOV-8.1-8, SYNC-9-7). An EL that rejects that hash, accepts it and keeps serving another block, or answers the read of c with a header of another height or hash still halts.
- `abci-recover prepare` reports an EL without the settled block at c as a missing prerequisite that names c and the landing's EL hash and points to the runbook, instead of invalid evidence. The lander waits on the same condition as a temporary failure. The [runbook](docs/governance-recovery.md#take-the-settled-el-state-at-c) describes how a node takes the settled EL state at c.
- abci: `RecoveryError::OriginNotHeld` is new, and `authenticate_recovery_with_headers` readers return `Option<Header>`. Callers must adapt.

### Switch checks and node requirements

- A nonzero Etna start without a `[switch]` configuration keeps checkpoint trust closed at every checkpoint, not only while the latest checkpoint is S: without it the node cannot check its own fork time against the built-in L2 SignalService implementation's `beaconRootsFrom()` (SYNC-9-5a). Before, trust opened after the first landing without that check.
- The [handoff runbook](docs/unzen-etna-handoff.md) and README now state two node requirements on a switching network: alethia-reth must run with exactly the client's Etna time, which no RPC reports, and until the first landing is final every `--l2.http` endpoint of the app and the lander must serve `eth_getProof` at S (reth's `--rpc.eth-proof-window` is 0 by default; use at least `unsettled_limit` blocks plus a margin, or an archive endpoint) (SYNC-9-16).

### Protocol artifact alignment

- Align the ABI/artifact provenance with the published switch contracts in PR #22286, which closes the L2 checkpoint store with `beaconRootsFrom` and removes `SignalServiceL1`. The protocol pin, first at `4c6424bc`, now follows #22412 (above).
- Regenerate Inbox, Anchor, PreconfWhitelist and SignalService bindings with workspace Alloy; remove the retired, unused LookaheadStore binding.
- Reproduction checks now include the legacy generated bindings. This alignment changes neither signed journals nor persisted app state.

### Unzen driver and Etna handoff

- Restore the Unzen sync/derivation driver and its CLI, protocol/RPC dependencies and generated bindings.
- Add `etna-handoff` to drain finalized Unzen derivation before serving Etna ABCI at S+1.
- Add authenticated nonzero ABCI starts with committee 0 and the unchanged global epoch schedule.
- Authenticate the switch with the L2 SignalService proxy's implementation slot at S, and check before every trust grant that the built-in implementation's `beaconRootsFrom()` equals the configured fork time (SYNC-9-5a). The `[switch]` key `anchor_implementation` is now `signal_service_implementation`.
- Add the shared `--engine-control-dir` Engine writer lease. Mount the same directory for every local controller of one EL.
- Pin alethia-reth to PR #248 head `53f33b70` with OP Reth `op-v2.7.0-1`.
- Support nonzero-S landing, cut leaves and overlaps above S, committee 0 bootstrap and authenticated Unzen ancestry.
- Retain the first landing's raw L2 SignalService implementation witness for the proof backend.
- Support nonzero-S checkpoint import/export, deriving the original EL block-zero identity from the operator-selected runtime chainspec.
- Bump lander journals from schema 16 to 18 for the additional private proof witness, the L2 SignalService implementation proof at S. Older journals, including schema 17's Anchor witness, are refused without migration; resolve outstanding signed transactions with the compatible lander before upgrading.


### ⚠ BREAKING CHANGES

Etna is unlaunched, so start a fresh devnet: the app state (schema 21), validator-state records,
lander journals (20), checkpoint import packages (schema 2), private trust control (schema 1)
and the signer's state layout are new, and older stores are refused, never migrated
(START-10-24). Regenerate older geneses with `abci-genesis`: InitChain and `etna-comet-import`
refuse CometBFT's default evidence limits (START-10-21).

- The lander's `--max-blobs` (`LANDER_MAX_BLOBS`) and the app's `--l1.archive`
  (`ABCI_L1_ARCHIVE`) are removed. A removed flag is now an unknown argument, so a deployment
  that still passes it crash-loops; a removed environment variable is ignored. The lander uses
  one to six blobs per landing (cap fixed at six), and the own L1 node serves the committee
  history a validator needs (SYNC-9-16).
- `etna-signer` serves one chain_id and requires `--chain-id`, `--priv-key`,
  `--priv-state <state-dir>/<chain_id>.json` and `--domains-log`; the authority-root flags are
  gone. Before the first start, run `etna-signer init-domains-log` once per key, and
  `etna-signer init-state` once per chain_id with the signer stopped, again for every recovered
  generation's new chain_id. Nothing else creates signing state (RECOV-8.2-1). Exit codes are 0
  (signal stop), 1 (configuration, transport or lock error), 2 (Go panic; no signature released)
  and 3 (signing state lost or uncertain, RECOV-8.2-3). See the
  [signer README](tools/etna-signer/README.md).
- `/trust` and `/status` no longer report `trust_ready` or `syncing`. Read readiness from `phase`
  (`/trust` and private trust control) or `trust_phase` (`/status`); only `ready` is ready
  (SYNC-9-15).
- `abci-import export`, `import` and `status` replace the multi-step import. `import` publishes
  ordinary `ROOT/ready/{app,comet,el}` stores, which the plain `abci`, EL and Comet processes
  run. `prepare`, `install`, `run-app`, `check-runtime` and the JSON `--profile` are gone.
- `abci-recover prepare`, `install` and `status` replace `activate`. The operator stops and
  starts services; nothing in the client fences them (RECOV-8.2-6).
- The validator supervisor needs `ETNA_PRIV_STATE_DIR` and `ETNA_DOMAINS_LOG`. In Unix-socket mode
  (a `unix://` `priv_validator_laddr`) it also needs an existing `<comet-home>/run/` owned by the
  Comet UID; TCP mode needs no `run/`. It restarts a signer that exits on its own (0, 1, 2 or a
  signal) without a fence (SYNC-9-12, SYNC-9-14). Five such exits within 600 s latch, and so
  do exit 3, a `<state>.uncertain` fence and a signer it had to SIGKILL on stop. These three also
  leave `validator-supervisor.signer-unsafe` in the app store and `<chain_id>.signer-unsafe`
  beside the domains log, which the supervisor and the signer refuse until an operator repair;
  a new app store never clears them (RECOV-8.2-3). Before stock FilePV writes, each signing
  step makes `<state>.inflight`, naming the kernel boot, durable (four fsyncs per step in all).
  A signer that dies during a step leaves it; a restart on the same boot refuses it with exit 3,
  and one after a reboot ignores it.
- The lander stops on any canonical revert at confirmation depth, out-of-gas included; a
  restart rebuilds from the current checkpoint. The `--max-batch-wait` timer lives in memory, so
  a restart starts the wait again.
- Upgrade the app, the supervisor and `etna-signer` together. Private trust control has one
  schema, whose replies always carry `recovery_origin` (null for generation zero), and the signer
  and the supervisor read readiness only from `phase`. In a mixed deployment the signer refuses
  to sign or trust control fails closed.
- Two configurations that started before are now refused at start. `etna-signer` rejects a
  `--trust-timeout` above 2 s with exit 1 (it accepted up to 10 s; SYNC-9-11), and the validator
  supervisor and `abci-recover install` refuse a validator `config.toml` whose
  `[blocksync] adaptive_sync`, `[consensus] double_sign_check_height` or
  `[consensus] block_time_tolerance` differs from its stock default (`false`, `0`, 60 s), naming
  the setting (START-10-6). An imported store also re-checks that the own EL serves the block and
  state at `execution_floor` at every CometBFT handshake, not once per app process, so that state
  must stay readable across Comet restarts.
- Metric and reason names follow the Etna spec's terms; update dashboards and alerts. The counter
  `abci_proposals_empty_total` is now `abci_proposals_placeholder_total`. In the `reason` label
  of `abci_process_rejected_total` and in `/status` `halt_reason`, `empty_proposal` is now
  `placeholder_proposal` and `landing_capacity` is now `block_size_bound`.
  The `trigger` field of the lander's "batch collection threshold reached" log line is now
  `back-pressure` where it was `backpressure`.

### Features

- Add authenticated bounded-window checkpoint import for fresh Etna generations and governance
  recovery. `abci-import export` collects a package from an archive node; `import`
  authenticates it against the node's own finalized L1 (DATA-5.4-2), installs the stock Comet,
  EL and app stores into a private stage and publishes them by one rename, and a rerun discards
  an interrupted stage (DATA-5.4-5); `status` reports on an import root. See the
  [checkpoint import runbook](docs/checkpoint-import.md).
- Verify imported validator signing and subsequent landing from both latest and older checkpoints,
  cold forced-inclusion replay, and native finalized ancestry beyond the BLOCKHASH window.
  Measure signed import windows, which the latest anchor bounds, with
  `just checkpoint-import-resources`.
- Derive the future validator sets, priorities and stored proposers from the authenticated
  s − 1 preimage, distinguish authenticated contradictions from incomplete input or subprocess
  failures, and retain an optional immutable preimage archive beyond live record pruning.
- Verify historical committee witnesses under the switch block's own anchor root while keeping
  the derivation parent's selected snapshot, including pending committees and recovery.
- Track the CometBFT validator state. The app computes stock CometBFT v0.40.0's validator
  sets, proposer priorities and stored proposers with its per-height arithmetic, records them at
  the generation's start and at every committed height in an immutable, checksummed
  `val-state-{height}.bin`, records the validator updates of every epoch switch height in
  `val-updates-{height}.bin`, and serves the state as the ABCI query `/val_state/<height>`.
  Below the height before the trust checkpoint it keeps the newest valid state record as the
  recompute base; a missing or corrupt record (set aside as `.corrupt`) is recomputed from an
  earlier record and the updates since (SYNC-9-5c). The app commits the state in its `app_hash`
  (CONS-3.1-8); landings do not carry it.
- Align with protocol `35e2f8f19` and the Etna specification of that time: authenticate slot 293,
  enforce ruleset selection/refusal and planned stops, and retain fixed recovery origins
  across later schedule writes. Reproduce schema-6 vectors and the updated recovery ABI.
- Read registry entries by slot independently of permanent bond IDs, including slot reuse;
  reject older app and lander stores without modifying their signed state.
- Add L1-authenticated governance recovery for validators and full nodes with usable local EL
  origin state. `abci-recover prepare` authenticates generation N, its origin c, R and the
  reselected committee on the node's own finalized L1 and writes a private plan file; `install`
  writes a fresh Comet home and an empty app directory; `status` summarizes a plan offline.
  Recovery keeps the registered key, every older chain_id's HRS state, old Comet history and
  immutable pending lander bytes, and the new generation's chain_id gets its own HRS state from
  `etna-signer init-state` (RECOV-8.2-5). See the [recovery runbook](docs/governance-recovery.md).
  The lander still uses dummy proofs; real proving, public EL snapshot
  distribution and production deployment acceptance are outside this change.
- Keep one stock HRS state per full chain_id in the signer, listed in a domains log on another
  volume, so a lost state or log is refused with exit 3 instead of looking like a fresh start.
  The log records chain IDs, never heights: restoring signing state from a backup stays
  undetectable and forbidden (RECOV-8.2-1, RECOV-8.2-6).

### Bug Fixes

- Re-pin the [conformance record](docs/etna-conformance.md) to the Etna specification at
  `d18357214fab30ea512ae9858a11699806d72ba1` (protocol #22348; superseded by `2e6763e21b`,
  #22412, above) and align with it. `Info`
  re-checks the EL at every CometBFT handshake, the first `Info` on each new set of ABCI
  connections, so a CometBFT restart under a running app never sees a height the EL does not
  hold (CONS-3.1-9). `etna-signer --trust-timeout` is at most 2 s, so a refusal is answered
  within 4 s, before CometBFT's fixed 5 s signer read timeout, and CometBFT gives up instead of
  retrying it (SYNC-9-11). Non-stock CometBFT validator settings are refused (START-10-6); see
  the breaking changes above.
- Replace empty derivation sources with a single default block before and after Unzen,
  matching the clarified source validation rules in protocol #22335. Regenerate contract
  fixtures and shared vectors from the protocol revision enforcing the strict bounty bound.
- Take the first recovered committee switch's registry snapshot at the fixed R across proposal
  deadlines. One background discovery, which PrepareProposal starts or joins, reads switch
  witnesses from the own L1, so a slow read never has to fit inside one proposal round; a
  verified witness is held in memory, and a restarted node discovers it again (SYNC-9-16).
- Authenticate proposal anchors before caching committee witnesses, and distinguish unavailable
  advisory L1 lookups from invalid anchor witnesses while keeping conservative publication
  urgency. The lander keeps its remembered tip anchor when a newer own-L1 lookup is unavailable.
- Persist the FilePV state file and its parent directory before returning any signature,
  cached HRS retries included (SYNC-9-13). A failed fsync withholds the signature, refuses every
  later request, writes the `<state>.uncertain` fence and exits 3; the fence refuses every
  restart, and the supervisor latches (RECOV-8.2-3).
- Restart Comet over its stale signer socket without CAP_FOWNER: every signer and Comet start
  meets at a fresh `<comet-home>/run/signer-<16 hex>.sock`.
- Start Comet together with a restarted signer while the app has not run InitChain, which only
  Comet can trigger, instead of waiting forever for trust.
- Recovery InitChain also requires the EL to serve the origin's state and waits with trust
  closed while it is missing, instead of reporting Ready and halting on the first block.
- Halt when the own L1's registry proof fails under its own state root, in committee-witness
  discovery or in a re-proof under the candidate anchor (SYNC-9-7); a peer's failing proof still
  only rejects its proposal. A background discovery's own-L1 integrity failure is kept and halts
  whichever handler sees it first, not only a waiting proposer.
- Treat an own-EL block that does not hash to the requested hash during startup and trust,
  such as in the recovery origin-state and import floor probes, as a contradiction that halts.
- A failed own-L1 registry proof halts only when the own L1 holds its anchor final; an endpoint
  that does not, as after a failover to one that is behind, pauses as missing data.
- Trust waits, instead of halting, while the own L1's finalized block precedes the Inbox's genesis
  L1_0 and the Inbox it reads is still empty, before InitChain and after it.
- Delete committed Comet block IDs below the committed anchor's checkpoint, which trust never
  reads, so the app directory stays within `unsettled_limit + 1` of them instead of growing one
  file per height until the volume runs out of inodes; trust re-acquires a checkpoint below it.

## [2.3.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-rs-v2.2.0...taiko-alethia-client-rs-v2.3.0) (2026-09-28)


### Features

* **taiko-client-rs:** harden event scanner against transient L1 stalls ([#21969](https://github.com/taikoxyz/taiko-mono/issues/21969)) ([9ef35dd](https://github.com/taikoxyz/taiko-mono/commit/9ef35dd36a7de9092ac5ceeedac092145456f20f))
* **taiko-client-rs:** optimize discv5 discovery + 20–30 peer management for the whitelist driver ([#21971](https://github.com/taikoxyz/taiko-mono/issues/21971)) ([c1d4b3c](https://github.com/taikoxyz/taiko-mono/commit/c1d4b3cf909ecb4b5d721048172aab0188392ebf))
* **taiko-client-rs:** reject zero beacon timing values ([#22169](https://github.com/taikoxyz/taiko-mono/issues/22169)) ([f5fce95](https://github.com/taikoxyz/taiko-mono/commit/f5fce95803dec25331af449b8f4d7d04235a07d7))
* **taiko-client-rs:** retry unavailable finalized state ([#22041](https://github.com/taikoxyz/taiko-mono/issues/22041)) ([7675a6d](https://github.com/taikoxyz/taiko-mono/commit/7675a6d5ee3aa0510429f9a65487d7ca18849d0a))
* **taiko-client,taiko-client-rs:** fetch blobs via the latest beacon blobs endpoint ([#22161](https://github.com/taikoxyz/taiko-mono/issues/22161)) ([29da7e7](https://github.com/taikoxyz/taiko-mono/commit/29da7e79dbf6cb7e336380505a1b9c9272e31c9d))


### Bug Fixes

* **taiko-client-rs:** extend preconfirmation timeout ([#21992](https://github.com/taikoxyz/taiko-mono/issues/21992)) ([ce7c2e8](https://github.com/taikoxyz/taiko-mono/commit/ce7c2e89580fcb181a3a76a4ca97d759eae337c7))
* **taiko-client-rs:** support SP1 fixed-k signer ([#21990](https://github.com/taikoxyz/taiko-mono/issues/21990)) ([4dbf352](https://github.com/taikoxyz/taiko-mono/commit/4dbf3522c5b2e2daa3e5de8045cc4a6b60aae118))


### Chores

* **clients:** bump execution client dependencies ([#21995](https://github.com/taikoxyz/taiko-mono/issues/21995)) ([d40a645](https://github.com/taikoxyz/taiko-mono/commit/d40a6455c4ad6ade7121905030ccd8b7119ced67))
* **deps:** bump the cargo-security group across 2 directories with 8 updates ([#22140](https://github.com/taikoxyz/taiko-mono/issues/22140)) ([aad725d](https://github.com/taikoxyz/taiko-mono/commit/aad725d0ede3fbeaef9ba4295e9d227079b6eb15))
* **taiko-client-rs:** bump execution client dependencies ([#22028](https://github.com/taikoxyz/taiko-mono/issues/22028)) ([792a268](https://github.com/taikoxyz/taiko-mono/commit/792a2684b8b4b0f66b64dd79ca69ce5ac86db587))
* **taiko-client-rs:** expose FixedKSigner without the net feature ([#21981](https://github.com/taikoxyz/taiko-mono/issues/21981)) ([fbe6716](https://github.com/taikoxyz/taiko-mono/commit/fbe6716c43c833b1bd9dfa80c784f67ed44df273))
* **taiko-client-rs:** shut down on SIGTERM and SIGINT ([#22146](https://github.com/taikoxyz/taiko-mono/issues/22146)) ([83304c4](https://github.com/taikoxyz/taiko-mono/commit/83304c4dae418f20578a5fd3291b911570607d27))
* **taiko-client-rs:** use standard preconfirmation signer ([#22011](https://github.com/taikoxyz/taiko-mono/issues/22011)) ([c4eaf44](https://github.com/taikoxyz/taiko-mono/commit/c4eaf44c02134c63f577b1be70f8f0bf98f614ee))
* **taiko-client,taiko-client-rs:** align manifest decoding ([#22173](https://github.com/taikoxyz/taiko-mono/issues/22173)) ([aa3a24f](https://github.com/taikoxyz/taiko-mono/commit/aa3a24f50060641bc345b7973ed4d5bad42987f0))
* **taiko-client,taiko-client-rs:** refuse shutdown ahead of imminent sequencing windows ([#22000](https://github.com/taikoxyz/taiko-mono/issues/22000)) ([7684747](https://github.com/taikoxyz/taiko-mono/commit/76847471d067509c3d137c29a2b6abe4dd7bbd2d))
* **taiko-client,taiko-client-rs:** remove Masaya network support ([#22063](https://github.com/taikoxyz/taiko-mono/issues/22063)) ([f9a4949](https://github.com/taikoxyz/taiko-mono/commit/f9a4949759f90c536c8d30f26ce680fef62eae94))


### Performance Improvements

* **protocol:** avoid redundant fixed-k scalar multiplication ([#22009](https://github.com/taikoxyz/taiko-mono/issues/22009)) ([170f50b](https://github.com/taikoxyz/taiko-mono/commit/170f50bbdf85b642d987de6df07b02783a9b8c48))


### Tests

* **taiko-client-rs:** retry transient ShastaEnv bootstrap failures in e2e setup ([#22049](https://github.com/taikoxyz/taiko-mono/issues/22049)) ([2634edf](https://github.com/taikoxyz/taiko-mono/commit/2634edfd045a857e35295afe34a919b2b13b9ae6))
* **taiko-client-rs:** stabilize the e2e lane and harden the test suite ([#21967](https://github.com/taikoxyz/taiko-mono/issues/21967)) ([abbc29d](https://github.com/taikoxyz/taiko-mono/commit/abbc29d0e9a521481fe259fa47713b0b03ad3501))

## [2.2.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-rs-v2.1.0...taiko-alethia-client-rs-v2.2.0) (2026-07-15)


### Features

* **taiko-client-rs:** keep proposer alive on tx reverts ([#21904](https://github.com/taikoxyz/taiko-mono/issues/21904)) ([4aba77b](https://github.com/taikoxyz/taiko-mono/commit/4aba77b1986cab33ee9d54aa77f78848cf892c47))
* **taiko-client-rs:** log preconfirmation peer ticks ([#21880](https://github.com/taikoxyz/taiko-mono/issues/21880)) ([00465ea](https://github.com/taikoxyz/taiko-mono/commit/00465eaa148ff3890a0457068266747b28482ed9))
* **taiko-client,taiko-client-rs:** restore forced inclusion propose inputs ([#21936](https://github.com/taikoxyz/taiko-mono/issues/21936)) ([2d7fd1a](https://github.com/taikoxyz/taiko-mono/commit/2d7fd1a3e76505652a6adee6d24278affa6ddd9c))


### Bug Fixes

* **taiko-client-rs:** avoid forced inclusions in propose input ([#21851](https://github.com/taikoxyz/taiko-mono/issues/21851)) ([61fec74](https://github.com/taikoxyz/taiko-mono/commit/61fec74e22e8fc0ae3df3d526babc6f84009f193))
* **taiko-client-rs:** decode legacy transactions in preconfirmation tx-lists ([#21906](https://github.com/taikoxyz/taiko-mono/issues/21906)) ([033bd94](https://github.com/taikoxyz/taiko-mono/commit/033bd94be3d90617fc2a1dab00d49cfcd96348bb))
* **taiko-client-rs:** degrade undecodable derivation source blob to default payload ([#21854](https://github.com/taikoxyz/taiko-mono/issues/21854)) ([eb3bc25](https://github.com/taikoxyz/taiko-mono/commit/eb3bc250f1eac1a7b93cba66ceb8baa4d8b34a85))
* **taiko-client-rs:** enforce strict engine status checks in driver payload submission ([#21949](https://github.com/taikoxyz/taiko-mono/issues/21949)) ([a062a61](https://github.com/taikoxyz/taiko-mono/commit/a062a612fac35b5e83dedcc9367efd8ea0d48238))
* **taiko-client-rs:** keep release lockfile current ([#21780](https://github.com/taikoxyz/taiko-mono/issues/21780)) ([c4786c2](https://github.com/taikoxyz/taiko-mono/commit/c4786c2bcd898c4674d8e1a8a4bfb26b95cdeb3e))
* **taiko-client-rs:** prevent derivation panic on oversized manifest size field ([#21948](https://github.com/taikoxyz/taiko-mono/issues/21948)) ([f91132c](https://github.com/taikoxyz/taiko-mono/commit/f91132c4dcfa4f23f0a97192de465f6f3aef784c))
* **taiko-client-rs:** recover from scanner lag and reorged-out proposal logs in event sync ([#21950](https://github.com/taikoxyz/taiko-mono/issues/21950)) ([9c19514](https://github.com/taikoxyz/taiko-mono/commit/9c19514686a80ba534ebafeba8143461e4f43e5f))
* **taiko-client-rs:** report execution head in /status when unsafe counter lags it ([#21777](https://github.com/taikoxyz/taiko-mono/issues/21777)) ([e263a73](https://github.com/taikoxyz/taiko-mono/commit/e263a73597a9073fc3135c4d34e79c3a6bd12224))
* **taiko-client-rs:** survive checkpoint sync handoff and harden the catch-up loop ([#21900](https://github.com/taikoxyz/taiko-mono/issues/21900)) ([52c3e77](https://github.com/taikoxyz/taiko-mono/commit/52c3e77ed34cdd0a674911ad54bf70f930acfded))
* **taiko-client-rs:** taiko-geth wire compat, proposer manifest fixes, and bounded event-sync retries ([#21958](https://github.com/taikoxyz/taiko-mono/issues/21958)) ([4679d0d](https://github.com/taikoxyz/taiko-mono/commit/4679d0d3cb04f0c37b37cb1a8f1eb8cd443985b8))


### Chores

* **protocol:** merge taiko-alethia-protocol-v3.0.0 (v3.1.0 + hardening) back to main ([f837160](https://github.com/taikoxyz/taiko-mono/commit/f83716070331945133adc283b765083501f21e4b))
* **protocol:** record the v3.0.0 merge ancestry (take 2) ([9646f55](https://github.com/taikoxyz/taiko-mono/commit/9646f553cd89abe95fab9745c17a46273c4d4bd0))
* **protocol:** record the v3.0.0 merge ancestry (take 2) ([bc35381](https://github.com/taikoxyz/taiko-mono/commit/bc35381393888f6c3dfe81d24eb6193255c0c49a))
* **protocol:** record the v3.0.0 merge ancestry lost by squashing [#21922](https://github.com/taikoxyz/taiko-mono/issues/21922) ([#21930](https://github.com/taikoxyz/taiko-mono/issues/21930)) ([ca16fba](https://github.com/taikoxyz/taiko-mono/commit/ca16fba34ca276975b4c5179489c8eec3f25a0db))
* **taiko-client-rs:** bump execution client dependencies ([#21801](https://github.com/taikoxyz/taiko-mono/issues/21801)) ([48caa9e](https://github.com/taikoxyz/taiko-mono/commit/48caa9e385f52659deee6a85faeb1b04f81df48a))
* **taiko-client-rs:** harden whitelist preconfirmation ingress ([#21943](https://github.com/taikoxyz/taiko-mono/issues/21943)) ([f1e84ae](https://github.com/taikoxyz/taiko-mono/commit/f1e84ae5d0cae84809895260104d74cb5f19f183))
* **taiko-client-rs:** reject trailing bytes after manifest RLP ([#21911](https://github.com/taikoxyz/taiko-mono/issues/21911)) ([d23ec01](https://github.com/taikoxyz/taiko-mono/commit/d23ec013e4c28dd95abe98415c108797b2db8b40))
* **taiko-client-rs:** simplify and harden the test harness ([#21914](https://github.com/taikoxyz/taiko-mono/issues/21914)) ([3f77845](https://github.com/taikoxyz/taiko-mono/commit/3f77845e9cfbea9b3dfb71e91fbea74c65278efa))
* **taiko-client,taiko-client-rs:** bump execution client deps ([#21941](https://github.com/taikoxyz/taiko-mono/issues/21941)) ([3a99ab1](https://github.com/taikoxyz/taiko-mono/commit/3a99ab186f878a4b18c4b432740e8df8381adbe6))


### Code Refactoring

* **taiko-client-rs:** drop the `Client<P>` provider generic ([#21925](https://github.com/taikoxyz/taiko-mono/issues/21925)) ([77ede38](https://github.com/taikoxyz/taiko-mono/commit/77ede383fc790f63a6e10ee1963d5da913c98901))
* **taiko-client-rs:** move permissionless preconfirmation to its own branch ([#21908](https://github.com/taikoxyz/taiko-mono/issues/21908)) ([37f8e27](https://github.com/taikoxyz/taiko-mono/commit/37f8e270a812953ba5c26abbe1736d8f53ee0b3d))
* **taiko-client-rs:** simplify whitelist preconfirmation driver ([#21913](https://github.com/taikoxyz/taiko-mono/issues/21913)) ([081d91c](https://github.com/taikoxyz/taiko-mono/commit/081d91c975bd84cc407130038f12cd627b75425c))
* **taiko-client-rs:** sweep quick-win cleanups across crates ([#21926](https://github.com/taikoxyz/taiko-mono/issues/21926)) ([fd8b35a](https://github.com/taikoxyz/taiko-mono/commit/fd8b35a3583155377ab63e24b19522e669c62f34))


### Workflow

* **taiko-client-rs:** enable signer recovery for net builds ([#21944](https://github.com/taikoxyz/taiko-mono/issues/21944)) ([2a752ad](https://github.com/taikoxyz/taiko-mono/commit/2a752addafd6bf4fc1a67443e82513ecaf484b2d))

## [2.1.0](https://github.com/taikoxyz/taiko-mono/compare/taiko-alethia-client-rs-v2.0.0...taiko-alethia-client-rs-v2.1.0) (2026-06-12)


### Features

* **protocol,taiko-client,taiko-client-rs:** raise Unzen derivation source block limit ([#21600](https://github.com/taikoxyz/taiko-mono/issues/21600)) ([189d6d4](https://github.com/taikoxyz/taiko-mono/commit/189d6d47e20d49f0105a56b3a0b8c9fc2aed07bb))
* **protocol:** remove MIN_ANCHOR_OFFSET from Shasta derivation ([#20967](https://github.com/taikoxyz/taiko-mono/issues/20967)) ([1423e4a](https://github.com/taikoxyz/taiko-mono/commit/1423e4a0550cbf210a74c129a47da530195d7915))
* **taiko-client-rs:** add `preconfirmation-client` SDK crate for P2P network integration ([#21018](https://github.com/taikoxyz/taiko-mono/issues/21018)) ([d0b6029](https://github.com/taikoxyz/taiko-mono/commit/d0b60299fe3292b34464deb59d4d391dbaafae3b))
* **taiko-client-rs:** add comprehensive metrics and observability instrumentation for whitelist preconfirmation driver ([#21300](https://github.com/taikoxyz/taiko-mono/issues/21300)) ([c9f18ec](https://github.com/taikoxyz/taiko-mono/commit/c9f18ec2d9d1c74b30e277414a5d7b40a955264e))
* **taiko-client-rs:** add engine mode for payload building via FCU + get_payload ([#21186](https://github.com/taikoxyz/taiko-mono/issues/21186)) ([01d7b25](https://github.com/taikoxyz/taiko-mono/commit/01d7b25528747c205f5c81dbb522bd10207792cb))
* **taiko-client-rs:** add function to decode a single blob ([#21318](https://github.com/taikoxyz/taiko-mono/issues/21318)) ([e0aeb19](https://github.com/taikoxyz/taiko-mono/commit/e0aeb1965898eb9f84600a4d7e07cb51ce416023))
* **taiko-client-rs:** add loopback delivery for local RPC publishes ([#21386](https://github.com/taikoxyz/taiko-mono/issues/21386)) ([1dcf91c](https://github.com/taikoxyz/taiko-mono/commit/1dcf91c3402a0a6bbfacab157ba7edda9a436ea1))
* **taiko-client-rs:** add preconfirmation entry logs ([#21745](https://github.com/taikoxyz/taiko-mono/issues/21745)) ([494002c](https://github.com/taikoxyz/taiko-mono/commit/494002c42a84a1db89c64f6fa4039f3220ef7a50))
* **taiko-client-rs:** add preconfirmation P2P raw identity flag ([#21723](https://github.com/taikoxyz/taiko-mono/issues/21723)) ([4986c7d](https://github.com/taikoxyz/taiko-mono/commit/4986c7d63dd9380ea2cca96cff785b29c67ec894))
* **taiko-client-rs:** add reqresp direct lookup path ([#21379](https://github.com/taikoxyz/taiko-mono/issues/21379)) ([007d635](https://github.com/taikoxyz/taiko-mono/commit/007d6356970ae4f8adf1019c2e250b731a38ce4b))
* **taiko-client-rs:** add whitelist preconf RPC server and P2P publishing ([#21312](https://github.com/taikoxyz/taiko-mono/issues/21312)) ([00bad73](https://github.com/taikoxyz/taiko-mono/commit/00bad7336046cb71c05aea8f59499b45296a92eb))
* **taiko-client-rs:** add whitelist preconfirmation driver and optimize envelope cache ([#21289](https://github.com/taikoxyz/taiko-mono/issues/21289)) ([f6faa5c](https://github.com/taikoxyz/taiko-mono/commit/f6faa5c45fd990fed540623a09fdd3f0448dd575))
* **taiko-client-rs:** adopt `tx-manager` for proposal submission ([#21513](https://github.com/taikoxyz/taiko-mono/issues/21513)) ([0a1b18a](https://github.com/taikoxyz/taiko-mono/commit/0a1b18ac2673a697c77c31056b5c7f9786de6b41))
* **taiko-client-rs:** advertise whitelist p2p enode address ([#21730](https://github.com/taikoxyz/taiko-mono/issues/21730)) ([285d457](https://github.com/taikoxyz/taiko-mono/commit/285d4576b80317d9f29030a66e1fd19cc9de7843))
* **taiko-client-rs:** allow multiple blobs to be coded into sidecar ([#20955](https://github.com/taikoxyz/taiko-mono/issues/20955)) ([85125ec](https://github.com/taikoxyz/taiko-mono/commit/85125ec7f87437f5164b0d4b26d4d631656c4e6c))
* **taiko-client-rs:** expose canShutdown on whitelist preconf /status ([#21656](https://github.com/taikoxyz/taiko-mono/issues/21656)) ([2d2745b](https://github.com/taikoxyz/taiko-mono/commit/2d2745bcffaf312d17e9a097240736e1a789aa2c))
* **taiko-client-rs:** extend `PreconfSignerResolver` trait ([#21117](https://github.com/taikoxyz/taiko-mono/issues/21117)) ([c6bdcb9](https://github.com/taikoxyz/taiko-mono/commit/c6bdcb9f41924ff9b3f900bd55c581ddeadc5f54))
* **taiko-client-rs:** fallback search for `start_tag` by inbox activation timestamp ([#20813](https://github.com/taikoxyz/taiko-mono/issues/20813)) ([41ca4aa](https://github.com/taikoxyz/taiko-mono/commit/41ca4aa8f15bdf7a960b701ced41e6ea6b43d09b))
* **taiko-client-rs:** gate net dependencies for zkvm ([#21204](https://github.com/taikoxyz/taiko-mono/issues/21204)) ([c1365d3](https://github.com/taikoxyz/taiko-mono/commit/c1365d39b6e2929c576f4f7f595015017e76a0d9))
* **taiko-client-rs:** gate ticks by preconfirmation whitelist in proposer ([#21626](https://github.com/taikoxyz/taiko-mono/issues/21626)) ([19d0e98](https://github.com/taikoxyz/taiko-mono/commit/19d0e98df125e1f40658254df92db1544984900f))
* **taiko-client-rs:** get_preconf_slot_info API for the taiko-client-rs ([#21279](https://github.com/taikoxyz/taiko-mono/issues/21279)) ([26f8c95](https://github.com/taikoxyz/taiko-mono/commit/26f8c958b33f29edeeabe4483dd084bb47aca089))
* **taiko-client-rs:** handle L1 finalized block RPC error ([#21495](https://github.com/taikoxyz/taiko-mono/issues/21495)) ([92e1c5f](https://github.com/taikoxyz/taiko-mono/commit/92e1c5f2dd572799b07a5c8f275febb7a1aeb6de))
* **taiko-client-rs:** handle L1 finalized block RPC error ([#21495](https://github.com/taikoxyz/taiko-mono/issues/21495)) ([e634165](https://github.com/taikoxyz/taiko-mono/commit/e634165995ae727f1edc63b15f6d251c41ad54d0))
* **taiko-client-rs:** import whitelist preconf blocks at genesis ([#21717](https://github.com/taikoxyz/taiko-mono/issues/21717)) ([bb272c2](https://github.com/taikoxyz/taiko-mono/commit/bb272c2ed36cdf57d4b2a50156615bf96a67716a))
* **taiko-client-rs:** introduce `LookaheadResolver` ([#20905](https://github.com/taikoxyz/taiko-mono/issues/20905)) ([23e3ea0](https://github.com/taikoxyz/taiko-mono/commit/23e3ea0b31b6c4eac980f107643fb6795877015d))
* **taiko-client-rs:** introduce preconfirmation interface ([#20871](https://github.com/taikoxyz/taiko-mono/issues/20871)) ([e30d8b5](https://github.com/taikoxyz/taiko-mono/commit/e30d8b5f01ad9ab4c7689b0329c23f0fa0bec76a))
* **taiko-client-rs:** introduce Rust driver RPC for permission-less preconfirmation ([#21132](https://github.com/taikoxyz/taiko-mono/issues/21132)) ([1f58006](https://github.com/taikoxyz/taiko-mono/commit/1f58006e1d1cbb9bbf56432b09a4ccf235f5e688))
* **taiko-client-rs:** make finalized proposal id optional in shasta derivation ([#21487](https://github.com/taikoxyz/taiko-mono/issues/21487)) ([67cfa98](https://github.com/taikoxyz/taiko-mono/commit/67cfa980789210646babd10654061579db8226ff))
* **taiko-client-rs:** metrics refactor ([#21751](https://github.com/taikoxyz/taiko-mono/issues/21751)) ([47f279e](https://github.com/taikoxyz/taiko-mono/commit/47f279e791e3179eb3da173e284845e9a73db3d8))
* **taiko-client-rs:** prevent preconfirmation reorgs of event-synced L2 history ([#21316](https://github.com/taikoxyz/taiko-mono/issues/21316)) ([3b01390](https://github.com/taikoxyz/taiko-mono/commit/3b01390f41bbbc24209f9dccadb644513468a1f3))
* **taiko-client-rs:** reconcile head L1 origin after reorg ([#21660](https://github.com/taikoxyz/taiko-mono/issues/21660)) ([13151be](https://github.com/taikoxyz/taiko-mono/commit/13151be1143be5e2930ae262ae8c22320448434d))
* **taiko-client-rs:** refactor `preconfirmation-client` into `preconfirmation-driver` with embedded driver support ([#21200](https://github.com/taikoxyz/taiko-mono/issues/21200)) ([a33b8f7](https://github.com/taikoxyz/taiko-mono/commit/a33b8f7d23a225cdb5f9774d911b84b957abd0cd))
* **taiko-client-rs:** rename RPC to REST and harden REST server ([#21326](https://github.com/taikoxyz/taiko-mono/issues/21326)) ([8db8de2](https://github.com/taikoxyz/taiko-mono/commit/8db8de2f7a0e25b3faaa592649dbbed155978118))
* **taiko-client-rs:** replace lookahead-based whitelist validation with configured sequencer allowlist ([#21329](https://github.com/taikoxyz/taiko-mono/issues/21329)) ([2b030b9](https://github.com/taikoxyz/taiko-mono/commit/2b030b9d756560f5c27888f63649c0b6314ab7e1))
* **taiko-client-rs:** rust client updates based on sequential proving ([#20921](https://github.com/taikoxyz/taiko-mono/issues/20921)) ([073b2bd](https://github.com/taikoxyz/taiko-mono/commit/073b2bdef88500d89c54db8dbad5eb3297865160))
* **taiko-client-rs:** skip orphaned proposal logs during event sync ([#21490](https://github.com/taikoxyz/taiko-mono/issues/21490)) ([ccf71eb](https://github.com/taikoxyz/taiko-mono/commit/ccf71eb9ef6051913769b1e5131a68f622ecb384))
* **taiko-client-rs:** strict inbound preconf gossipsub validation ([#21328](https://github.com/taikoxyz/taiko-mono/issues/21328)) ([1e80e32](https://github.com/taikoxyz/taiko-mono/commit/1e80e32b409f2ed7e35814ef70d74747bcecbce9))
* **taiko-client-rs:** support configurable L1 transports ([#21450](https://github.com/taikoxyz/taiko-mono/issues/21450)) ([8a07036](https://github.com/taikoxyz/taiko-mono/commit/8a070365713e0f3e8910287736dffefea69c78f9))
* **taiko-client-rs:** update for latest `alethia-reth` Uzen semantics ([#21556](https://github.com/taikoxyz/taiko-mono/issues/21556)) ([1b5f765](https://github.com/taikoxyz/taiko-mono/commit/1b5f765f964e4e140aec71b667642cdae6c32812))
* **taiko-client-rs:** update Rust contract bindings ([#20812](https://github.com/taikoxyz/taiko-mono/issues/20812)) ([c29c755](https://github.com/taikoxyz/taiko-mono/commit/c29c755b8e35237582ccb175cbb6bf8b13086891))
* **taiko-client-rs:** wire finalized Shasta proposal into forkchoice updates ([#20809](https://github.com/taikoxyz/taiko-mono/issues/20809)) ([a1a72e4](https://github.com/taikoxyz/taiko-mono/commit/a1a72e423f0e145cea9fee48b7d797f99a086108))
* **taiko-client,taiko-client-rs:** add devnet Uzen time override flag ([#21566](https://github.com/taikoxyz/taiko-mono/issues/21566)) ([f72c38d](https://github.com/taikoxyz/taiko-mono/commit/f72c38d51f09178aa897d738cc3da6846795843b))
* **taiko-client,taiko-client-rs:** align Shasta manifest validation with the latest protocol updates ([#20775](https://github.com/taikoxyz/taiko-mono/issues/20775)) ([5e18853](https://github.com/taikoxyz/taiko-mono/commit/5e18853b253d7c4e8db2d8c547870c11a3af45d9))
* **taiko-client,taiko-client-rs:** carry Uzen `header.difficulty` on preconfirmation gossip wire ([#21576](https://github.com/taikoxyz/taiko-mono/issues/21576)) ([539e986](https://github.com/taikoxyz/taiko-mono/commit/539e9867d4eeace708ef0f0e994528f540abc098))
* **taiko-client,taiko-client-rs:** changes based on protocol PR [#20986](https://github.com/taikoxyz/taiko-mono/issues/20986) ([#20990](https://github.com/taikoxyz/taiko-mono/issues/20990)) ([07ad17c](https://github.com/taikoxyz/taiko-mono/commit/07ad17c95415e113e3c8759c615a8ea21d7865c5))
* **taiko-client,taiko-client-rs:** changes based on the latest Shasta consecutive proofs submission design ([#20979](https://github.com/taikoxyz/taiko-mono/issues/20979)) ([f9e6bc4](https://github.com/taikoxyz/taiko-mono/commit/f9e6bc4ed50e787ab012606528bb6ea16891bab6))
* **taiko-client,taiko-client-rs:** client updates for moving bond processing to L1 ([#21078](https://github.com/taikoxyz/taiko-mono/issues/21078)) ([68fa85d](https://github.com/taikoxyz/taiko-mono/commit/68fa85d6c4f5386a723f86d3e9224acc8e5fb341))
* **taiko-client,taiko-client-rs:** make anchor/timestamp offsets chain-aware ([#21427](https://github.com/taikoxyz/taiko-mono/issues/21427)) ([2dc51f0](https://github.com/taikoxyz/taiko-mono/commit/2dc51f0540984db28614c1cc91882dd7e3dd8dfb))
* **taiko-client,taiko-client-rs:** only allow one block per forced inclusion ([#20778](https://github.com/taikoxyz/taiko-mono/issues/20778)) ([685445a](https://github.com/taikoxyz/taiko-mono/commit/685445abe0c753b35832a8e5064110e281c7012f))
* **taiko-client,taiko-client-rs:** remove `--propose.anchorOffset` flag ([#21053](https://github.com/taikoxyz/taiko-mono/issues/21053)) ([eb0f198](https://github.com/taikoxyz/taiko-mono/commit/eb0f198dbbe8f9b03cf40629c1277cdd5d952195))
* **taiko-client,taiko-client-rs:** remove `designatedProver` from `transition` ([#21109](https://github.com/taikoxyz/taiko-mono/issues/21109)) ([98d9135](https://github.com/taikoxyz/taiko-mono/commit/98d9135ee3ff808cbc57f5b410bdc960b0e95052))
* **taiko-client,taiko-client-rs:** rename Unzen fork ([#21599](https://github.com/taikoxyz/taiko-mono/issues/21599)) ([1252842](https://github.com/taikoxyz/taiko-mono/commit/125284295ac78e45bc2f3d742b6022eb3ebfb50a))
* **taiko-client,taiko-client-rs:** update `BLOCK_GAS_LIMIT_MAX_CHANGE` to `200` ([#21114](https://github.com/taikoxyz/taiko-mono/issues/21114)) ([56353ce](https://github.com/taikoxyz/taiko-mono/commit/56353ce2b8554036158e57f176f336e33fe0d87d))
* **taiko-client,taiko-client-rs:** update `MaxBlockGasLimit` to `45_000_000` ([#20788](https://github.com/taikoxyz/taiko-mono/issues/20788)) ([4f31233](https://github.com/taikoxyz/taiko-mono/commit/4f31233fed5e1829b84f5e5a740ac8c7a46ccccf))
* **taiko-client,taiko-client-rs:** update `Proposed` event signature ([#21052](https://github.com/taikoxyz/taiko-mono/issues/21052)) ([5b94117](https://github.com/taikoxyz/taiko-mono/commit/5b94117a56ecad2b44c9c4cee4453ead5459c450))
* **taiko-client,taiko-client-rs:** update blob offset validation for Shasta proposals ([#21148](https://github.com/taikoxyz/taiko-mono/issues/21148)) ([74194df](https://github.com/taikoxyz/taiko-mono/commit/74194df5edfd809fc70335b1211abd074292e6e5))
* **taiko-client,taiko-client-rs:** update Go / Rust contract bindings ([#21011](https://github.com/taikoxyz/taiko-mono/issues/21011)) ([fc8c3fb](https://github.com/taikoxyz/taiko-mono/commit/fc8c3fbfd3e82d6bf6d3d19ee1ab45e90d175caa))
* **taiko-client,taiko-client-rs:** update Go / Rust contract bindings ([#21019](https://github.com/taikoxyz/taiko-mono/issues/21019)) ([6fb8bb2](https://github.com/taikoxyz/taiko-mono/commit/6fb8bb22212b7bd72f66f4b17a80f993f4f0173c))
* **taiko-client,taiko-client-rs:** update Go / Rust contract bindings ([#21026](https://github.com/taikoxyz/taiko-mono/issues/21026)) ([d8741f1](https://github.com/taikoxyz/taiko-mono/commit/d8741f16b36db30c200b1592310c3d85b625a16c))
* **taiko-client,taiko-client-rs:** update Go / Rust contract bindings ([#21035](https://github.com/taikoxyz/taiko-mono/issues/21035)) ([9ee7108](https://github.com/taikoxyz/taiko-mono/commit/9ee7108bfa23a485307affbb291006732354b2e4))
* **taiko-client,taiko-client-rs:** update Go / Rust contract bindings ([#21050](https://github.com/taikoxyz/taiko-mono/issues/21050)) ([a0d76ba](https://github.com/taikoxyz/taiko-mono/commit/a0d76ba7681bb1d8ecbe72647da8726786becf14))
* **taiko-client,taiko-client-rs:** updates related to new Shasta `Proposed` event ([#21040](https://github.com/taikoxyz/taiko-mono/issues/21040)) ([d29355a](https://github.com/taikoxyz/taiko-mono/commit/d29355abbb89bdd91b98ff4b7147bf560327baba))


### Bug Fixes

* **taiko-client-rs:** add DNS support to libp2p transport configuration ([#21355](https://github.com/taikoxyz/taiko-mono/issues/21355)) ([d7840f2](https://github.com/taikoxyz/taiko-mono/commit/d7840f2b9ed4a512d2499ff8d7f974b696ae99ba))
* **taiko-client-rs:** add TTL cache for whitelist sequencer lookups ([#21299](https://github.com/taikoxyz/taiko-mono/issues/21299)) ([28ffca4](https://github.com/taikoxyz/taiko-mono/commit/28ffca468489e87f16362786e323a502f03ba755))
* **taiko-client-rs:** align /status and fee range checks with go ([#21335](https://github.com/taikoxyz/taiko-mono/issues/21335)) ([06f7ec0](https://github.com/taikoxyz/taiko-mono/commit/06f7ec032d60ba6e657107953c2992cbb5b60c1b))
* **taiko-client-rs:** better caching based on nethermind code ([#21304](https://github.com/taikoxyz/taiko-mono/issues/21304)) ([4414a7c](https://github.com/taikoxyz/taiko-mono/commit/4414a7ca1a1f46b7431ec44cf81660e2d6c690fe))
* **taiko-client-rs:** call `set_devnet_uzen_override` after `init_logs` ([#21567](https://github.com/taikoxyz/taiko-mono/issues/21567)) ([4c57323](https://github.com/taikoxyz/taiko-mono/commit/4c573235f2c1976337cdf1f86e67ca2a0792c372))
* **taiko-client-rs:** defer whitelist preconf driver timeouts instead of crashing ([#21568](https://github.com/taikoxyz/taiko-mono/issues/21568)) ([b67b175](https://github.com/taikoxyz/taiko-mono/commit/b67b17582f11d1f6fe64f880fb8bc3bb258ddbc7))
* **taiko-client-rs:** fix docker build CI ([#21140](https://github.com/taikoxyz/taiko-mono/issues/21140)) ([6088b45](https://github.com/taikoxyz/taiko-mono/commit/6088b4536af01246ea31ada33cb61a5ac759816c))
* **taiko-client-rs:** fix tx-list RLP format in whitelist preconfirmation zlib codec ([#21310](https://github.com/taikoxyz/taiko-mono/issues/21310)) ([ad01db8](https://github.com/taikoxyz/taiko-mono/commit/ad01db86ae43a3ed6ab1f271527aa88aba9a7d1b))
* **taiko-client-rs:** ignore self preconfirmation gossip ([#21726](https://github.com/taikoxyz/taiko-mono/issues/21726)) ([23cddae](https://github.com/taikoxyz/taiko-mono/commit/23cddaecdf1b566779b13ac387b902555ad7d3d6))
* **taiko-client-rs:** make Shasta event sync resilient on genesis and pre-finality startup ([#21348](https://github.com/taikoxyz/taiko-mono/issues/21348)) ([9e5b426](https://github.com/taikoxyz/taiko-mono/commit/9e5b426c33cd1b8bc73fd838122b752b9986a0d8))
* **taiko-client-rs:** preconf_tip fallback ([#21413](https://github.com/taikoxyz/taiko-mono/issues/21413)) ([6fa6bd0](https://github.com/taikoxyz/taiko-mono/commit/6fa6bd0c92386aaff294bbb7738513b736423ff6))
* **taiko-client-rs:** reconcile highestUnsafeL2PayloadBlockID to reth head after L1 reorg ([#21744](https://github.com/taikoxyz/taiko-mono/issues/21744)) ([fe5b6d2](https://github.com/taikoxyz/taiko-mono/commit/fe5b6d2f4e9a172229c4d63ca2c18589629c4f22))
* **taiko-client-rs:** remove anchor gas subtraction from engine params gas limit ([#21203](https://github.com/taikoxyz/taiko-mono/issues/21203)) ([4999719](https://github.com/taikoxyz/taiko-mono/commit/4999719d512b13584a88617faff3d32affca3a8b))
* **taiko-client-rs:** retry timed-out preconf submissions and reconnect event sync ([#21505](https://github.com/taikoxyz/taiko-mono/issues/21505)) ([ca2984d](https://github.com/taikoxyz/taiko-mono/commit/ca2984d1c736d093df4d8d90b97e03ed0999f408))
* **taiko-client-rs:** retry whitelist preconfirmation peer dials ([#21705](https://github.com/taikoxyz/taiko-mono/issues/21705)) ([795728d](https://github.com/taikoxyz/taiko-mono/commit/795728dcec307ac46039c7077041c06cc734e76b))
* **taiko-client-rs:** should use lower rpc L2 block number for resume ([#21577](https://github.com/taikoxyz/taiko-mono/issues/21577)) ([eaee3a9](https://github.com/taikoxyz/taiko-mono/commit/eaee3a939e6ba37696ab19ec2b96881a3c4666f1))
* **taiko-client-rs:** skip stale finalized hint for current proposal ([#21694](https://github.com/taikoxyz/taiko-mono/issues/21694)) ([49efe2a](https://github.com/taikoxyz/taiko-mono/commit/49efe2a1365a703b62c07689b02d77686d7a317f))
* **taiko-client-rs:** support `enode://` bootnode URLs in whitelist preconfirmation driver ([#21309](https://github.com/taikoxyz/taiko-mono/issues/21309)) ([7a9d99b](https://github.com/taikoxyz/taiko-mono/commit/7a9d99bf29988e7a015f08cd28467d15797e5b8b))
* **taiko-client-rs:** tolerate transient RPC errors in whitelist preconfirmation event handler ([#21590](https://github.com/taikoxyz/taiko-mono/issues/21590)) ([cd84769](https://github.com/taikoxyz/taiko-mono/commit/cd84769c11333ae62ada4d353ccf30d08c14574c))
* **taiko-client-rs:** use trusted resume head for event sync (checkpoint head or `head_l1_origin`) ([#21331](https://github.com/taikoxyz/taiko-mono/issues/21331)) ([c500e8a](https://github.com/taikoxyz/taiko-mono/commit/c500e8a5ece96080df8fd4ce11268b7bf94237b0))
* **taiko-client,taiko-client-rs:** default SHASTA fork path and make protocol dir configurable for bindings ([#21376](https://github.com/taikoxyz/taiko-mono/issues/21376)) ([461a0d1](https://github.com/taikoxyz/taiko-mono/commit/461a0d1cdfed9f0b9714255f4389c68fbefd961a))
* **taiko-client,taiko-client-rs:** only apply default low-bond manifests for normal proposer sources ([#20748](https://github.com/taikoxyz/taiko-mono/issues/20748)) ([aa1956a](https://github.com/taikoxyz/taiko-mono/commit/aa1956a2a65e2dccaab8c15f95844668fa2704ea))
* **taiko-client,taiko-client-rs:** update `TIMESTAMP_MAX_OFFSET` ([#20969](https://github.com/taikoxyz/taiko-mono/issues/20969)) ([4a49518](https://github.com/taikoxyz/taiko-mono/commit/4a495188afbdbddf41457d440762b89023b32d84))
* **taiko-client:** close event filter iterators ([#21374](https://github.com/taikoxyz/taiko-mono/issues/21374)) ([b4627ea](https://github.com/taikoxyz/taiko-mono/commit/b4627eaf7f4663e042005c6e23983b4e367cae98))


### Chores

* **deps:** bump the cargo group across 2 directories with 1 update ([#21518](https://github.com/taikoxyz/taiko-mono/issues/21518)) ([adf6875](https://github.com/taikoxyz/taiko-mono/commit/adf6875ed84ac3160b2a423ddcbf2f1bd042092c))
* **deps:** bump the cargo group across 5 directories with 1 update ([#21264](https://github.com/taikoxyz/taiko-mono/issues/21264)) ([75a5e00](https://github.com/taikoxyz/taiko-mono/commit/75a5e0019e12c1b9048c5837d208b4f9246624b2))
* **deps:** bump the cargo group across 5 directories with 2 updates ([#21116](https://github.com/taikoxyz/taiko-mono/issues/21116)) ([c76e37a](https://github.com/taikoxyz/taiko-mono/commit/c76e37a28d153f5b6407538f70ca28f0a93c82db))
* **deps:** migrate kona dependencies to ethereum-optimism/optimism and upgrade to v1.2.9 ([#21466](https://github.com/taikoxyz/taiko-mono/issues/21466)) ([411fffd](https://github.com/taikoxyz/taiko-mono/commit/411fffd7550abf0da4124b628130d5e4e9b17960))
* **ejector,repo,taiko-client-rs:** improve code comments clarity ([#21055](https://github.com/taikoxyz/taiko-mono/issues/21055)) ([486a6e3](https://github.com/taikoxyz/taiko-mono/commit/486a6e3b1aee009bb963d16e8482643c9a868730))
* **protocol,taiko-client,taiko-client-rs:** cherry pick pr 20762 ([#20763](https://github.com/taikoxyz/taiko-mono/issues/20763)) ([09ff83f](https://github.com/taikoxyz/taiko-mono/commit/09ff83f348c19ad11c920adc881dcc76ed62194d))
* **taiko-client-rs, taiko-client:** address ci timeout ([#21153](https://github.com/taikoxyz/taiko-mono/issues/21153)) ([3260855](https://github.com/taikoxyz/taiko-mono/commit/3260855ebba2c2bec87c06fad192dd6ef318af1a))
* **taiko-client-rs,ejector:** bump event-scanner to `v1.1.1` ([#21737](https://github.com/taikoxyz/taiko-mono/issues/21737)) ([729a43e](https://github.com/taikoxyz/taiko-mono/commit/729a43e0e0e22958c295bd7fbbb30cdde6b3ce06))
* **taiko-client-rs,preconfirmation-p2p:** enforce docs and `clippy` standards && update `AGENTS.md` ([#21333](https://github.com/taikoxyz/taiko-mono/issues/21333)) ([cf5991e](https://github.com/taikoxyz/taiko-mono/commit/cf5991e57ccfb8fa6bc4a72ab0e16784259141fa))
* **taiko-client-rs:** add more metrics for driver ([#20751](https://github.com/taikoxyz/taiko-mono/issues/20751)) ([9d10a1c](https://github.com/taikoxyz/taiko-mono/commit/9d10a1cf74dcd3ba3f6a740cfe310f2d47bb0884))
* **taiko-client-rs:** alethia reth update to 03fc0929b324aff68ee5bc26f1c0a8169b58060b ([#21458](https://github.com/taikoxyz/taiko-mono/issues/21458)) ([af0f38b](https://github.com/taikoxyz/taiko-mono/commit/af0f38b4596cafac1c10a2ec2c8ede807f72f553))
* **taiko-client-rs:** align Shasta manifest header decoding ([#21764](https://github.com/taikoxyz/taiko-mono/issues/21764)) ([d691584](https://github.com/taikoxyz/taiko-mono/commit/d691584a2c5ff30f9868e394ccc59b419e467a5b))
* **taiko-client-rs:** align Shasta parent anchor decoding with `taiko-client` ([#21532](https://github.com/taikoxyz/taiko-mono/issues/21532)) ([d7d9edb](https://github.com/taikoxyz/taiko-mono/commit/d7d9edb58c27af77ff48cad77035e245d16a9736))
* **taiko-client-rs:** build the LookaheadResolver with a scanner task ([#21295](https://github.com/taikoxyz/taiko-mono/issues/21295)) ([5d49db8](https://github.com/taikoxyz/taiko-mono/commit/5d49db858274dfa9404d2c303859ee8ea6e44120))
* **taiko-client-rs:** bump `alethia-reth` and tolerate Shasta origin lookup uncertainty ([#21227](https://github.com/taikoxyz/taiko-mono/issues/21227)) ([db069a2](https://github.com/taikoxyz/taiko-mono/commit/db069a26a40f4c1149e25c5eb3681ac47f0f42ff))
* **taiko-client-rs:** bump `alethia-reth` dependencies ([#21486](https://github.com/taikoxyz/taiko-mono/issues/21486)) ([3b5ac06](https://github.com/taikoxyz/taiko-mono/commit/3b5ac063e0ea363e978d03b7802a22496edb033f))
* **taiko-client-rs:** bump `event-scanner` to `0.8.0-alpha` ([#21024](https://github.com/taikoxyz/taiko-mono/issues/21024)) ([9961a31](https://github.com/taikoxyz/taiko-mono/commit/9961a314e8d8e041587f6984d6f6272fb7d75a96))
* **taiko-client-rs:** bump `event-scanner` to `1.0.0` ([#21174](https://github.com/taikoxyz/taiko-mono/issues/21174)) ([21ddb06](https://github.com/taikoxyz/taiko-mono/commit/21ddb0693c7188f0dd27fd3186a465a54d50b0c9))
* **taiko-client-rs:** bump `event-scanner` to `v1.0.0-rc.1` ([#21115](https://github.com/taikoxyz/taiko-mono/issues/21115)) ([07fe663](https://github.com/taikoxyz/taiko-mono/commit/07fe6630d168916b07c73cf1ee43ea4f59c10988))
* **taiko-client-rs:** bump alethia-reth dependency ([#21646](https://github.com/taikoxyz/taiko-mono/issues/21646)) ([b5e3860](https://github.com/taikoxyz/taiko-mono/commit/b5e3860e5f79389d7c7980b7e66700793bbab35d))
* **taiko-client-rs:** bump alethia-reth dependency and reuse `payload_id_taiko` ([#21183](https://github.com/taikoxyz/taiko-mono/issues/21183)) ([f8ba38d](https://github.com/taikoxyz/taiko-mono/commit/f8ba38d56a0d55e7dc918807c9e77c7ec1f10c98))
* **taiko-client-rs:** bump alethia-reth deps to latest main ([#21462](https://github.com/taikoxyz/taiko-mono/issues/21462)) ([6640f00](https://github.com/taikoxyz/taiko-mono/commit/6640f00e5fad14bd35a31b3cb820c549bded50c8))
* **taiko-client-rs:** bump dependency ver ([#21352](https://github.com/taikoxyz/taiko-mono/issues/21352)) ([087a04c](https://github.com/taikoxyz/taiko-mono/commit/087a04c1c83504dbbb01ee30e5e5b4358e3f8b29))
* **taiko-client-rs:** bump deps to `alloy 1.8` ([#21659](https://github.com/taikoxyz/taiko-mono/issues/21659)) ([9d1b842](https://github.com/taikoxyz/taiko-mono/commit/9d1b842e323811ee0fc7b3881b51bd43fd9b6444))
* **taiko-client-rs:** bump Docker build Rust toolchain ([#21398](https://github.com/taikoxyz/taiko-mono/issues/21398)) ([911679f](https://github.com/taikoxyz/taiko-mono/commit/911679f2d3c90c197549574e64162ffe6689e2ba))
* **taiko-client-rs:** disable Unzen fork on Hoodi ([#21696](https://github.com/taikoxyz/taiko-mono/issues/21696)) ([b5614df](https://github.com/taikoxyz/taiko-mono/commit/b5614dfecb720214d3b7348c5055f57ac3db8c71))
* **taiko-client-rs:** gate signer behind net feature ([#21605](https://github.com/taikoxyz/taiko-mono/issues/21605)) ([0130a6e](https://github.com/taikoxyz/taiko-mono/commit/0130a6eeae45e4f9ef5b76f9f04363abc858e2f2))
* **taiko-client-rs:** improve comments ([#21344](https://github.com/taikoxyz/taiko-mono/issues/21344)) ([748467c](https://github.com/taikoxyz/taiko-mono/commit/748467cfd0384af497715f77eba7056940c61ee9))
* **taiko-client-rs:** keep host features out of no-default build ([#21604](https://github.com/taikoxyz/taiko-mono/issues/21604)) ([3ecc25e](https://github.com/taikoxyz/taiko-mono/commit/3ecc25e612e9fae238abb33a0b81c1897e29f9c1))
* **taiko-client-rs:** make preconf server API methods public to be accessed by crate users ([#21296](https://github.com/taikoxyz/taiko-mono/issues/21296)) ([a099505](https://github.com/taikoxyz/taiko-mono/commit/a09950572696cf0ba50b6728a96ea285e5c0ddfa))
* **taiko-client-rs:** manifest decoding errors instead of None ([#21168](https://github.com/taikoxyz/taiko-mono/issues/21168)) ([18d09fe](https://github.com/taikoxyz/taiko-mono/commit/18d09fe60de0a960a0a0ca65a5acfe02f35ec7cb))
* **taiko-client-rs:** missing driver crate licence ([#21308](https://github.com/taikoxyz/taiko-mono/issues/21308)) ([dba22a9](https://github.com/taikoxyz/taiko-mono/commit/dba22a9dc35bae275ab68496b16ebe43aeea3824))
* **taiko-client-rs:** preserve lookahead error semantics for slot info RPC ([#21286](https://github.com/taikoxyz/taiko-mono/issues/21286)) ([7b50fce](https://github.com/taikoxyz/taiko-mono/commit/7b50fceea159cb5b714a5bf83372514b4ad03be1))
* **taiko-client-rs:** rename difficulty to mixHash after Uzen ([#21570](https://github.com/taikoxyz/taiko-mono/issues/21570)) ([b6e564f](https://github.com/taikoxyz/taiko-mono/commit/b6e564fca160cd6cc514b3193b26f447781c25be))
* **taiko-client-rs:** rust 1.94, dependecies update ([#21633](https://github.com/taikoxyz/taiko-mono/issues/21633)) ([6ea4287](https://github.com/taikoxyz/taiko-mono/commit/6ea4287f37497fc77bb3f9a125e78720bfeb5fe2))
* **taiko-client-rs:** several improvments for preconfirmation-driver ([#21330](https://github.com/taikoxyz/taiko-mono/issues/21330)) ([d6d67ec](https://github.com/taikoxyz/taiko-mono/commit/d6d67ecd2eee992648aaae8c5f296da700327d97))
* **taiko-client-rs:** support Masaya chain id `167011` in Shasta fork config ([#21301](https://github.com/taikoxyz/taiko-mono/issues/21301)) ([938c05d](https://github.com/taikoxyz/taiko-mono/commit/938c05d23309916ab0a8c0840b1d3494c3fd553c))
* **taiko-client-rs:** update `event-scanner` && `alethia-reth` ([#20805](https://github.com/taikoxyz/taiko-mono/issues/20805)) ([811e34d](https://github.com/taikoxyz/taiko-mono/commit/811e34d7fee38302c5e362586e7f9de7bfb398b5))
* **taiko-client-rs:** update `SHASTA_FORK_MAINNET` ([#21547](https://github.com/taikoxyz/taiko-mono/issues/21547)) ([1d1e6da](https://github.com/taikoxyz/taiko-mono/commit/1d1e6da5be399f9f74f19fb0f760d3ffcbb14f73))
* **taiko-client-rs:** update alethia reth pin ([#21708](https://github.com/taikoxyz/taiko-mono/issues/21708)) ([a2a2e66](https://github.com/taikoxyz/taiko-mono/commit/a2a2e66d981d875b21026c99ee793175b6c60c02))
* **taiko-client-rs:** update alethia reth pin ([#21712](https://github.com/taikoxyz/taiko-mono/issues/21712)) ([43d7bd2](https://github.com/taikoxyz/taiko-mono/commit/43d7bd2005b73287145f399c9b797016896ce5db))
* **taiko-client-rs:** update alethia reth pin ([#21733](https://github.com/taikoxyz/taiko-mono/issues/21733)) ([a8863d1](https://github.com/taikoxyz/taiko-mono/commit/a8863d11437b6e4789d9294ee0256ed14d8c26d3))
* **taiko-client-rs:** update alethia reth pin ([#21736](https://github.com/taikoxyz/taiko-mono/issues/21736)) ([9fe9052](https://github.com/taikoxyz/taiko-mono/commit/9fe9052b74a9c99c5f3d7aceba70b128145840d8))
* **taiko-client-rs:** update alethia reth pin ([#21747](https://github.com/taikoxyz/taiko-mono/issues/21747)) ([b153bbc](https://github.com/taikoxyz/taiko-mono/commit/b153bbcf76289e679d3853acc38278adf3edfd52))
* **taiko-client-rs:** update base image from ubuntu 22.04 to 24.04 ([#21415](https://github.com/taikoxyz/taiko-mono/issues/21415)) ([0b7e0f6](https://github.com/taikoxyz/taiko-mono/commit/0b7e0f6e7901be56ff15f1d531aee44bb12b245c))
* **taiko-client-rs:** update Shasta constants ([#21266](https://github.com/taikoxyz/taiko-mono/issues/21266)) ([cab48cc](https://github.com/taikoxyz/taiko-mono/commit/cab48cca0a8dbd0ba10015629b409604541d17db))
* **taiko-client-rs:** updated Cargo.lock security related dependencies ([#21611](https://github.com/taikoxyz/taiko-mono/issues/21611)) ([b488bdd](https://github.com/taikoxyz/taiko-mono/commit/b488bdd740e21a9de796b7581149521399878129))
* **taiko-client-rs:** use `taikoAuth` batch lookups and error handling ([#21241](https://github.com/taikoxyz/taiko-mono/issues/21241)) ([ca00003](https://github.com/taikoxyz/taiko-mono/commit/ca00003f21c6ef6a10142e14558609d934b96433))
* **taiko-client-rs:** use alethia-reth chainspec forks ([#21698](https://github.com/taikoxyz/taiko-mono/issues/21698)) ([678ae4d](https://github.com/taikoxyz/taiko-mono/commit/678ae4d767a41ca3820af906529271576a32b0bc))
* **taiko-client-rs:** validate blob server KZG data ([#21766](https://github.com/taikoxyz/taiko-mono/issues/21766)) ([4177feb](https://github.com/taikoxyz/taiko-mono/commit/4177febfd3d5b1d0617a37f2e20222daa25adb22))
* **taiko-client,taiko-client-rs:** align execution deps and Hoodi Unzen time ([#21654](https://github.com/taikoxyz/taiko-mono/issues/21654)) ([0942707](https://github.com/taikoxyz/taiko-mono/commit/09427074352023bc262f5a907d41f0c8b02cd3ea))
* **taiko-client,taiko-client-rs:** bump execution client dependencies ([#21721](https://github.com/taikoxyz/taiko-mono/issues/21721)) ([89afa8e](https://github.com/taikoxyz/taiko-mono/commit/89afa8e47ed69d095fe44aa3e50db233ae8b13a9))
* **taiko-client,taiko-client-rs:** bump execution client dependencies ([#21778](https://github.com/taikoxyz/taiko-mono/issues/21778)) ([ffce7c8](https://github.com/taikoxyz/taiko-mono/commit/ffce7c8aea3867d3dbd52a7da50d776daa5774e2))
* **taiko-client,taiko-client-rs:** bump execution client deps ([#21603](https://github.com/taikoxyz/taiko-mono/issues/21603)) ([af02afc](https://github.com/taikoxyz/taiko-mono/commit/af02afc645e6a8c352b69d5ebffe9d1c9f3fb052))
* **taiko-client,taiko-client-rs:** bump execution deps ([#21671](https://github.com/taikoxyz/taiko-mono/issues/21671)) ([cdb811a](https://github.com/taikoxyz/taiko-mono/commit/cdb811a130759010378cdd05fb16b06e9597f1c6))
* **taiko-client,taiko-client-rs:** bump Hoodi Unzen execution deps ([#21689](https://github.com/taikoxyz/taiko-mono/issues/21689)) ([fd88b22](https://github.com/taikoxyz/taiko-mono/commit/fd88b22c42eab091397d6269a9dad68464028cec))
* **taiko-client,taiko-client-rs:** bump taiko-geth and alethia-reth to latest ([#21753](https://github.com/taikoxyz/taiko-mono/issues/21753)) ([1d76df6](https://github.com/taikoxyz/taiko-mono/commit/1d76df6294b2784ddaf6b50da8ea189f0d1f3705))
* **taiko-client,taiko-client-rs:** bump taiko-geth and alethia-reth to latest ([#21755](https://github.com/taikoxyz/taiko-mono/issues/21755)) ([fb8b852](https://github.com/taikoxyz/taiko-mono/commit/fb8b852f4c91b397cfb95bfdbf0bcd0b708fb50c))
* **taiko-client,taiko-client-rs:** update Go / Rust contract bindings ([#20961](https://github.com/taikoxyz/taiko-mono/issues/20961)) ([f1118e6](https://github.com/taikoxyz/taiko-mono/commit/f1118e691b52bf22dc03c868f8db9be2368f4cfd))
* **taiko-client,taiko-client-rs:** update Go / Rust contract bindings ([#21171](https://github.com/taikoxyz/taiko-mono/issues/21171)) ([96d2f0a](https://github.com/taikoxyz/taiko-mono/commit/96d2f0afbf4be894aa3c6a4593eae7fa2d809629))
* **taiko-client,taiko-client-rs:** update Go / Rust contract bindings ([#21176](https://github.com/taikoxyz/taiko-mono/issues/21176)) ([fe6a678](https://github.com/taikoxyz/taiko-mono/commit/fe6a67842f9f9da48f6b4665f49b9a471b971417))
* **taiko-client,taiko-client-rs:** update Go / Rust contract bindings ([#21193](https://github.com/taikoxyz/taiko-mono/issues/21193)) ([34c446d](https://github.com/taikoxyz/taiko-mono/commit/34c446de200a0856863615936c8ce1e94097981f))
* **taiko-client:** improve `ResetL1Current` to set Shasta anchor number ([#20761](https://github.com/taikoxyz/taiko-mono/issues/20761)) ([14f9367](https://github.com/taikoxyz/taiko-mono/commit/14f93671c2fbea1cd747ad5779cc1507eeadda53))


### Documentation

* **taiko-client-rs:** codify cross-crate preconfirmation/event-sync guardrails and invariant references ([#21334](https://github.com/taikoxyz/taiko-mono/issues/21334)) ([8ef6d54](https://github.com/taikoxyz/taiko-mono/commit/8ef6d54707fcf1233e590979eaeb5621d1c5d7d5))


### Code Refactoring

* **taiko-client-rs, preconfirmation-p2p:** simplify codebase by consolidating single-file submodules ([#21142](https://github.com/taikoxyz/taiko-mono/issues/21142)) ([41ec2ee](https://github.com/taikoxyz/taiko-mono/commit/41ec2ee64008c9784b5365bba944774f1d740b74))
* **taiko-client-rs:** avoid cloning preconfirmation execution payload ([#21027](https://github.com/taikoxyz/taiko-mono/issues/21027)) ([2b6c078](https://github.com/taikoxyz/taiko-mono/commit/2b6c07814c1a685cf49aaa087c3da47c988933e9))
* **taiko-client-rs:** centralize `whitelist-preconfirmation-driver` error handling and harden validation paths ([#21390](https://github.com/taikoxyz/taiko-mono/issues/21390)) ([c2ca581](https://github.com/taikoxyz/taiko-mono/commit/c2ca581078c9a9e4afd98ab1da34cc50b8385bb6))
* **taiko-client-rs:** consolidate shared assembly and collapse single-impl abstractions ([#21776](https://github.com/taikoxyz/taiko-mono/issues/21776)) ([6d9b444](https://github.com/taikoxyz/taiko-mono/commit/6d9b444148a354768cb37854d2d00401f05b3fc4))
* **taiko-client-rs:** consolidate whitelist preconfirmation driver helpers ([#21771](https://github.com/taikoxyz/taiko-mono/issues/21771)) ([8e2207b](https://github.com/taikoxyz/taiko-mono/commit/8e2207b092ba3ff6a0badca2b96e6aeca96de9b1))
* **taiko-client-rs:** consume preconf receiver exactly once ([#21498](https://github.com/taikoxyz/taiko-mono/issues/21498)) ([505d55f](https://github.com/taikoxyz/taiko-mono/commit/505d55f5b948c2bfcb25123226830c06e71a8768))
* **taiko-client-rs:** introduce `DriverApiError` for driver preconf RPC errors ([#21139](https://github.com/taikoxyz/taiko-mono/issues/21139)) ([da8a475](https://github.com/taikoxyz/taiko-mono/commit/da8a4753cb462927e1273ab2032e7b3fc4133532))
* **taiko-client-rs:** refactor whitelist preconfirmation driver P2P + derive chain ID from L2 ([#21539](https://github.com/taikoxyz/taiko-mono/issues/21539)) ([a137b98](https://github.com/taikoxyz/taiko-mono/commit/a137b984fad900733cd25a0eddb04a8a6502ece4))
* **taiko-client-rs:** remove `proposal-id`/`canonical-tip` wiring and use confirmed head-state sync ([#21332](https://github.com/taikoxyz/taiko-mono/issues/21332)) ([519e9c6](https://github.com/taikoxyz/taiko-mono/commit/519e9c665c961bbae6cc2881bbb9f4b2bac32d3c))
* **taiko-client-rs:** remove some duplicated logs ([#21137](https://github.com/taikoxyz/taiko-mono/issues/21137)) ([19e2438](https://github.com/taikoxyz/taiko-mono/commit/19e24383819304f1f80aafa0c7b73c5b1dd31cce))
* **taiko-client-rs:** remove whitelist preconfirmation reqresp lookup path ([#21537](https://github.com/taikoxyz/taiko-mono/issues/21537)) ([6e28796](https://github.com/taikoxyz/taiko-mono/commit/6e28796897987712ff7732ac4f268bfb493615e0))
* **taiko-client-rs:** share fallback whitelist timeline across resolver clones, drop dead code ([#21774](https://github.com/taikoxyz/taiko-mono/issues/21774)) ([8219429](https://github.com/taikoxyz/taiko-mono/commit/8219429f2572ef65e8463e679a9897a28a227a06))
* **taiko-client-rs:** simplification sweep across all crates ([#21772](https://github.com/taikoxyz/taiko-mono/issues/21772)) ([8faa8e9](https://github.com/taikoxyz/taiko-mono/commit/8faa8e97a32e30c388287ff90d41104056d59ca4))
* **taiko-client-rs:** simplify and deduplicate across `rpc`, `driver`, and `CLI` ([#21571](https://github.com/taikoxyz/taiko-mono/issues/21571)) ([b521c27](https://github.com/taikoxyz/taiko-mono/commit/b521c2745398481b7d9fd751c9eb290be89d4084))
* **taiko-client-rs:** simplify some implementations in `whitelist-preconfirmation-driver` crate ([#21421](https://github.com/taikoxyz/taiko-mono/issues/21421)) ([3977c46](https://github.com/taikoxyz/taiko-mono/commit/3977c466fde470882a8e4f27429392e0cf40c1dd))
* **taiko-client-rs:** simplify whitelist preconf driver state and API types ([#21769](https://github.com/taikoxyz/taiko-mono/issues/21769)) ([8435b4c](https://github.com/taikoxyz/taiko-mono/commit/8435b4cb0797aeca6cecd436c7f04fe1fd39c537))
* **taiko-client-rs:** simplify whitelist preconfirmation driver ([#21768](https://github.com/taikoxyz/taiko-mono/issues/21768)) ([b6d1967](https://github.com/taikoxyz/taiko-mono/commit/b6d196703c32b07b9ab35d98a189cf7ff66aa419))
* **taiko-client-rs:** split oversized modules and simplify network / server flows ([#21389](https://github.com/taikoxyz/taiko-mono/issues/21389)) ([084f090](https://github.com/taikoxyz/taiko-mono/commit/084f090ee5564d41ff2ef704dcd95cd1b3d604b3))
* **taiko-client-rs:** split whitelist network runtime and bootstrap setup ([#21405](https://github.com/taikoxyz/taiko-mono/issues/21405)) ([43497de](https://github.com/taikoxyz/taiko-mono/commit/43497de04e81ead430ab47c61c742ced5520005f))
* **taiko-client,taiko-client-rs:** swap preconf whitelist check from coinbase to node P2P signer ([#21584](https://github.com/taikoxyz/taiko-mono/issues/21584)) ([5d62757](https://github.com/taikoxyz/taiko-mono/commit/5d6275785966683f783069f76d3982c05ccf7c7a))


### Tests

* **taiko-client-rs:** add event‑driven preconfirmation P2P integration test and pre‑dial hooks ([#21144](https://github.com/taikoxyz/taiko-mono/issues/21144)) ([85ee841](https://github.com/taikoxyz/taiko-mono/commit/85ee841f0b709c70512249603e32889e9b578c34))
* **taiko-client-rs:** comprehensive E2E tests for preconfirmation and driver flows ([#21151](https://github.com/taikoxyz/taiko-mono/issues/21151)) ([22487b7](https://github.com/taikoxyz/taiko-mono/commit/22487b7aed7ca456b28350820a3f18f9782d6b3d))
* **taiko-client-rs:** introduce new auth rpc & fix test ([#21594](https://github.com/taikoxyz/taiko-mono/issues/21594)) ([47e9878](https://github.com/taikoxyz/taiko-mono/commit/47e9878d36c92017c79ddfd75b6dcc93e7989d61))
* **taiko-client-rs:** use `test-context` to simplify tests ([#20866](https://github.com/taikoxyz/taiko-mono/issues/20866)) ([5176f13](https://github.com/taikoxyz/taiko-mono/commit/5176f13aa11118f0825ae93d48fecce110598819))
* **taiko-client-rs:** use WS endpoints for `ShastaEnv` test providers ([#21254](https://github.com/taikoxyz/taiko-mono/issues/21254)) ([d42b051](https://github.com/taikoxyz/taiko-mono/commit/d42b0518c20e3f785e840d40ce796bea4b983023))


### Workflow

* **repo:** fix taiko-client-rs test workflow  ([#21393](https://github.com/taikoxyz/taiko-mono/issues/21393)) ([6b940a3](https://github.com/taikoxyz/taiko-mono/commit/6b940a3b65c4e13ab520e5fe2205a3ca56589b7e))
* **taiko-client, taiko-client-rs:** improve ci timeout ([#21159](https://github.com/taikoxyz/taiko-mono/issues/21159)) ([3b7d6e8](https://github.com/taikoxyz/taiko-mono/commit/3b7d6e83c46bd4be2179d0319f024acf74dfb6f5))
