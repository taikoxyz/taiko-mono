# C1. Anchor-free L2 execution and checkpoint publication

**Owner:** B. **Reviewer:** A. **Independent reviewer:** J (DeepSeek).

**Status [open]:** proposed section, awaiting A's explicit verdict and J's review. This is a specification, not an implementation or an assertion about deployed contracts. It does not establish whole-protocol readiness, D1 confirmation, or a successful convergence round. The integration obligations in §10 remain open until their owning sections discharge them.

## 1. Scope, vocabulary and claim convention

**[assumed: section boundary]** C1 owns the L2 execution-header profile, standard system-operation order, L2 checkpoint authentication, origin pins and legacy-writer phase guard. C2 owns L1 origin selection/authentication, proof/data binding, retention duties and L1 checkpoint publication. C3 owns forced inclusion. C4 owns the authenticated migration boundary and the complete retained-surface change table, including the shared-contract selector audit. C7 owns composition of the complete block-validity predicate; C1 supplies its header/execution component. C8 owns the consolidated interface/message/upgrade artifact, referencing this module's declarations rather than maintaining duplicate rules. S2 owns sequencing rights, signed preconfirmation objects and slashable confirmation. S3 owns bonded duties and economic sanctions. C6 owns the assurance dashboard, accepted-limitations register and consolidated parameter index. Their rule text is not duplicated here. This scope incorporates D9 and DL-1 to DL-4 at `e8778cd6f88901b480204e2ad11aa21484d3ee6a`.

**[assumed: notation]** A paragraph or table headed **assumed** specifies a proposed rule or names a premise; it does not assert that the premise holds. **Proven** means a conditional argument or arithmetic derivation on this page, not machine verification. **Open** means unresolved, with the closure condition identified. An identifier `C1-Rxx` has exactly one normative definition below. Other tables refer to it. The parameter register is the sole definition of C1 numeric choices; examples use, rather than redefine, those choices. Source constants have upstream provenance, not a performance-measurement claim.

| Term | Definition [assumed: vocabulary] |
|---|---|
| Origin `O_b` | The L1 execution header selected for L2 block `b`, including its number, execution hash, state root and timestamp, authenticated under C2's rules. It is not an L1 beacon/SSZ root. |
| Current root | The word returned by the canonical L2 EIP-4788 getter for the currently executing L2 block's timestamp. |
| Pin | An irreversible-in-history membership bit for one origin hash at the existing L2 SignalService address. It stores neither a header nor a state root. Ordinary reorg rollback still applies. |
| Reveal | A normal user transaction supplying the complete RLP L1 execution header whose hash was authenticated through the oracle or a pin. |
| Checkpoint | The existing external tuple `(uint48 blockNumber, bytes32 blockHash, bytes32 stateRoot)` used by SignalService. Its persisted value remains two words. |
| Legacy writer | Any reachable Anchor, SignalService or router path capable of writing legacy checkpoint or Anchor progress state. |
| Execution validity | Correct execution under a complete, authenticated local context; distinct from canonicality, availability, certification and finality. |
| Caller | Any account or contract submitting a pin/reveal. This is an unbonded, voluntary action, not an exclusive or assigned protocol role. |

**[assumed: named premises]** The following names are used in the arguments, not as substitutes for other sections' specifications.

| Premise | Exact dependency |
|---|---|
| A-CRYPTO | Ethereum Keccak collision/second-preimage resistance and normal EVM authentication hold; nobody can authorize an ordinary transaction as the standard system address. |
| A-ORIGIN | C2 and the local derivation rules authenticate every selected origin against the intended L1 history and bind it to the same L2 block. A nonzero word alone is insufficient. |
| A-EXEC | Builder, importer and proof guest implement the same C1 profile and EVM semantics, including rollback. |
| A-HISTORY | C4 authenticates the inherited checkpoint mappings and received-signal caches, installs the specified code/guards, closes alternate writer routes, and preserves their storage. |
| A-INCLUSION | C3 eventually permits successful execution of the two valid calls described in §8 in an eventually stable canonical history, with their actual wrapper, EVM and proof costs. Queue advancement alone is insufficient; this eventual-stability premise is not a finality claim about an observed pin. |
| A-ORIGIN-PROGRESS | For recovery of a persistent remote signal, an eventual successful pin executes with an admissible processing origin whose state contains that signal, or such a checkpoint already exists. C2/C3 must establish this progress property. Mere existence of a suitable but never selected L1 header is insufficient. |
| A-FUNDING | A requester can supply a valid nonce and enough native ETH/gas/fee allowance for the eventual execution; any fee upper bound and refresh procedure are supplied by C3. |
| A-ARCHIVE | Someone can obtain the exact selected L1 header and a suitable remote SignalService account/storage proof. A hash commitment does not provide these bytes. |
| A-UPGRADE | The current reviewed implementations remain in effect for the history being evaluated. DAO upgrade authority is a separate governance assumption, not a daily liveness dependency. |

## 2. Execution profile

### C1-R01. Per-block origin and local validation

**[assumed: proposed rule]** Each Etna block has one C2-authenticated origin `O_b` and sets `header.parentBeaconBlockRoot = O_b.blockHash`, which is nonzero. C2's canonical block-data representation and proof statement bind that equality, the complete L2 header and its execution result. The C1 component of C7's local validity predicate checks the same equality and origin authentication before executing the block. Its component result is `UNKNOWN_CONTEXT` when required bytes/context are missing, `INVALID_C1` for a known contradiction and `C1_PASS` when these checks pass. `C1_PASS` is not whole-block validity; C7 composes the remaining predicates, and S2 defines confirmation labels and their consequences. C1 introduces no origin-age, origin-per-batch, finality or CL-lookahead rule. **Adversary schedule:** a producer supplies a fabricated execution hash, a genuine orphaned origin, a beacon root, or different origins to the importer and prover. A-ORIGIN is indispensable to rejecting the latter history/context attacks; the oracle alone cannot do so.

### C1-R02. System operations and block structure

**[assumed: proposed rule]** On the first Etna block and every successor, execute the standard EIP-4788 operation, then the standard EIP-2935 operation, before ordinary transactions. Use the addresses, caller, calldata and allowances in §6 and the upstream semantics in [E4788] and [E2935]. These are system operations, not transactions: no synthetic transaction, receipt, log, account nonce increment, Anchor gas reserve or contribution to ordinary block `gasUsed` is created. Their state writes enter the resulting state root. No transaction position is reserved for an anchor; a zero-transaction block is permitted. A pin/reveal, when present, is an ordinary transaction with ordinary fees and receipts. Preserve upstream no-code silence and genesis exceptions; the migration preconditions in C1-R09 ensure Etna does not depend on that no-code behavior. The first Etna block is a non-genesis child of C4's authenticated boundary. **Adversary schedule:** an empty first block, a producer inserting a fake anchor receipt, or builder/guest disagreement about operation order and gas accounting.

### C1-R03. Timestamp and metadata encoding

**[assumed: proposed profile, metadata choice pending P-B-C1-01]** Etna header timestamps are positive, strictly increasing from their parent, and fit the existing checkpoint-width profile in §6. Encode `extraData` as exactly `feeShare:u8 || termId:u32BE || view:u8 || kind:u8`, with no prefix, padding or trailing bytes. The fee-share byte has the value in §6. S2 assigns term and view semantics; C3/S2 assign kind semantics and permitted values. Reject values outside these physical widths; exhaustion requires an explicit protocol upgrade, never silent wraparound. S2/C2 publish and bind the full preconfirmation metadata removed with anchor calldata, including any seat, view-change and carried-certificate identities used by their rules. The signing, data and proof identities must distinguish conflicting metadata envelopes for the same execution hash. This paragraph specifies that interface obligation; those sections own its encoding and predicates. **Adversary schedule:** a producer reuses one execution hash with two `vcHash` or carried-certificate envelopes, or a prover omits one envelope. Seven bytes of `extraData` do not themselves bind those omitted fields. This attack remains **open** until the cross-section identity is specified. The choice of layout is a proposal for review, not an assertion of prior agreement.

**[proven: representation limit]** Unix-time seconds and strictly increasing integer timestamps permit a target of one block per second without reference to an L1 slot length. They do not prove one-second issuance, two-second D1 confirmation, network propagation or prover throughput. Those timing/service claims belong to S2/S4 and remain dependent on measured implementation behavior.

## 3. In-place interface and authentication rules

**[assumed: interface declaration]** The following are interface sketches only. Existing methods/events retain their selectors/topics; new declarations extend the existing L2 SignalService proxy. There is no new Bridge, SignalService or Vault address. `saveCheckpoint` and `getCheckpoint` are the existing ABI. Parameter names are descriptive, not ABI changes. NatSpec summarizes rule references rather than restating validation predicates.

```solidity
interface IEtnaCheckpointStore {
    struct Checkpoint {
        uint48 blockNumber;
        bytes32 blockHash;
        bytes32 stateRoot;
    }

    event CheckpointSaved(uint48 indexed blockNumber, bytes32 blockHash, bytes32 stateRoot);
    event OriginPinned(bytes32 indexed originHash, uint64 indexed l2Timestamp);

    /// @notice Apply C1-R06 and the layer-specific C1-R07 writer authorization.
    /// @param _checkpoint The existing checkpoint tuple.
    function saveCheckpoint(Checkpoint calldata _checkpoint) external;

    /// @notice Read according to C1-R06.
    /// @param _blockNumber Remote execution block number.
    /// @return checkpoint_ The stored tuple.
    function getCheckpoint(uint48 _blockNumber) external view returns (Checkpoint memory checkpoint_);

    /// @notice Pin according to C1-R05.
    /// @return originHash_ The authenticated current origin hash.
    function pinCurrentOrigin() external returns (bytes32 originHash_);

    /// @notice Read pin membership according to C1-R05.
    /// @param _originHash The queried hash.
    /// @return pinned_ Whether membership is present.
    function isOriginPinned(bytes32 _originHash) external view returns (bool pinned_);

    /// @notice Reveal according to C1-R08.
    /// @param _l2Timestamp Oracle lookup timestamp, or the reserved pin sentinel.
    /// @param _l1HeaderRlp Complete canonical RLP execution header.
    /// @return checkpoint_ The authenticated existing-format tuple.
    function revealCheckpoint(uint64 _l2Timestamp, bytes calldata _l1HeaderRlp)
        external returns (Checkpoint memory checkpoint_);
}
```

**[assumed: implementation error ABI]** These declarations describe the implementation's errors, not additional interface methods. Existing `SS_UNAUTHORIZED()`, `SS_INVALID_CHECKPOINT()` and `SS_CHECKPOINT_NOT_FOUND()` remain.

```solidity
error EtnaWrongMode();
error EtnaOracleUnavailable();
error EtnaWrongPhase();
error EtnaHeaderSize();
error EtnaMalformedHeader();
error EtnaFutureTimestamp();
error EtnaUnknownOrigin();
error EtnaCheckpointConflict(uint48 _blockNumber);
error EtnaCheckpointCorrupt(uint48 _blockNumber);
```

### C1-R04. Authenticated oracle read and current-root guard

**[assumed: proposed rule]** Implementations have an immutable deployment mode, `L1_INBOX` or `L2_ORIGIN`, fixed by the reviewed implementation installed through C4. Do not infer mode from caller input, RPC chain names or a root's shape. L2 oracle reads first verify the canonical address's runtime code hash against §6, then make `STATICCALL` with the specified read gas operand, zero value, raw 32-byte big-endian timestamp input and a fixed 32-byte output buffer. Require success and exactly 32 bytes of return data; any mismatch is `EtnaOracleUnavailable()`. Do not allocate/copy arbitrary return data. Normal EIP-150 and caller gas limits still apply. For phase checks read `block.timestamp`, never a supplied timestamp. A successful zero word means legacy phase; a successful nonzero word means Etna phase. Missing code, a missing timestamp, revert and exhausted gas are not zero. **Adversary schedule:** a caller exploits a read failure, hostile replacement runtime or a stale supplied timestamp to reopen the publicly accessible legacy signer path.

### C1-R05. Pin operation

**[assumed: proposed rule]** `pinCurrentOrigin()` is nonpayable and permissionless. In order: require `L2_ORIGIN` or `EtnaWrongMode`; apply C1-R04 to the current timestamp; require a nonzero result or `EtnaWrongPhase`; set that hash's pin bit if absent, emitting `OriginPinned(hash, uint64(block.timestamp))` only on the first write; return the hash in both cases. There is no user-selected origin or timestamp, no automatic checkpoint write and no unpin operation. `isOriginPinned` is an unrestricted view of the bit; the zero hash returns false. An L1 deployment returns false for that view and rejects both new mutations. **Adversary schedule:** an attacker asks to pin a private, old or nonexistent origin, or repeatedly pins the same origin to manufacture events. Only the processing block's authenticated current word can create membership.

### C1-R06. Shared checkpoint record operation

**[assumed: proposed rule]** All accepted writes into the existing checkpoint map use one operation with the following order. Reject a zero supplied hash or root using existing `SS_INVALID_CHECKPOINT()`. Read both stored words at the supplied block number. If both are zero, write the two-word record and emit the existing `CheckpointSaved` event. If exactly one is zero, revert `EtnaCheckpointCorrupt(number)`. If both match the supplied tuple, return without writing or emitting. Otherwise revert `EtnaCheckpointConflict(number)`. No global latest-number restriction applies. The getter returns the stored tuple only if both words are nonzero; both zero gives existing `SS_CHECKPOINT_NOT_FOUND()`, and a partial record gives `EtnaCheckpointCorrupt(number)`. The internal getter used for signal proofs follows the same rule. **Adversary schedule:** out-of-order valid reveals, racing duplicates, same-height conflicts or an inherited partial record. Exact duplicates do not become a new authenticated source; their original provenance is A-HISTORY or a prior valid write. These conflict/idempotence checks are proposed changes: baseline SignalService currently overwrites records [SS-WRITE].

### C1-R07. Writer authority and legacy closure

**[assumed: proposed rule]** On L1, `saveCheckpoint` retains exact immutable Inbox authorization, then applies C1-R06; it does not use an L1 beacon root as authority for an L2 state root. On L2, the legacy `saveCheckpoint` path retains exact legacy syncer authorization, then requires a successful current zero read under C1-R04, then applies C1-R06. Each reachable legacy Anchor writer similarly retains its legacy sender authorization and requires the successful current zero read before any progress/checkpoint writes. Nonzero gives `EtnaWrongPhase`; read failures retain C1-R04's error. These checks apply through all inherited, delegated and fork-router routes, not just newly named methods. Other legacy validation still applies. C4 owns removal of unrelated operational powers and selection of the guarded implementations. **Adversary schedule:** invoke the old golden-touch Anchor at ordinary transaction zero in the first Etna block, call SignalService through an old router target, or call L2 reveal logic on L1. A voluntary pin or reveal must not be necessary to close a writer.

### C1-R08. Reveal operation, parser and precedence

**[assumed: proposed rule]** `revealCheckpoint` is nonpayable and permissionless. Its ordered algorithm is:

1. Require `L2_ORIGIN`, else `EtnaWrongMode`; apply the current-read guard C1-R04 and require nonzero, else `EtnaWrongPhase`. This occurs even for a duplicate or a pinned historical reveal.
2. Check nonempty input and the raw-header byte cap before any input-dependent allocation; otherwise `EtnaHeaderSize`. Compute `h = keccak256(the entire supplied header bytes)` using Ethereum Keccak, not SHA3-256. Reject zero `h` with `SS_INVALID_CHECKPOINT`.
3. Parse one canonical RLP list consuming the whole input, with the field-count bounds in §6. Every field is a scalar byte string. Reject nested lists, trailing bytes, truncated payloads, nonminimal short/long forms, leading zeros in length-of-length, overflow and out-of-bounds offsets with `EtnaMalformedHeader`. Field 0 (parent hash) and field 3 (state root) have the fixed hash width. Fields 8 (number) and 11 (timestamp) are minimal unsigned integers bounded by the checkpoint-width profile; zero is the empty RLP string, not byte `0x00`. No truncating cast is permitted. Other fields are parsed canonically without assuming their future semantics. A zero state root gives `SS_INVALID_CHECKPOINT`. Construct `(number, h, stateRoot)`.
4. Inspect the existing record using C1-R06's partial/conflict/duplicate cases. This step is read-only, including when the record is empty; do not invoke the fresh-writing branch yet. An exact duplicate returns immediately without consulting a historical ring entry or pin. This is deliberately idempotent after ring eviction. A conflicting or partial record errors before the remaining timestamp checks.
5. For a fresh record: if `l2Timestamp` is the pin sentinel, require `pinned[h]`, else `EtnaUnknownOrigin`. Otherwise require `l2Timestamp <= block.timestamp`, else `EtnaFutureTimestamp`; read that timestamp through C1-R04 (reuse the current read when equal), and require its nonzero word equals `h`, else `EtnaUnknownOrigin`. An unavailable historical read gives `EtnaOracleUnavailable`. Never query the oracle with the pin sentinel.
6. Apply the fresh-write branch of C1-R06 and return the tuple. Revealing through a timestamp does not implicitly pin the hash.

Normal ABI decoding errors, nonpayable-value rejection and transaction out-of-gas are EVM/compiler errors outside that ordered body. No check compares the L1 number to the current L2 number. No requirement makes the current root equal an older pinned root. **Adversary schedule:** a fabricated header prefix, an authentic hash paired with an unrelated state root, noncanonical RLP, overwide integers, expiration before inclusion, or a different header at an already used height.

## 4. Fork, state and storage

### C1-R09. Activation and rollback boundary

**[assumed: proposed rule]** C4's authenticated terminal legacy state includes the exact standard utility runtimes, correctly bound SignalService implementations, both guarded legacy writers and closure of all alternate writer routes before the first Etna ordinary transaction. Any earlier legacy blocks executed with those guarded writers must actually perform the standard current-timestamp zero-root recording, so their guards can succeed. Do not invent retroactive writes into old state roots. At activation C1-R02 consumes the first nonzero origin; no phase-changing user transaction or administrator action participates. Following activation, a child block with a zero origin is invalid under C1-R01, including during a stall. Ordinary reorg processing rolls back storage, code and block context together. Resuming a different legacy execution regime requires a separately specified C4 forward upgrade with authenticated history/state reconstruction; oracle reset, failed reads and automatic zero-root fallback are not rollback mechanisms. **Adversary schedule:** partially migrate the writer/reader pair, withhold the first user reveal, reorganize the upgrade, or reopen the old signer path after Anchor history has stopped advancing.

### C1-R10. Storage compatibility and bridge-facing semantics

**[assumed: proposed rule]** Keep existing proxy addresses, checkpoint version, inherited fields, received-signal cache, signal-slot derivation, checkpoint map root/value ordering and legacy gaps at their original locations. Add only the namespaced pin map defined below; deployment mode is an implementation immutable, not an inserted storage field. No pin/reveal changes a sent-signal value, received-signal cache or Bridge reimbursement count. Preserve the existing nonempty one-hop SignalService proof ABI, remote SignalService binding and ordinary Bridge/Vault message paths; C4 separately audits every upgraded operational selector. The obsolete Anchor's history/progress storage remains frozen after activation and readable under the legacy ABI, not emulated from the finite EIP-2935 window. All new pin/checkpoint mutations are already enumerated in C1-R05 to C1-R08; there is no administrator repair or pruning mutation. **Adversary schedule:** upgrade to a three-word checkpoint record, shift the mapping version, repurpose an Anchor slot, count pin SSTOREs as Bridge cache reimbursements, or retain a hidden administrative writer.

**[assumed: source-layout reference, live deployment audit open]** At snapshot [BASE], `SignalService_Layout.sol` reports Pacaya reserved slots 251 to 252, received signals at 253, checkpoint map at 254 and gap 255 to 300 [SS-LAYOUT]. VERSION is 1 [SS-STRUCT]. For `n:uint48`, the checkpoint's hash slot is

```text
outer = keccak256(abi.encode(uint256(1), uint256(254)))
record = keccak256(abi.encode(n, outer))
hash at record; stateRoot at record + 1 (EVM 256-bit slot arithmetic)
```

**[assumed: proposed new namespace]** The pin map's sole mapping root is:

```text
P = keccak256(abi.encode(
      uint256(keccak256(bytes("taiko.etna.origin-pins.v1"))) - 1
    )) & ~bytes32(uint256(0xff))
pin[h] at keccak256(abi.encode(h, P)); absent = 0, present = 1
```

**[proven: compatibility, conditional]** The namespace addition and immutable mode do not shift an existing slot. This does not prove the live deployment layout or a future compiled upgrade matches the source layout; C4 must compare them. The baseline mapping and helper are private [SS-STRUCT], so a compatible base refactor or replacement implementation is needed; an inaccessible subclass override is not an implementation plan. Storage collision resistance remains A-CRYPTO.

**[assumed: baseline interface fact]** Existing Anchor storage is `blockHashes` at 251, reserved 252 to 254, deprecated field 255, `BlockState` 256 to 257 and gap 258 to 300 [ANCHOR-LAYOUT]. C1 adds no Anchor storage, no anchorV5, no mandatory Anchor call and no new callback from SignalService to Anchor. C4 owns disabling its owner withdrawal and all shared owner/pauser/resolver operational powers. Merely zeroing a pauser immutable would leave owner authorization in baseline SignalService [SS-PAUSE].

**[proven: authentication flow, conditional]** The L2 flow is `C2-authenticated L1 header hash -> standard L2 oracle -> pin or live timestamp -> full-header reveal -> existing L2 checkpoint map -> existing remote account/storage proof verification -> Bridge/Vault`. The reverse L1 flow remains `C2-accepted L2 execution proof -> authorized Inbox saveCheckpoint -> existing L1 checkpoint map`. This section does not authorize publication of an unproved L2 root. C2 must define which proof status permits that custody write, including its proposed degraded mode.

## 5. State machines and call flow

**[proven: state-machine projection of the rules]** These tables are projections, not additional transition rules.

| Object | State transition | Rule / rollback |
|---|---|---|
| L2 block | received -> C1 component result -> whole-block validity | C1-R01 to C1-R03; C7 owns predicate composition and S2 certificate states |
| Execution-valid block | current-view state -> landed/final/orphaned | C2/S2, not decided by a pin or checkpoint |
| Writer phase | guarded legacy zero -> Etna nonzero before ordinary transactions | C1-R02, C1-R07, C1-R09 |
| Origin hash | unpinned -> pinned; repeated pin is a self-transition | C1-R05; reorg can undo the pin |
| Origin hash | available ring entry -> overwritten ring entry | standard timestamp-indexed oracle; does not erase a pin |
| Checkpoint number | empty -> present; exact duplicate is a self-transition | C1-R06, C1-R08; conflict has no state effect |
| Caller | absent -> submits ordinary call -> absent | any funded account, no registration/exit delay; C1-R05/C1-R08 |

```text
normal block
  C2 origin + S2 sequencing context
       -> validate header profile
       -> EIP-4788 -> EIP-2935 -> ordinary transactions -> state root
                                                 |
                       optional pin/reveal ------+-> existing SignalService

censorship / expired ring
  requester -> C3: force pinCurrentOrigin()
  later successful processing -> pin actual processing origin
  requester retrieves that origin's full header
            -> C3: force revealCheckpoint(pin sentinel, full header)
  later successful processing -> existing checkpoint map -> ordinary bridge proof

partial upgrade / first-block old signer
  old signer -> guarded Anchor -> current nonzero root -> revert
  alternate old route -> prohibited by C4 activation precondition

prover failure or L1/L2 reorg
  C2/S2 recovery changes canonical block history
       -> normal state rollback, including oracle, pins and checkpoints
       -> recompute C1 state on the accepted replacement history
```

**[assumed: caller incentives/failure profile]** Entry/exit are ordinary transaction submission and stopping submission. There is no exclusive duty, protocol reward, bond or slash for merely attempting a pin/reveal. A malformed attempt pays normal gas and has no accepted write. Successful callers gain checkpoint availability for their own or others' bridging. If all callers go offline, optional checkpoint freshness stops but block execution does not wait for them; any new funded caller may resume. If all callers are malicious, accepted writes are still constrained by C1's predicates, but they can maximize permanent state growth and need not serve archived data. Bonded availability or execution duties and their slashing evidence belong to S3/S4; C1 creates no slashable evidence of a P2P failure to serve.

## 6. Numeric and bytecode register

**[assumed: rule-owned register]** These are C1's sole numeric definitions. C6 should index these identifiers and their status, not maintain a second normative copy. Units are bytes, gas, seconds or block numbers, never CL slots/epochs. Values marked unmeasured are proposed spec parameters under D2, not benchmark results.

| ID | Value / unit | Derivation, rationale and status |
|---|---|---|
| P-HASH | 32 bytes | **assumed:** Ethereum Keccak/EVM word width and existing checkpoint hash/root ABI. |
| P-NUMBER | 48 bits, unsigned | **assumed:** existing checkpoint-number ABI; proposed same upper bound for header timestamps to share the legacy profile. Maximum `2^48 - 1`, **derived**. Scope/width adoption belongs in C2's origin profile as well. |
| P-PIN-SENTINEL | 0 | **assumed:** oracle rejects timestamp zero; reserves the pin path without ambiguous oracle input. |
| P-RING | 8,191 | **assumed:** standard [E4788] modulus in seconds; [E2935] predecessor window in block numbers. Same number, different indexing. |
| P-SYSTEM-GAS | 30,000,000 gas per operation | **assumed:** upstream system-operation allowance [E4788], [E2935], not ordinary block gas usage or measured consumption. |
| P-READ-GAS | 100,000 gas operand | **open/unmeasured:** proposed bounded getter STATICCALL allowance. Intended to cover cold code/storage access under the selected fork. Client/contract gas measurement and fork repricing review required. Insufficient allowance fails closed and can halt checkpoint publication. |
| P-HEADER-BYTES | 1,536 bytes | **open/unmeasured:** proposed parser/forced-call resource envelope, not a universal Ethereum header maximum. C2 must restrict the supported origin-header fork profile accordingly; future larger headers require an upgrade before use. |
| P-HEADER-FIELDS | minimum 12, maximum 32 scalar fields | **assumed:** 12 reaches timestamp at index 11; **open/unmeasured** upper cap is a parser resource choice. Compatibility with all supported forks must be checked. |
| P-EXTRA | 7 bytes | **derived:** one fee byte + four term bytes + one view byte + one kind byte. Choice pending P-B-C1-01. |
| P-FEE-SHARE | 100 percent (byte `0x64`) | **assumed proposal:** all current native-ETH base fee goes to the block coinbase, matching candidate profiles rather than an Anchor withdrawal path. S3 must define the selected chain's fee accounting and rewards consistently; no C1 proof of nonrecoupable storage cost. |
| P-TERM / P-VIEW / P-KIND | unsigned 32 / 8 / 8 bits | **assumed proposal:** candidate A header allocation, pending P-B-C1-01. Semantic limits and reserved encodings owned by S2/C3. |
| P-FI-EXAMPLE-GAS | 1,000,000 gas | **open/unmeasured:** illustrative transaction envelope for §8 arithmetic, not a selected C3 cap and not an execution/proof gas claim. |

**[assumed: upstream constants]** The bytecode below is the runtime portion of the deployment input in the pinned EIPs, with the initial nine-byte constructor removed. `expectedCodeHash = keccak256(exact runtime bytes)`. Runtime identity, not merely nonempty code, is the C1-R04 predicate. C4 records and checks the resulting code hashes in its activation manifest.

| Constant | Exact value |
|---|---|
| System caller | `0xfffffffffffffffffffffffffffffffffffffffe` |
| EIP-4788 address | `0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02` |
| EIP-2935 address | `0x0000F90827F1C53a10cb7A02335B175320002935` |
| EIP-4788 system calldata | raw P-HASH-byte `header.parentBeaconBlockRoot` |
| EIP-2935 system calldata | raw P-HASH-byte parent L2 execution hash |
| System-call ETH value | zero, upstream constant |

```text
EIP-4788 runtime (97 bytes, derived from the 0x61 constructor length):
3373fffffffffffffffffffffffffffffffffffffffe14604d57602036146024575f5ffd5b5f35801560495762001fff810690815414603c575f5ffd5b62001fff01545f5260205ff35b5f5ffd5b62001fff42064281555f359062001fff015500

EIP-2935 runtime (83 bytes, derived from the 0x53 constructor length):
3373fffffffffffffffffffffffffffffffffffffffe14604657602036036042575f35600143038111604257611fff81430311604257611fff9006545f5260205ff35b5f5ffd5b5f35611fff60014303065500
```

**[proven: reproduced digests]** Ethereum Keccak of those exact runtime bytes gives, respectively, `0xf57acd40259872606d76197ef052f3d35588dadf919ee1f0e3cb9b62d3f4b02c` and `0x6e49e66782037c0555897870e29fa5e552daf4719552131a0abce779daec0a5d`. The namespace formula in §4 evaluates to `0xdf69c48d3f34ad2eb24ae03aaa1d62941dc9b65358e1a70dc025c34643281000`. These are derived identifiers, not unmeasured economic inputs.

**[assumed: upstream semantics]** EIP-4788 writes timestamp at `t % P-RING` and the header word at that residue plus P-RING. Its getter rejects timestamp zero, wrong input length and a nonmatching stored timestamp; a successfully returned zero root is permitted. Its genesis operation is absent. EIP-2935 runs on every block where active except genesis, stores the parent hash at `(number - 1) % P-RING`, and exposes numbers in `[number - P-RING, number - 1]` where nonnegative. It does not extend the EVM `BLOCKHASH` opcode's 256-block window, backfill historical state or warm the address/storage for the first ordinary user call [E2935].

## 7. Argument and adversary coverage

**[proven: checkpoint integrity, conditional]** Assume A-CRYPTO, A-ORIGIN, A-EXEC, A-HISTORY and A-UPGRADE. A fresh accepted L2 checkpoint is either the successful zero-phase legacy path at the authenticated migration boundary or a C1-R08 reveal. For a reveal, its whole-header hash equals a previously authenticated origin word, directly or through a C1-R05 pin. C1-R08 extracts number/root from those same bytes, so substituting another root or number requires a hash failure or violating an assumption. C1-R06 preserves the first record and rejects partial/conflicting replacements. Induction over successful mutations gives authenticated map contents. This does not establish that a tentative origin is finalized; the entire L2 state can reorganize, and the governing origin policy must account for that.

**[proven: first-Etna writer closure, conditional]** Under A-EXEC and A-HISTORY, C1-R02 writes the nonzero selected origin before transaction execution, including in an otherwise empty block. C1-R07 therefore rejects every old writer in that block regardless of whether a caller has pinned or revealed. C1-R01 extends that condition to every valid successor. Missing code/read does not open the guard. A partial upgrade violates A-HISTORY; this proof is not a substitute for C4's deployment audit.

**[proven: bounded uniqueness, conditional]** Let `M` be the number of distinct authenticated origin hashes ever selected in the canonical Etna history under A-ORIGIN, A-EXEC and A-HISTORY. Fresh C1 writes add at most `M` pin values and `2M` checkpoint values, thus at most `3M` 32-byte values, or `96M` raw value bytes. Conflicts and duplicates cannot increase that count. This excludes inherited state, trie keys/nodes, archive copies, ordinary signals and received-signal caches. It is a per-origin bound, not a lifetime bound or a bound per batch. It does not assume candidate B's abandoned one-origin-per-segment rule.

**[proven: ring bound, conditional]** For increasing timestamp values with difference strictly less than P-RING, their residues cannot collide. A jump by exactly P-RING can overwrite the original entry in the very next block. Thus neither an P-RING-block retention promise nor a wall-clock inclusion guarantee follows from this oracle. Pins remove that ring-expiry dependency for a selected hash, subject to canonical-history rollback and actual header availability.

| Attack trace [assumed: adversarial schedule] | Result under the cited rules, or explicit limit |
|---|---|
| Producer chooses private execution header; feeds hash to utility; later reveals false custody root. Cost: one payload/proof attempt. Gain: forged remote state. | C1-R01 needs C2's authenticated origin, not just a nonzero utility word. **Open:** C2 predicate and guest/data binding. |
| Legacy publicly known signer submits old Anchor before any user reveal in first Etna block. Cost: one transaction. Gain: checkpoint poisoning. | C1-R02/R07/R09 close before that transaction. **Open:** actual migration selector/code manifest in C4. |
| Upgrader leaves an old router target reachable. Cost: partial upgrade. Gain: old writer bypass. | Violates C1-R07/R09 and A-HISTORY; activation must not be certified by C4. C1 does not repair a bad installed proxy. |
| Caller makes a duplicate after the old oracle entry expired or supplies a fresh hash at an occupied height. | C1-R06/R08 give idempotent success for the former and conflict failure for the latter, without an unbounded scan. |
| Producer delays a historical-timestamp forced reveal until a ring collision. Cost: censorship until collision. Gain: failed transaction, withheld bridge progress. | §8's current-origin pin flow avoids choosing an expiring timestamp. **Open:** A-INCLUSION/A-FUNDING and wrapper fit. |
| Provider promises availability, pins a header hash, then deletes the header/proof bytes. Cost: no continued service. Gain: griefing callers. | Pin proves membership, not availability. A-ARCHIVE remains necessary; no C1 objective slashing evidence exists for private non-service. |
| Ordinary caller uses delegation or copied oracle code to obtain system write authority. | Standard EVM caller/storage identity and exact canonical runtime under A-CRYPTO: copying code does not write the canonical address's storage; delegation does not confer the system sender's authorization. |
| Caller submits oversized/nonminimal RLP or hopes a malformed oracle return decodes as zero. | C1-R04/R08 bound the read/parser and fail closed. Exact gas sufficiency remains unmeasured. |
| Producer reorgs a block containing a pin/reveal after a user observes its event. | Ordinary rollback applies. C1 supplies no finality or indemnity; S2's D1 evidence and exceptions must be explicit. |
| Integrated producer repeatedly pins and reveals every distinct origin, recovering transaction fees through coinbase. | Uniqueness bound above; no lifetime cap or irrecoverable charge. **Open:** S3/C6 resource economics, including direct unpinned reveals. |
| L1 publication treats a provisional/degraded proof root as immediately spendable, then changes that root after a conflicting proof. | C1's L1 mode does not decide this. **Open:** C2 custody/finality rule must prevent irreversible Bridge effects from a retractable root. |

## 8. Conditional censorship-recovery and encoding examples

**[proven: constructive eventual processing-origin checkpoint availability, conditional]** Assume A-ORIGIN, A-EXEC, A-HISTORY, A-INCLUSION, A-FUNDING and A-ARCHIVE. A caller first forces the selector-only pin call. Whatever the queue delay, successful execution selects the processing block's origin. After obtaining that exact header, a second forced reveal uses the pin sentinel. Its authentication no longer depends on ring retention. Under C1-R06/R08 this either writes that origin's checkpoint or returns the identical existing tuple. This proves availability of the processing origin's checkpoint, not necessarily one containing a later signal. Recovering a particular persistent signal additionally requires A-ORIGIN-PROGRESS. Otherwise a producer can repeatedly select an authentic pre-signal origin and execute every forced call successfully while withholding useful bridge progress. C2/C3 must close that schedule. No wall-clock upper bound is claimed; C3 must derive any bound from its queue policy. A skipped/voided entry or a reverted transaction does not satisfy successful execution. Neither this argument nor the small reveal envelope proves that an arbitrary Bridge message/proof fits forced inclusion.

**[assumed: archive baseline]** Today's SignalService ordinary send path writes a signal value at `keccak256(abi.encodePacked("SIGNAL", uint64(chainId), app, signal))` [SS-SIGNAL]. A later checkpoint can witness an earlier signal if the relevant state and compatible storage proof remain available; C4 must preserve this property across upgrades. It is not permission to fabricate a proof from the pin alone.

**[proven: derived ABI size]** At the proposed maximum header length, the reveal calldata is `4 + 2*32 + 32 + ceil(1536/32)*32 = 1636` bytes: selector, two ABI head words, dynamic length, padded bytes. The pin calldata is only its four-byte function selector. Function selectors are the first four bytes of Ethereum Keccak of `pinCurrentOrigin()` and `revealCheckpoint(uint64,bytes)` respectively; they are not SHA3 digests.

**[proven: constructive raw transaction bound]** Consider a type-2 transaction with that calldata, a non-creation destination, zero value, empty access list, a nonce bounded by uint64, arbitrary uint256 chain ID and fees, and gas limit at P-FI-EXAMPLE-GAS. Its maximum RLP field sizes are: three uint256 fields `3*33 = 99`, nonce `9`, gas `4`, destination `21`, zero value `1`, data `1639`, empty list `1`, parity `1`, signatures `2*33 = 66`. Payload total `1841`; outer list prefix `3` and transaction type `1` give **1845 bytes**. This derivation is conditional on those dimensions, not a statement that every account/transaction fits. C3 must add its actual request/manifest wrapper and separately admit measured EVM and proof costs. Candidate A's quoted 4096-byte manifest is not an adopted C1 parameter or proof of fit.

**[open: integration measurement]** P-READ-GAS, header parse cost, initial/repeated pin and fresh/duplicate reveal gas, proof cost, complete C3 envelope length, repricing headroom and adequate eventual fee funding have no execution measurements in this section. D2 permits unmeasured values; it does not permit claiming forced execution fits an unspecified wrapper or gas budget. C3/C6 own closure of those integration facts.

### Deterministic examples and test-vector obligations

**[proven: byte/arithmetic vectors]** These examples are exact encodings or rule projections. They are not test executions or deployed-state fixtures. Integer values in the examples are chosen fixtures, not economic parameters.

| Vector | Input | Expected result / derivation |
|---|---|---|
| V01 extraData | fee 100, term 1, view 2, kind 3 | `0x64000000010203`; parsing recovers the physical fields. Semantic acceptance of kind 3 is left to C3/S2. |
| V02 raw getter | timestamp 1 | `0x0000000000000000000000000000000000000000000000000000000000000001`; not ABI `get(uint256)` calldata. |
| V03 collision | roots `H1` at timestamp 1, `H2` at timestamp 8192 | residue 1 both times; after the second write getter(1) reverts, getter(8192) returns H2; an earlier pin(H1) survives. |
| V04 malformed integer | number field `0x00` versus `0x80` | first is nonminimal integer zero and rejected; second is minimal zero. Whole-header authentication is still independently required. |
| V05 width boundary | number field `0x86ffffffffffff` versus `0x8701000000000000` | first is maximum uint48; second is `2^48`, rejected before cast. These are RLP field bytes, not complete headers. |
| V06 duplicate | existing `(n,H,R)`, same complete header, expired positive timestamp | current nonzero guard and parser pass, exact tuple returns with no event/write, no historical read, by C1-R08 step 4. |
| V07 conflict | existing `(n,H1,R1)`, parsed `(n,H2,R2)`, `H1 != H2` | `EtnaCheckpointConflict(n)` before checking historical timestamp/pin. |
| V08 corruption | existing `(n,H,0)` or `(n,0,R)` | `EtnaCheckpointCorrupt(n)` for getter or write; never auto-repair. |
| V09 phase | current read unavailable / zero / nonzero | unavailable is error; zero admits only authenticated legacy writers; nonzero admits new operations and rejects old writers. |
| V10 identity | same execution header/transactions, different `vcHash` in PH envelope | cannot infer same certificate identity from blockHash. **Open:** C2/S2 supply exact signed/DA/proof vectors under P-B-C1-01. |

**[proven: ABI selector vectors]** The signatures in §8 evaluate to `pinCurrentOrigin() = 0xb5ad3e31` and `revealCheckpoint(uint64,bytes) = 0x6c7d3fdf`. The new view is `isOriginPinned(bytes32) = 0xafa0caba`.

**[proven: complete synthetic parser vector V11]** The following 78-byte RLP input has exactly twelve scalar fields. Parent hash is 32 copies of `0x11`, state root is 32 copies of `0xaa`, number and timestamp are 1, and all other fields are empty strings. It parses under C1-R08 and hashes to `0x97349d16acda015ee25d7468566d0759c8d128707dec6b16fd17254b76233723`. It is deliberately only a parser fixture, not a valid/authenticated Ethereum header: live acceptance additionally requires A-ORIGIN and the oracle/pin equality. A caller cannot make a trusted origin by constructing this input.

```text
0xf84ca011111111111111111111111111111111111111111111111111111111111111118080a0aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa8080808001808001
```

**[proven: reproduction record, limited scope]** The runtime extraction, namespace/selector/parser digests, ABI/envelope arithmetic and raw-value storage counts were recomputed in a disposable scratch script with PyCryptodome 3.23.0 `Crypto.Hash.keccak`, checked against the standard empty-input and `abc` Keccak-256 vectors. Runtime bytes matched the pinned EIP deployment inputs after constructor removal. This verifies byte arithmetic and hashes, not EVM execution, parser implementation, proof soundness or gas. The throwaway script/dependency are not part of the specification or PR.

**[open: implementation conformance suite]** The eventual implementation must provide full authenticated L1-header fixtures and independent builder/importer/guest roots for: empty first block, both system operations, legacy-zero transition, fresh/duplicate/pinned reveal, same-height conflict, malformed parser branches, ring collision, proxy-route bypass attempts and reorg rollback. C2/C4 supply the selected fork headers and deployed-code/layout manifests; C6 records their current absence. No production tests or contracts are delivered by this research PR.

## 9. Limits and rejected alternatives

| Choice | Reason and residual [proven/assumed/open as marked] |
|---|---|
| Standard utilities and optional reveal, not mandatory anchor transaction | **Proven, conditional:** C1-R02/R07 remove the transaction-position dependency while closing old writers before ordinary execution. **Open:** implementation parity and migration. Credit [ISSUE], [B-CHECKPOINTS], [B-CODEC]. |
| Current-root guard, not voluntary `beginEtna` | **Proven:** a voluntary transaction can be withheld or ordered after the legacy writer; the system operation precedes every ordinary transaction. |
| Permanent membership, not mandatory historical-timestamp forced reveal | **Proven:** V03 defeats a fixed old timestamp after queue delay. **Open:** permanent-state costs. |
| No global latest-checkpoint pointer | **Proven:** independent authenticated heights can be revealed out of order without creating overwrites; a latest-only gate could block delayed valid bridging. |
| No administrator checkpoint repair or pin pruning | **Assumed:** avoids an operational authority and expiry-dependent forced flow. **Open:** future storage policy would need a new decision with proofs of retention and migration. |
| No new Bridge/SignalService/Vault address | **Assumed:** existing proxy upgrades preserve R2's address constraint; complete live-layout and selector audit is C4's responsibility. |
| No inherited B staging/rent/segment timing | **Assumed:** the merged committee design owns these choices. This section counts distinct origins and consumes C2's policy. |
| No "pin means available/final/confirmed" label | **Proven:** a hash preimage can be withheld, and its containing state can reorganize. S2/S3 must supply D1 and availability claims separately. |
| No storage tariff in this proposal | **Assumed:** pin/reveal remain nonpayable normal transactions. **Open:** a fee only on pins would miss direct timestamp reveals; a future policy must cover all fresh persistent writes, duplicate behavior, fee sink and forced funding. Ordinary producer-recoverable gas is not a permanent-storage price proof. |

**[proven: illustrative growth only]** With 100 distinct origins, the bound in §7 is 9600 raw value bytes. If, as a hypothetical workload rather than a selected origin policy, a year has `365*24*60 = 525600` distinct origins, pins alone account for `16,819,200` raw value bytes and pins plus checkpoint values for at most `50,457,600`. Actual disk/archive use is larger and unmeasured. No origin-frequency or monopoly-resistance guarantee follows.

## 10. Integration dashboard and requirement impact

| Owner / obligation | Status and closure condition |
|---|---|
| C2: O_b authentication, header-fork profile, canonical DA, journal and proof binding | **Open.** Specify membership/ancestry, age and stall/reorg policies; bind every origin and all removed Anchor metadata. Supply V10/full-header vectors. C1-R01/R03 are consumers of this interface. |
| S2: confirmation identity and execution-context labels | **Open.** Prove slashable D1 confirmation with explicit reorg/withholding exceptions and identity binding under P-B-C1-01. A header word or pin does not discharge D1. |
| C2: L1 custody checkpoint publication | **Open.** Give exact Inbox interface/authenticated proof status. In particular resolve whether a degraded/provisional result can have irreversible Bridge effects. C1-R07 preserves authority but supplies no such finality policy. |
| C3: eventual successful pin/reveal execution | **Open.** Derive full wrapper sizes, nonce/fee rules, EVM/proof budgets, successful-execution semantics and any queue-delay bound. Do not count void/revert as checkpoint progress. |
| C2/C3: origin progress for signal recovery | **Open.** Discharge A-ORIGIN-PROGRESS; authentic but perpetually pre-signal processing origins defeat useful bridge progress despite successful pin/reveal calls. |
| C4: authenticated boundary and no old writer route | **Open.** Inventory actual proxies, code hashes, layouts, syncer/remote immutables, caches and fork-router selectors; define legacy-zero transition, code installation and forward rollback. Full pause/withdraw/resolver-power removal belongs there. |
| S3/C6: retention economics | **Open.** Accept or price unbounded distinct-origin growth, recognizing fee recapture and direct-reveal writes. A new tariff/pruning proposal changes the interface and requires a decision. |
| C6: unmeasured register | **Open.** Index P-READ-GAS, parser bounds/profile, fresh/duplicate operation gas, forced wrapper/proof cost, runtime parity, state/disk growth and selected-fork gas repricing. Preserve source/derived/unmeasured distinctions. |
| C7/C8: composition and consolidated interfaces | **Open.** C7 invokes C1's component without treating `C1_PASS` as complete validity; C8 indexes the module's declarations and C4 layouts without diverging duplicate definitions. |
| A/J: review | **Open.** A approve/request changes and J's independent review not yet received; neither internal B source checks nor this PR count as those verdicts. |

| Requirement | C1 contribution, not a whole-design pass |
|---|---|
| R1 | **Proven conditionally:** new calls accept any address and block execution needs no checkpoint operator. **Open:** C4 removes every inherited operational authority; other roles specified elsewhere. |
| R2 | **Proven conditionally:** API/layout proposal reuses maps/proxies and ordinary bridge paths. **Open:** live storage/immutable/selector audit and C2 L1 publication rules. |
| R3 | **Assumed:** caller lifecycle/failure behavior in §5; bonded roles and all-offline recovery owned by S4. |
| R4 | **Assumed target:** timestamps allow the required one-second issuance profile. **Open:** S2 propagation/confirmation and execution/proving capacity, not proven by removing Anchor. |
| R5 | **Proven for C1:** no CL lookahead, slot or epoch input; timestamps and block-number windows retain their units if L1 cadence changes. C2 owns its independent timing policy. |
| R6 | **Open outside C1:** malformed calls fail objectively, but C1 creates no slash for private non-service and no anti-monopoly claim. S3/S4 must specify these. |
| R7 | **Open outside C1:** C2 binds these execution outputs in its atomic data-plus-proof action; C1 does not specify landing races, prover replacement or finality. |
| D1 / D2 | **Open / assumed scope:** D1 depends on S2/S3; D2 permits the marked unmeasured values while requiring eventual exact interface integration. This C1 draft alone is not spec-ready convergence. |

## 11. Evidence and credit

**[assumed: source facts]** Sources were inspected at immutable commits on 2026-10-01. Repository snapshot evidence is not a live deployment audit. The Ethereum EIP snapshot was fetched at run time; fork adoption beyond the explicitly selected runtime/profile belongs to C5.

- [BASE]: convergence base `1e74435947d3d1ee1c47f9bf19cbc4a2193dace1`.
- [SS-STRUCT]: [SignalService.sol, structs, immutables and mappings, lines 24 to 93](https://github.com/taikoxyz/taiko-mono/blob/1e74435947d3d1ee1c47f9bf19cbc4a2193dace1/packages/protocol/contracts/shared/signal/SignalService.sol#L24).
- [SS-WRITE]: [baseline writes/getter, lines 174 to 218](https://github.com/taikoxyz/taiko-mono/blob/1e74435947d3d1ee1c47f9bf19cbc4a2193dace1/packages/protocol/contracts/shared/signal/SignalService.sol#L174).
- [SS-LAYOUT]: [SignalService layout, lines 21 to 24](https://github.com/taikoxyz/taiko-mono/blob/1e74435947d3d1ee1c47f9bf19cbc4a2193dace1/packages/protocol/contracts/shared/signal/SignalService_Layout.sol#L21).
- [SS-SIGNAL]: [signal-slot derivation and send path, lines 160 to 170 and 220 to 235](https://github.com/taikoxyz/taiko-mono/blob/1e74435947d3d1ee1c47f9bf19cbc4a2193dace1/packages/protocol/contracts/shared/signal/SignalService.sol#L160).
- [SS-PAUSE]: [SignalService owner/pauser authorization, line 201](https://github.com/taikoxyz/taiko-mono/blob/1e74435947d3d1ee1c47f9bf19cbc4a2193dace1/packages/protocol/contracts/shared/signal/SignalService.sol#L201); [EssentialContract pause methods/hooks, lines 150 to 209](https://github.com/taikoxyz/taiko-mono/blob/1e74435947d3d1ee1c47f9bf19cbc4a2193dace1/packages/protocol/contracts/shared/common/EssentialContract.sol#L150).
- [ANCHOR-LAYOUT]: [Anchor layout, lines 21 to 25](https://github.com/taikoxyz/taiko-mono/blob/1e74435947d3d1ee1c47f9bf19cbc4a2193dace1/packages/protocol/contracts/layer2/core/Anchor_Layout.sol#L21); [Anchor legacy writer and withdrawal, lines 124 to 185](https://github.com/taikoxyz/taiko-mono/blob/1e74435947d3d1ee1c47f9bf19cbc4a2193dace1/packages/protocol/contracts/layer2/core/Anchor.sol#L124).
- [PROOF-ABI]: [SignalService hop proof validation, lines 265 to 296](https://github.com/taikoxyz/taiko-mono/blob/1e74435947d3d1ee1c47f9bf19cbc4a2193dace1/packages/protocol/contracts/shared/signal/SignalService.sol#L265); [cache return count, lines 124 to 126](https://github.com/taikoxyz/taiko-mono/blob/1e74435947d3d1ee1c47f9bf19cbc4a2193dace1/packages/protocol/contracts/shared/signal/SignalService.sol#L124); [Bridge reimbursement, lines 339 to 392](https://github.com/taikoxyz/taiko-mono/blob/1e74435947d3d1ee1c47f9bf19cbc4a2193dace1/packages/protocol/contracts/shared/bridge/Bridge.sol#L339).
- [ROUTES]: [ForkRouter selection and delegation, lines 18 to 66](https://github.com/taikoxyz/taiko-mono/blob/1e74435947d3d1ee1c47f9bf19cbc4a2193dace1/packages/protocol/contracts/shared/fork-router/ForkRouter.sol#L18).
- [E4788]: [EIP-4788 at Ethereum/EIPs 41ba25ccbf3f5dc441d7d049d0bc6ec9ad8e8215](https://github.com/ethereum/EIPs/blob/41ba25ccbf3f5dc441d7d049d0bc6ec9ad8e8215/EIPS/eip-4788.md).
- [E2935]: [EIP-2935 at the same live-fetched revision](https://github.com/ethereum/EIPs/blob/41ba25ccbf3f5dc441d7d049d0bc6ec9ad8e8215/EIPS/eip-2935.md).
- [ISSUE]: [David's proposal to remove the anchor transaction, #22147](https://github.com/taikoxyz/taiko-mono/issues/22147#issue-5516275880).
- [B-CHECKPOINTS]: [B checkpoint design at bfc0964](https://github.com/taikoxyz/taiko-mono/blob/bfc09641794cbc172a3255a416a93d0a10a23a1f/packages/protocol/docs/Etna/design/checkpoints.html), especially guard/parser/forced-call treatment; [B migration](https://github.com/taikoxyz/taiko-mono/blob/bfc09641794cbc172a3255a416a93d0a10a23a1f/packages/protocol/docs/Etna/design/migration.html).
- [B-CODEC]: [B execution profile and vectors at bfc0964](https://github.com/taikoxyz/taiko-mono/blob/bfc09641794cbc172a3255a416a93d0a10a23a1f/packages/protocol/docs/Etna/design/codec.html#L240). Its segment metadata and rent were not adopted here.
- [A-METADATA]: [A's seven-byte header and removed Anchor fields at 8ef29cd](https://github.com/taikoxyz/taiko-mono/blob/8ef29cd29497763cceb40a8c3b079f632428f70a/packages/protocol/docs/Etna/design/bridge-migration.html#L42); [A's PH and old anchor-calldata binding claim](https://github.com/taikoxyz/taiko-mono/blob/8ef29cd29497763cceb40a8c3b079f632428f70a/packages/protocol/docs/Etna/design/preconf.html#L23); [A's canonical publication fields](https://github.com/taikoxyz/taiko-mono/blob/8ef29cd29497763cceb40a8c3b079f632428f70a/packages/protocol/docs/Etna/design/landing.html#L26). These files still contain `anchorV5`; the later adoption described in the charter is prospective, not evidence that the exact metadata interface was already reconciled.
- [Ownership confirmation](https://github.com/taikoxyz/taiko-mono/pull/22191#issuecomment-5927671024) and [working agreement](https://github.com/taikoxyz/taiko-mono/pull/22188#issuecomment-5927629688). Pending cross-module choices are recorded in [DECISIONS.md](../DECISIONS.md), not silently attributed to A or J.
