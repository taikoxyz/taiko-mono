# C1. Anchor-free L2 execution and checkpoint publication

**[assumed: acceptance record; open: consumer integration]** [D59](../DECISIONS.md) merges C3 as `c0b52677325c6565b5bf34902ceb801ebf9e1c53`; its content is identical to the retained `eebc598` source pins. [D63](../DECISIONS.md) merges B's C1/C4/C6 consumers and learning-site update as `d997a9bc7b7489a2ac2e8c15f01b52c5280a8907`. D59's full D50 user-completion list stays open: hatch spacing; the base poison halt and `fiClear` cap; deposit forfeit; honest post-void certification anchored before the void (B-D41-03); the lengthened poison halt; legacy expiry and the LEGACY_BLOB service promise. Technical review and C3's merge sign none of these for the user. [D60](../DECISIONS.md) separately adds fresh out-of-order execution outside T11 to the user-completion list; D55(3) signs only replay. [D61](../DECISIONS.md) merges A's C2/C5/C6-A/C8/S1/S4 hatch synchronization as `d3f9bfe6`. [D62](../DECISIONS.md) merges C7 as `0f0a2f0eafa4057648fe54ba1be4b09035bb3e93`; genesis/restart modes, fork choice and encoding obligations remain open. These merges do not complete D44.

**Owner:** B. **Reviewer:** A. **Independent reviewer:** J (DeepSeek).

**Status [assumed: acceptance record]:** merged under [D28 and D63](../DECISIONS.md), incomplete under D44. The current disposition of the W10 census is in the [W15 disposition](#w15-open-item-disposition); acceptance of the section does not close its remaining specification obligations.

**[assumed: acceptance record; open: integration]** A merged C1 under D28. The W1 review dispositions below retain their authoring-time history; they are not a new request to review the accepted head. This is a specification, not an implementation or an assertion about deployed contracts. D44 now requires implementation-ready specification closure under [WORK.md](../WORK.md#readiness-d44), not merely a list of unmeasured inputs. The obligations in §10 remain open until their owners discharge them; [C6's closure index](C6-readiness-closure-index.md) links the required artifacts. This D41 consumer revision is accepted under D63 and consumes the corrected hatch merged under D59 at [C3-HATCH], with D51's product choices and D55's signed limitations at [HATCH-DECISIONS]. D56's freeze and D57's full J verdict apply to earlier `76c6150`; B approved the corrections and D59 merged this source. C1-R05 adopts its request-block system pin and §8 states the resulting conditional recovery argument. D59 and D63 are source and consumer acceptance, not performance evidence or closure of the remaining integration obligations. No whole-protocol readiness, D1 confirmation or successful convergence round is claimed.

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
| Caller | Any account or contract submitting an ordinary pin/reveal. This is an unbonded, voluntary action, not an exclusive or assigned protocol role. The request-block system pin needs no such caller. |

**[assumed: named premises]** The following names are used in the arguments, not as substitutes for other sections' specifications.

| Premise | Exact dependency |
|---|---|
| A-CRYPTO | Ethereum Keccak collision/second-preimage resistance and normal EVM authentication hold; nobody can authorize an ordinary transaction as the standard system address. |
| A-ORIGIN | C2 and the local derivation rules authenticate every selected origin against the intended L1 history and bind it to the same L2 block. A nonzero word alone is insufficient. |
| A-EXEC | Builder/sealer, importer and proof guest implement the same C1 profile and EVM semantics, including pre-Etna system operations, the C1-R05 request-block system pin and rollback. In particular the sealer executes the same EIP-4788 call as importers (taiko-geth#601); importer-only support does not establish parity. |
| A-HISTORY | C4 authenticates the inherited checkpoint mappings and received-signal caches, including absence of partial inherited records, installs the specified code/guards, closes alternate writer routes, and preserves their storage. |
| A-ORIGIN-CHAIN | Within the canonical landed L2 history all selected origins lie on one L1 parent-hash chain; equal numbers imply equal hashes. C2-R04/R19 export this conditional result through whole-range authentication, not tip-only checking. Unlanded conflicting histories do not satisfy it. |
| A-LEGACY-ZERO | Every EIP-4788 record written before first Etna activation is zero, as required by the pre-Etna profile. C4 audits this from the real activation history, not from an invented backfill. |
| A-INCLUSION | The two requests in §8 are provable and land in an eventually stable canonical history under the revised [C3-HATCH] A-HATCH-LATENCY and §9 premises. In that source's 12-second L1 inclusion example, acquisition, proving and submission finish within 1,776 s of S_c, and inclusion finishes within 1,788 s of S_c, strictly before the first voidable instant. These are derived margins, not measured performance. Each save-time bound assumes a request saved in the active epoch and no intervening CONFLICT restart; inherited entries use §9's close_e instead. The first request produces the C1-R05 system pin; the second produces a successful C1-R08 reveal or that reveal has already succeeded. Actual wrapper, EVM and proof costs must fit. Consumption, voiding, skipped content and reverts alone are insufficient; eventual stability is not a finality claim about an observed pin. |
| A-ORIGIN-PROGRESS | For a request saved on the intended L1 chain after the persistent signal's containing block, a landed request block pins an origin containing that signal. [C3-HATCH] C3-R05's origin-progress claim, C3-R07 check 5 and C3-R08's save-before-anchor assertion supply the time ordering under T3, without T11; C2 supplies origin authentication and A-ORIGIN-CHAIN, and persistence supplies the retained signal state. §8 gives the conditional composition. A request that is only voided supplies no pin. |
| A-FUNDING | A requester can pay C3's L1 save charges and supply a valid reveal transaction with enough native ETH, gas and fee allowance for its actual execution. An eventual fee envelope and a refresh procedure that preserve the recovery argument remain open in §8; C3 consumption does not establish them. |
| A-ARCHIVE | Someone can obtain the exact selected L1 header and a suitable remote SignalService account/storage proof. A hash commitment does not provide these bytes. |
| A-UPGRADE | The current reviewed implementations remain in effect for the history being evaluated. DAO upgrade authority is a separate governance assumption, not a daily liveness dependency. |

## 2. Execution profile

### C1-R01. Per-block origin and local validation

**[assumed: proposed rule]** Each Etna block has one C2-authenticated origin `O_b` and sets `header.parentBeaconBlockRoot = O_b.blockHash`, which is nonzero. C2's canonical block-data representation and proof statement bind that equality, the complete L2 header and its execution result. The C1 component of C7's local validity predicate checks the same equality and origin authentication before executing the block. Its component result is `UNKNOWN_CONTEXT` when required bytes/context are missing, `INVALID_C1` for a known contradiction and `C1_PASS` when these checks pass. `C1_PASS` is not whole-block validity; C7 composes the remaining predicates, and S2 defines confirmation labels and their consequences. C1 introduces no origin-age, origin-per-batch, finality or CL-lookahead rule. **Adversary schedule:** a producer supplies a fabricated execution hash, a genuine orphaned origin, a beacon root, or different origins to the importer and prover. A-ORIGIN is indispensable to rejecting the latter history/context attacks; the oracle alone cannot do so.

### C1-R02. System operations and block structure

**[assumed: proposed rule]** Whenever both utilities are active, execute the standard EIP-4788 operation, then the standard EIP-2935 operation, before ordinary transactions. Their deployment/activation order is owned solely by C1-R09 and executed by C4; the first Etna block is not their initial activation. Use the addresses, caller, calldata and allowances in §6 and the upstream semantics in [E4788] and [E2935]. These two standard operations create no synthetic transaction, receipt, log, account nonce increment, Anchor gas reserve or contribution to ordinary block `gasUsed`. Their state writes enter the resulting state root. C1-R05 inserts the request-block system pin into this order. No transaction position is reserved for an anchor; a zero-transaction block is permitted. Voluntary calls to the public pin/reveal methods are ordinary transactions with ordinary fees and receipts. Preserve upstream no-code silence and genesis exceptions; the migration preconditions in C1-R09 ensure Etna does not depend on that no-code behavior. The first Etna block is a non-genesis child of C4's authenticated boundary. **Adversary schedule:** an empty first block, a producer inserting a fake anchor receipt, or builder/guest disagreement about operation order and gas accounting.

### C1-R03. Timestamp and metadata encoding

**[assumed: profile accepted under D28; open: integrated reference vectors]** Etna header timestamps are positive, strictly increasing from their parent, and fit P-NUMBER in §6. The new uint64 reveal parameter/event matches the PH timestamp carrier and safely carries `block.timestamp` under P-NUMBER; it is not a legacy-ABI compatibility requirement or a wider consensus timestamp; fresh positive inputs exceed the current uint48 timestamp only by failing the future-timestamp check. Encode `extraData` as exactly `feeShare:u8 || termId:u32BE || view:u8 || kind:u8`, with no prefix, padding or trailing bytes. The fee-share byte has the value in §6. Legacy blocks retain `feeShare:u8 || proposalId:u48BE`; this Etna decoder applies from the first Etna block. C8 owns the consumer-side decoder switch. S2-R03/R18 own the signed identity and confirmation semantics, C3-R05/R07 at [C3-HATCH] own request-block kinds, and C4 owns the first-Etna kind; C7 checks their combined header table. Term exhaustion requires an explicit protocol upgrade, never silent wraparound. S2/C2 publish and bind the full preconfirmation metadata removed with anchor calldata, including any seat, view-change and carried-certificate identities used by their rules. The signing, data and proof identities must distinguish conflicting metadata envelopes for the same execution hash. This paragraph specifies that interface obligation; those sections own its encoding and predicates. **Adversary schedule:** a producer reuses one execution hash with two `vcHash` or carried-certificate envelopes, or a prover omits one envelope. Seven bytes of `extraData` do not themselves bind those omitted fields. S2-R03 specifies the PH identity and D16 makes `vcHash` a logical opening id independent of the quorum witness. Exact cross-section encoding/verification vectors remain **open** under S2-V14 and C8. D28 closes P-B-C1-01's layout and identity direction; it expressly leaves the full-envelope vectors to their owners, and does not merge S2.

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

**[assumed: proposed rule]** `pinCurrentOrigin()` is nonpayable and permissionless. Neither it nor C1-R08 reveal has an inherited `whenNotPaused` gate, owner/pauser authorization or pause-dependent branch. The upgraded SignalService `_authorizePause` reverts for every caller on both layers; C4 removes effective inherited operational pause checks without moving their persisted fields. In order: require `L2_ORIGIN` or `EtnaWrongMode`; apply C1-R04 to the current timestamp; require a nonzero result or `EtnaWrongPhase`; set that hash's pin bit if absent; return the hash in both cases. An ordinary call emits `OriginPinned(hash, uint64(block.timestamp))` only on the first write. There is no user-selected origin or timestamp, no automatic checkpoint write and no unpin operation. `isOriginPinned` is an unrestricted view of the bit; the zero hash returns false. An L1 deployment returns false for that view and rejects both new mutations.

**[assumed: request-block adoption of C3-R05(d) at C3-HATCH]** Every C3 request block, kind FI or FORCED, applies the same current-origin authentication and pin mutation as a system operation after EIP-4788 and EIP-2935 and before its ordinary transactions. This includes replay blocks and expiry-empty request blocks under C3-R05(a)/(e). It creates no transaction, account nonce increment or receipt, and writes the bit only if absent. Its state effect enters the block's state root independently of whether any manifest transaction is valid, skipped or reverted. A void consumption without a request block performs no L2 operation. Request selection, content, replay authorization and expiry remain C3's rules; this adoption adds no per-block request duty.

**[open: system-operation execution interface]** C3-R05(d) fixes the order and state effect but does not fix the system pin's call surface, gas allowance/accounting or treatment of `OriginPinned` without a receipt. P-SYSTEM-GAS describes only the two standard utilities. C1's implementation specification and C8's interface consolidation must select the remaining execution details and provide builder/importer/guest parity vectors before D44 closure; this text does not fabricate a log or reuse the standard-utility allowance by implication. The recovery proof below depends on the required pin state, not on observing an event from this operation.

**[assumed: adversary schedule]** An attacker asks to pin a private, old or nonexistent origin, repeats a pin to manufacture events, or pre-executes a queued ordinary pin transaction against a pre-signal origin. Only the processing block's authenticated current word can create membership; the request-block system pin remains mandatory even if that ordinary transaction is then skipped for its used nonce.

### C1-R06. Shared checkpoint record operation

**[assumed: proposed rule, incorporating C2-R21]** Resolve the epoch for a checkpoint height before every map read/write, including the internal getter for nonempty signal proofs. On L2 it remains epoch 1: a re-landed L2 history reveals the same authenticated L1 header tuples under A-ORIGIN-CHAIN, while ordinary L2 state rollback removes writes from the replaced history. On L1, begin at epoch 1 and scan the rollback floors from newest appended to oldest; the first entry whose `floorHeight < number` selects its epoch. If none matches, select epoch 1. Equality with a floor does not select that floor's epoch; the scan continues to older entries. Append order, not floor-height sort order, determines recency. C2-R13/R15 currently permit only nondecreasing floors; decreasing floors in V12 test lookup behavior for a future separately reviewed upgrade that changes that restriction, not an available recovery path. Thus above the newest floor both reads and writes address the newest epoch, with no fallback to an old epoch when its new record is empty.

At that selected `(epoch, number)`, reject a zero supplied hash/root with existing `SS_INVALID_CHECKPOINT()`. If both stored words are zero, write the two-word record and emit `CheckpointSaved`. If exactly one is zero, revert `EtnaCheckpointCorrupt(number)`. If both equal the supplied tuple, return without a write or event. Otherwise revert `EtnaCheckpointConflict(number)`. No global latest-number restriction is added to SignalService; C2 owns increasing L1 publication heights. The public/internal getter returns only two nonzero words; both zero gives `SS_CHECKPOINT_NOT_FOUND()`, and a partial record gives `EtnaCheckpointCorrupt(number)`.

**[assumed: behavioral change and consequence]** Conflict and duplicate semantics change the baseline L1 and L2 writers, which currently overwrite and emit on every call. The getter change also affects inherited heights: the baseline tests only the hash, whereas the new public/internal path rejects either partial record. C4's retained-surface table records both changes, with A-HISTORY naming the defensive no-partial-inherited-record premise. An L1 conflict reverts the entire atomic landing or the finalization pass that carries the write, rather than overwriting custody state; a duplicate emits no new checkpoint event. C2-R15's strictly increasing accepted publication heights and C2-R14/R21's restart/floor rules must exclude conflicting publication paths.

Within one selected epoch a conflict is a permanent hole for the conflicting tuple at that height, with no per-record repair. If a private/stale L1 origin entered an unlanded L2 branch, its checkpoint is immediately usable for L2 signal proofs and local Bridge effects even though L1 has not authenticated the containing range. Those effects are provisional and replaceable until that range lands; bridge withdrawals wait for the landed/custody status of C2-R19 and S2-R18. C2-R04 authenticates every origin in the range by a parent-hash chain to the L1-checked tip, so a range containing the bad origin cannot land. Recovery is replacement of an unlanded range under C2-R08/R20, a C2-R14 CONFLICT restart preserving the Etna profile, or the separately reviewed C4 execution-profile rollback under C1-R09; a C2-R21 epoch change accompanies either upgrade recovery only when its checkpoint-floor preconditions hold. None is in-place checkpoint repair.

**Adversary schedule:** duplicate/out-of-order reveal, same-height private/canonical origins, a partial inherited record, two proofs of distinct L2 states at one height, reused heights after rollback, or a reader falling back to a voided record after an empty new epoch. Whole-range origin authentication is answered by C2-R04/R19, conditional on its soundness/history premises, not established by a producer-set oracle word.

### C1-R07. Writer authority and legacy closure

**[assumed: proposed rule]** On L1, `saveCheckpoint` retains exact immutable Inbox authorization, then applies C1-R06; it does not use an L1 beacon root as authority for an L2 state root. On L2, the legacy `saveCheckpoint` path retains exact legacy syncer authorization, then requires a successful current zero read under C1-R04, then applies C1-R06. Each reachable legacy Anchor writer similarly retains its legacy sender authorization and requires the successful current zero read before any progress/checkpoint writes. Nonzero gives `EtnaWrongPhase`; read failures retain C1-R04's error. These checks apply through all inherited, delegated and fork-router routes, not just newly named methods. Other legacy validation still applies. C4-R10 applies D26's removal of the retained operational powers and selects the guarded implementations; no such route may bypass this writer guard. **Adversary schedule:** invoke the old golden-touch Anchor at ordinary transaction zero in the first Etna block, call SignalService through an old router target, or call L2 reveal logic on L1. A voluntary pin or reveal must not be necessary to close a writer.

### C1-R08. Reveal operation, parser and precedence

**[assumed: proposed rule]** `revealCheckpoint` is nonpayable and permissionless. Its ordered algorithm is:

1. Require `L2_ORIGIN`, else `EtnaWrongMode`; apply the current-read guard C1-R04 and require nonzero, else `EtnaWrongPhase`. This occurs even for a duplicate or a pinned historical reveal.
2. Check nonempty input and the raw-header byte cap before any input-dependent allocation; otherwise `EtnaHeaderSize`. Compute `h = keccak256(the entire supplied header bytes)` using Ethereum Keccak, not SHA3-256. The nonzero authenticated-origin requirement in step 5 excludes zero without a separate header-hash check.
3. Parse one canonical RLP list consuming the whole input, with the field-count bounds in §6. Every field is a scalar byte string. Reject nested lists, trailing bytes, truncated payloads, nonminimal short/long forms, leading zeros in length-of-length, overflow and out-of-bounds offsets with `EtnaMalformedHeader`. Field 0 (parent hash) and field 3 (state root) have the fixed hash width. Fields 8 (number) and 11 (timestamp) are minimal unsigned integers bounded by P-NUMBER; zero is the empty RLP string, not byte `0x00`. No truncating cast is permitted. Other fields are parsed canonically without assuming their future semantics. A zero state root gives `SS_INVALID_CHECKPOINT`. Construct `(number, h, stateRoot)`.
4. Inspect the existing record using C1-R06's partial/conflict/duplicate cases. This step is read-only, including when the record is empty; do not invoke the fresh-writing branch yet. An exact duplicate returns immediately without consulting a historical ring entry or pin. This is deliberately idempotent after ring eviction. A conflicting or partial record errors before the remaining timestamp checks.
5. For a fresh record: if `l2Timestamp` is the pin sentinel, require `pinned[h]`, else `EtnaUnknownOrigin`. Otherwise require `l2Timestamp <= block.timestamp`, else `EtnaFutureTimestamp`; read that timestamp through C1-R04 (reuse the current read when equal), and require its nonzero word equals `h`, else `EtnaUnknownOrigin`. An expired or never-recorded positive timestamp gives `EtnaOracleUnavailable`; for a fresh reveal after eviction only a prior pin of that hash supplies recovery. Never query the oracle with the pin sentinel.
6. Apply the fresh-write branch of C1-R06 and return the tuple. Revealing through a timestamp does not implicitly pin the hash.

Normal ABI decoding errors, nonpayable-value rejection and transaction out-of-gas are EVM/compiler errors outside that ordered body. No check compares the L1 number to the current L2 number. No requirement makes the current root equal an older pinned root. **Adversary schedule:** a fabricated header prefix, an authentic hash paired with an unrelated state root, noncanonical RLP, overwide integers, expiration before inclusion, or a different header at an already used height.

## 4. Fork, state and storage

### C1-R09. Activation and rollback boundary

**[assumed: proposed rule]** C4 owns executing this ordered prerequisite sequence: establish builder/sealer/importer/guest parity for the standard operations; activate EIP-2935; activate EIP-4788 recording zero roots on every pre-Etna block; only then install guarded writer implementations and close alternate routes; then activate the first Etna block from the authenticated terminal legacy state. Existing correctly active utilities may satisfy a step after audit. Once both are active, C1-R02 is the sole per-block operation-order rule. Every pre-Etna EIP-4788 system call supplies a zero root; all records written in that interval are therefore zero (A-LEGACY-ZERO). Both SignalService instances must have inherited `__paused != _TRUE` (equivalently `paused() == false`) when the rejecting pause hook is installed; C1-R05 owns removal of effective proof-path pause gates. No historical state root is changed retroactively, and no voluntary phase-changing transaction participates in first Etna activation.

Ordinary reorg processing rolls back code, state and block context together. Under the Etna profile a zero-origin successor is invalid. A separately reviewed C4 forward upgrade can change that profile at a specified client rollback time and reset the old Anchor's single `ancestorsHash` field to zero, define the void set and preserve the remaining checkpoint/pin history. Once that upgraded profile again records successful current zero roots, legacy writer reopening is exactly the consequence of C1-R07, not an oracle-read failure workaround. Any legacy writer installed at or after activation retains C1-R04's guard; an `ancestorsHash` reset may be installed only together with that guard. The frozen `anchorBlockNumber` still gates the legacy update condition; C4 must specify its preserved/restored value with the authenticated rollback state, rather than assume resetting `ancestorsHash` alone reopens every checkpoint update. Until the first valid zero-root rollback header, the public golden-touch signer cannot use a reset `ancestorsHash` to forge a checkpoint. This profile rollback is distinct from C2-R14's CONFLICT restart, which retains Etna execution rules. C4 specifies the authenticated upgrade and C2-R21 applies to its L1 checkpoint visibility; neither introduces an automatic runtime fallback.

**Adversary schedule:** install a guarded writer before the sealer records zeros, reset `ancestorsHash` without its guard, call old Anchor between upgrade and rollback time, withhold a voluntary reveal, or retain stale checkpoint history during restart.

### C1-R10. Storage compatibility and bridge-facing semantics

**[assumed: proposed rule, incorporating C2-R21]** Keep proxy addresses, inherited fields, received-signal cache locations, signal-slot derivation, checkpoint map root and two-word value ordering. Preserve epoch-1 checkpoint slots. Add the pin namespace below and, on the L1 implementation, consume one reserved-gap slot for the rollback-floor list below; remaining gap slots retain their locations. `VERSION = 1` remains the initial epoch and existing signal-cache domain; checkpoint lookups use C1-R06's selected epoch instead of treating VERSION as their permanent outer key. Mode remains an implementation immutable.

Only C4's DAO forward-upgrade/reinitializer can append a rollback floor as part of the authenticated C2-R21 recovery; it appends `(previousEpoch + 1, restoredHeight)` with checked arithmetic, where `restoredHeight` equals the newest written checkpoint height under C2-R15, never mutates/deletes/reorders previous floors or checkpoint values. It is not an operational caller-selected setter. No pin/reveal changes signals, received caches or Bridge reimbursement counts. Preserve the ordinary one-hop proof ABI and remote SignalService binding. Epoch floors do not revoke received-signal caches or completed/retriable Bridge effects: C2-R14's published-checkpoint limitation excludes that rollback on the current path, C4 owns the disposition table, and C6 indexes the residual beside L-PF without treating the Bridge quota as a lifetime loss bound.

Anchor history/progress stays frozen under the Etna execution profile and readable through its legacy ABI; the guarded forward rollback in C1-R09 is the only specified exception. C4-R10's table applies D26's removal of Anchor withdrawal, resolver registration and bridged-token owner mint/burn; C1 requires that none write legacy checkpoint/progress state under a nonzero current root. Pin pruning and per-record administrator repair remain absent.

**Adversary schedule:** shift old map slots or record widths, ignore floor equality, select floors by height instead of append order, fall back to a voided epoch, use a floor setter outside upgrade recovery, count pin writes as reimbursements, or mistake old received-cache bits for revoked state.

**[assumed: source-layout reference, live deployment audit open]** At snapshot [BASE], `SignalService_Layout.sol` reports Pacaya reserved slots 251 to 252, received signals at 253, checkpoint map at 254 and gap 255 to 300 [SS-LAYOUT]. VERSION is initially 1 [SS-STRUCT]. For `n:uint48` and the selected `e:uint256`, the checkpoint's hash slot is

```text
outer = keccak256(abi.encode(e, uint256(254)))
record = keccak256(abi.encode(n, outer))
hash at record; stateRoot at record + 1 (EVM 256-bit slot arithmetic)
```

**[assumed: rollback-list reservation; physical layout owned by C8]** The floor array and C1-R06 scan ship at Etna in `L1_INBOX` mode only. Slot 255, taken from the old gap, is the initially empty `RollbackFloor[] floors` array root; gap 256 to 300 stays reserved. C8-R15 defines the accepted element types, packing and stride under D49; C1 does not define a second physical element layout. Entry `i` has checked epoch `i + 2`, so no separate current-epoch slot is needed. C1-R06 scans at most `floors.length` entries, one per upgrade recovery, not per checkpoint. Lookup gas grows with recovery count and is **unmeasured**. C4/C8 compare the compiled/deployed layout and recovery count with the execution budget before an append. L2 does not append this list.

**[assumed: proposed new namespace]** The pin map's sole mapping root is:

```text
P = keccak256(abi.encode(
      uint256(keccak256(bytes("taiko.etna.origin-pins.v1"))) - 1
    )) & ~bytes32(uint256(0xff))
pin[h] at keccak256(abi.encode(h, P)); absent = 0, present = 1
```

**[proven: compatibility, conditional]** The namespace, immutable mode and use of the reserved gap do not shift an existing live slot; epoch 1 retains its mapping address formula. This does not prove the live deployment layout or a future compiled upgrade matches the source layout; C4 must compare them. The baseline mapping and helper are private [SS-STRUCT], so a compatible base refactor or replacement implementation is needed; an inaccessible subclass override is not an implementation plan. Storage collision resistance remains A-CRYPTO.

**[assumed: baseline interface fact]** Existing Anchor storage is `blockHashes` at 251, reserved 252 to 254, deprecated field 255, `BlockState` 256 to 257 and gap 258 to 300 [ANCHOR-LAYOUT]. C1 adds no Anchor storage, no anchorV5, no mandatory Anchor call and no new callback from SignalService to Anchor. C4-R10 applies the accepted D26 removal of Anchor withdrawal, resolver registration and bridged-token owner mint/burn; C1-R07 separately governs every checkpoint/progress writer. Merely zeroing a pauser immutable would leave owner authorization in baseline SignalService [SS-PAUSE].

**[assumed: authentication-flow projection, argued in §7]** The L2 flow is `C2-authenticated L1 header hash -> standard L2 oracle -> pin or live timestamp -> full-header reveal -> existing L2 checkpoint map -> existing remote account/storage proof verification -> Bridge/Vault`. The reverse L1 flow remains `C2-accepted L2 execution proof -> authorized Inbox saveCheckpoint -> existing L1 checkpoint map`. This section does not authorize publication of an unproved L2 root. The accepted C2-R13/R15 rules define which proof status permits that custody write under D36; their proof-soundness and irreversibility premises remain conditional.

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
  requester saves a provable CALLDATA request after the signal's L1 block
  request block: EIP-4788 -> EIP-2935 -> C1-R05 system pin -> manifest transactions
  after landing, requester retrieves that pinned origin's full header
            -> C3: CALLDATA request for revealCheckpoint(pin sentinel, full header)
  successful reveal -> existing checkpoint map -> ordinary bridge proof
  consumed/void/skipped/reverted alone -> no successful reveal established

partial upgrade / first-block old signer
  old signer -> guarded Anchor -> current nonzero root -> revert
  alternate old route -> prohibited by C4 activation precondition

prover failure or L1/L2 reorg
  C2/S2 recovery changes canonical block history
       -> normal state rollback, including oracle, pins and checkpoints
       -> recompute C1 state on the accepted replacement history
```

**[assumed: caller incentives/failure profile]** Entry/exit are ordinary transaction submission and stopping submission. C1 assigns no exclusive duty, protocol reward, bond or slash for merely attempting an ordinary pin/reveal; saving a C3 request separately incurs C3's charges and settlement. A malformed ordinary attempt pays normal gas and has no accepted write. Successful callers gain checkpoint availability for their own or others' bridging. If all callers go offline, optional checkpoint freshness stops but block execution does not wait for a reveal; request blocks still apply C1-R05. Any new funded caller may resume reveals. If all callers are malicious, accepted writes are still constrained by C1's predicates, but they can maximize permanent state growth and need not serve archived data. Bonded availability or execution duties and their slashing evidence belong to S3/S4; C1 creates no slashable evidence of a P2P failure to serve.

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
| P-EXTRA | 7 bytes | **derived:** one fee byte + four term bytes + one view byte + one kind byte. Layout accepted under D28; full-envelope vectors remain open. |
| P-FEE-SHARE | 100 percent (byte `0x64`) | **assumed proposal:** all native-ETH base fee goes to block coinbase; policy input is BASE `MainnetInbox.sol:46` (Proposal0026), not a measured economic optimum. S3 must define the selected chain's fee accounting and rewards consistently; no C1 proof of nonrecoupable storage cost. |
| P-TERM / P-VIEW / P-KIND | unsigned 32 / 8 / 8 bits | **assumed accepted profile:** candidate A header allocation adopted under D28. Semantic limits and reserved encodings owned by S2/C3. |
| P-FI-EXAMPLE-GAS | 1,000,000 gas | **open/unmeasured:** illustrative transaction envelope for §8 arithmetic, not a selected C3 cap and not an execution/proof gas claim. |

**[assumed: upstream constants]** The bytecode below is the runtime portion of the deployment input in the pinned EIPs, with the initial nine-byte constructor removed. `expectedCodeHash = keccak256(exact runtime bytes)`. Runtime identity, not merely nonempty code, is the C1-R04 predicate. C4 records and checks the resulting code hashes in its activation manifest.

| Constant | Exact value |
|---|---|
| System caller | `0xfffffffffffffffffffffffffffffffffffffffe` |
| EIP-4788 address | `0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02` |
| EIP-4788 runtime code hash | `0xf57acd40259872606d76197ef052f3d35588dadf919ee1f0e3cb9b62d3f4b02c` (**proven: derived** from the runtime bytes below) |
| EIP-2935 runtime code hash | `0x6e49e66782037c0555897870e29fa5e552daf4719552131a0abce779daec0a5d` (**proven: derived** from the runtime bytes below) |
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

**[proven: checkpoint integrity, conditional]** Assume A-CRYPTO, A-ORIGIN, A-ORIGIN-CHAIN, A-LEGACY-ZERO, A-EXEC, A-HISTORY and A-UPGRADE. For the canonical landed history under the Etna profile, inherited records are authenticated at the migration boundary by A-HISTORY and every fresh accepted L2 checkpoint is a C1-R08 reveal. For a reveal, its whole-header hash equals a previously authenticated origin word, directly or through a C1-R05 pin. C1-R08 extracts number/root from those same bytes, so substituting another root or number requires a hash failure or violating an assumption. C1-R06 preserves the first record and rejects partial/conflicting replacements. Induction over successful mutations gives authenticated map contents. This does not establish that a tentative origin is finalized; the entire L2 state can reorganize, and the governing origin policy must account for that.

**[proven: first-Etna writer closure, conditional]** Under A-EXEC and A-HISTORY, C1-R02 writes the nonzero selected origin before transaction execution, including in an otherwise empty block. C1-R07 therefore rejects every old writer in that block regardless of whether a caller has pinned or revealed. C1-R01 extends that condition to every valid successor under the Etna profile; a separately upgraded execution profile is outside this claim. Missing code/read does not open the guard. A partial upgrade violates A-HISTORY; this proof is not a substitute for C4's deployment audit.

**[proven: bounded uniqueness, conditional]** Let `M` be the number of distinct authenticated origin hashes ever selected in the canonical Etna history under A-ORIGIN, A-ORIGIN-CHAIN, A-LEGACY-ZERO, A-EXEC and A-HISTORY. This is the L2 epoch-1 bound, excluding the L1 rollback-floor list and its retired epoch values. Fresh C1 writes add at most `M` pin values and `2M` checkpoint values, thus at most `3M` 32-byte values, or `96M` raw value bytes. Conflicts and duplicates cannot increase that count. This excludes inherited state, trie keys/nodes, archive copies, ordinary signals and received-signal caches. It is a per-origin bound, not a lifetime bound or a bound per batch. It does not assume candidate B's abandoned one-origin-per-segment rule.

**[proven: ring bound, conditional]** For increasing timestamp values with difference strictly less than P-RING, their residues cannot collide. A jump by exactly P-RING can overwrite the original entry in the very next block. Thus neither an P-RING-block retention promise nor a wall-clock inclusion guarantee follows from this oracle. Pins remove that ring-expiry dependency for a selected hash, subject to canonical-history rollback and actual header availability.

| Attack trace [assumed: adversarial schedule] | Result under the cited rules, or explicit limit |
|---|---|
| Producer chooses private execution header; feeds hash to utility; later reveals false custody root. Cost: one payload/proof attempt. Gain: forged remote state. | C1-R01 needs C2's authenticated origin, not just a nonzero utility word. **Assumed dependency answered:** C2-R04/R19 at 4ee1dd6 authenticate every origin; unlanded bad-origin effects are provisional and replacement removes them. |
| Legacy publicly known signer submits old Anchor before any user reveal in first Etna block. Cost: one transaction. Gain: checkpoint poisoning. | C1-R02/R07/R09 close before that transaction. **Open, C4/C8:** exact manifest schema and reference fixtures; C4-R01/R10/R11 define the accepted requirements under D32. Actual installation evidence remains a later deployment gate (C1-O02 below). |
| Upgrader leaves an old router target reachable. Cost: partial upgrade. Gain: old writer bypass. | Violates C1-R07/R09 and A-HISTORY; activation must not be certified by C4. C1 does not repair a bad installed proxy. |
| Caller makes a duplicate after the old oracle entry expired or supplies a fresh hash at an occupied height. | C1-R06/R08 give idempotent success for the former and conflict failure for the latter, without an unbounded scan. |
| Producer delays a historical-timestamp forced reveal until a ring collision, or pre-executes the queued ordinary pin before the signal's origin. | §8 uses C1-R05's request-block system pin and a sentinel reveal. **Open, C1/C3/C8/C6:** A-INCLUSION/A-FUNDING and wrapper fit; C1-O03 states the closure evidence. |
| Provider promises availability, pins a header hash, then deletes the header/proof bytes. Cost: no continued service. Gain: griefing callers. | Pin proves membership, not availability. A-ARCHIVE remains necessary; no C1 objective slashing evidence exists for private non-service. |
| Ordinary caller uses delegation or copied oracle code to obtain system write authority. | Standard EVM caller/storage identity and exact canonical runtime under A-CRYPTO: copying code does not write the canonical address's storage; delegation does not confer the system sender's authorization. |
| Caller submits oversized/nonminimal RLP or hopes a malformed oracle return decodes as zero. | C1-R04/R08 bound the read/parser and fail closed. Exact gas sufficiency remains unmeasured. |
| Producer reorgs a block containing a pin/reveal after a user observes its event. | Ordinary rollback applies. C1 supplies no finality or indemnity; S2's D1 evidence and exceptions must be explicit. |
| Integrated producer repeatedly pins and reveals every distinct origin, recovering transaction fees through coinbase. | Uniqueness bound above; no lifetime cap or irrecoverable charge. **Open:** S3/C6 resource economics, including direct unpinned reveals. |
| L1 publication treats a provisional/degraded proof root as immediately spendable, then changes that root after a conflicting proof. | **Closed as a rule/review request under D36:** C2-R13/R15 prevent publication through an unfinalized provisional prefix, and C2-R14/C4-R12 constrain the restart to the published boundary. C1-O04 retains the soundness, CONFLICT and L-PF limitations; no unconditional custody guarantee follows. |

## 8. Conditional censorship-recovery and encoding examples

**[assumed: recovery flow consuming C3-HATCH]** Use two provable CALLDATA requests, whose content has no blob-expiry rule under C3-R12. Save the first on the intended L1 chain after the persistent signal's containing block. Its ordinary content may call `pinCurrentOrigin()`, but recovery relies on the request-block system pin defined in C1-R05. After that request block lands and its pin is present in the history being continued, obtain its exact selected header and save a second CALLDATA request carrying `revealCheckpoint(P-PIN-SENTINEL, header)`. Reveal remains an ordinary signed transaction with C1-R08's predicates, nonce, fees and execution budget. The second request's own system pin does not replace the earlier pin used by its reveal.

**[proven: origin progress and checkpoint recovery, conditional]** Assume A-CRYPTO, A-ORIGIN, A-ORIGIN-CHAIN, A-LEGACY-ZERO, A-EXEC, A-HISTORY, A-INCLUSION, A-FUNDING, A-ARCHIVE and A-UPGRADE. By the A-ORIGIN-PROGRESS dependency, the first landed request block's authenticated origin is at or after its save, including for a replay: C3-R08 proves the comparison for kind FI and C3-R07 check 5 enforces it for FORCED. The signal precedes that save and persists on the same L1 chain, so the pinned origin contains it. This closes the authentic-but-perpetually-pre-signal schedule without a committee-honesty premise T11. Pre-execution of the first request's ordinary pin cannot suppress its system pin. Under C1-R06/R08, successful execution of the second request's reveal writes the first origin's checkpoint or returns the identical existing tuple, regardless of ring eviction. If the same reveal has already succeeded on the continued history, that state already satisfies the recovery goal. Obtain the corresponding account/storage proof to use the checkpoint; a pin supplies none of those bytes. Ordinary state rollback still applies, and a pin observed only on a replaced branch is insufficient. Neither this argument nor the reveal envelope proves that an arbitrary Bridge message/proof fits forced inclusion.

**[proven: limits of the consumption argument, conditional on the revised source premises]** C3-R05(a) can skip invalid or over-budget transactions. The revised [C3-HATCH] §9 bounds provable request-block execution only under its latency, active-epoch or inherited-entry, and other stated premises; it does not guarantee success of every transaction. A void with no request block creates no pin; a skipped or reverted reveal creates no checkpoint. BLOB/LEGACY requests may execute expiry-empty, which still pins the request block's origin but cannot perform their reveal content. An unprovable recovery request may be voided as a poison. D55's poison-adjacent delay and late quorum replay remain in scope; neither authorizes counting queue movement or replayable status as completed signal recovery. The CALLDATA route avoids content expiry, not nonce, funding, completeness or execution failures.

**[proven: timing composition conditional on the revised source and both requests' premises; open: end-to-end bound]** For each request saved during the active epoch with no CONFLICT restart before consumption, let `B_pin` and `B_reveal` be its own save-to-execution ceiling from the revised [C3-HATCH] §9, including its queue and hatch terms and A-HATCH-LATENCY's strict pre-close inclusion margin. For an inherited request, use §9's `close_e` relative to its save instead; a restart replaces the previous deadline, and no uniform original-save bound follows. If every premise holds separately for both requests, A-INCLUSION and A-FUNDING hold, and `delta` bounds header retrieval, confirmation of the continued pin state and the second L1 save, recovery takes at most `B_pin + delta + B_reveal` from the first save. In particular the reveal must execute successfully or already have succeeded; queue consumption alone is insufficient. This is a conditional composition, not a new queue rule. The source's rounded empty-queue ceilings are 4 h 30 min each, or 9 h before `delta`; the strict inclusion margin does not turn that illustration into a universal under-9 h claim. Backlog is unbounded and D55 permits additional poison-adjacent delay. No measured or worst-case upper bound for `delta` or the eventual reveal fee envelope is supplied here.

**[assumed: archive baseline]** Today's SignalService ordinary send path writes a signal value at `keccak256(abi.encodePacked("SIGNAL", uint64(chainId), app, signal))` [SS-SIGNAL]. A later checkpoint can witness an earlier signal if the relevant state and compatible storage proof remain available; C4 must preserve this property across upgrades. It is not permission to fabricate a proof from the pin alone.

**[proven: derived ABI size]** At the proposed maximum header length, the reveal calldata is `4 + 2*32 + 32 + ceil(1536/32)*32 = 1,636` bytes: selector, two ABI head words, dynamic length, padded bytes. The pin calldata is only its four-byte function selector. Function selectors are the first four bytes of Ethereum Keccak of `pinCurrentOrigin()` and `revealCheckpoint(uint64,bytes)` respectively; they are not SHA3 digests.

**[proven: constructive raw transaction bound]** Consider a type-2 transaction with that calldata, a non-creation destination, zero value, empty access list, a nonce bounded by uint64, arbitrary uint256 chain ID and fees, and gas limit at P-FI-EXAMPLE-GAS. Its maximum RLP field sizes are: three uint256 fields `3*33 = 99`, nonce `9`, gas `4`, destination `21`, zero value `1`, data `1,639`, empty list `1`, parity `1`, signatures `2*33 = 66`. Payload total `1,841`; outer list prefix `3` and transaction type `1` give **1,845 bytes**. This derivation is conditional on those dimensions, not a statement that every account/transaction fits. Against [C3-HATCH] §7's adopted FI_CALLDATA_MAX of 4,096 bytes, the 1,636-byte call is smaller, but the limit applies to the complete manifest. The illustrative raw transaction leaves `4,096 - 1,845 = 2,251` bytes for its manifest encoding; an exact accepted encoding must still demonstrate fit.

**[open: recovery execution and measurement]** P-READ-GAS, header parse cost, initial/repeated system and ordinary pin costs, fresh/duplicate reveal gas, proof cost, complete manifest length, repricing headroom and eventual nonce/fee funding lack conformance evidence here. [C3-HATCH] §7 selects FI_GAS_LIMIT = 5 M EVM gas and FI_ZK_GAS_LIMIT = 20 M zk gas per request block; P-FI-EXAMPLE-GAS is only an illustrative transaction limit, not a measured fit in either budget. The system pin's accounting is the open C1-R05 interface item. C1/C3/C6 must discharge their existing execution, envelope and measurement obligations, with C8 recording the interface. Until a valid reveal remains executable throughout its admitted delay, A-INCLUSION is an additional premise, not a consequence of the hatch bound. A consumed CALLDATA request containing a nonce-invalid, underfunded or over-budget reveal is a concrete counterexample to that implication. Under D44 these gaps require an exact manifest, conservative execution budgets and measurement procedure, and a funding/refresh argument; this update does not choose those missing rules.

### Deterministic examples and test-vector obligations

**[proven: byte/arithmetic vectors and rule projections; open: explicitly marked integration items]** These examples are exact encodings or rule projections. They are not test executions or deployed-state fixtures. Integer values in the examples are chosen fixtures, not economic parameters.

| Vector | Input | Expected result / derivation |
|---|---|---|
| V01 extraData | fee 100, term 1, view 2, kind 3 | `0x64000000010203`; parsing recovers the physical fields. Semantic acceptance of kind 3 is left to C3/S2. |
| V02 raw getter | timestamp 1 | `0x0000000000000000000000000000000000000000000000000000000000000001`; not ABI `get(uint256)` calldata. |
| V03 collision | roots `H1` at timestamp 1, `H2` at timestamp 8192 | residue 1 both times; after the second write getter(1) reverts, getter(8192) returns H2; a fresh `revealCheckpoint(1, headerH1)` gives `EtnaOracleUnavailable`, as does a never-recorded positive timestamp; an earlier pin(H1) permits the sentinel reveal. V06 separately covers duplicates. |
| V04 malformed integer | number field `0x00` versus `0x80` | first is nonminimal integer zero and rejected; second is minimal zero. Whole-header authentication is still independently required. |
| V05 width boundary | number field `0x86ffffffffffff` versus `0x8701000000000000` | first is maximum uint48; second is `2^48`, rejected before cast. These are RLP field bytes, not complete headers. |
| V06 duplicate | existing `(n,H,R)`, same complete header, expired positive timestamp | current nonzero guard and parser pass, exact tuple returns with no event/write, no historical read, by C1-R08 step 4. |
| V07 conflict | existing `(n,H1,R1)`, parsed `(n,H2,R2)`, `H1 != H2` | `EtnaCheckpointConflict(n)` before checking historical timestamp/pin. |
| V08 corruption | existing `(n,H,0)` or `(n,0,R)` | `EtnaCheckpointCorrupt(n)` for getter or write; never auto-repair. |
| V09 phase | current read unavailable / zero / nonzero | unavailable is error; zero admits only authenticated legacy writers; nonzero admits new operations and rejects old writers. |
| V10 identity | same execution header/transactions, different logical `vcHash` in PH envelope; interchangeable witnesses of one logical opening keep that id | S2-R03 and D16 own identity; blockHash alone is insufficient. **Partly closed under D49:** C8-V02 supplies the PH hash vector and C8-V09 the logical opening id. **Open, C2/C8/S2:** full-envelope/certificate bytes and the guest-rebuild acceptance/rejection fixture, matching C1-O06 and §10. |
| V12 epoch selection | no floor; equal/increasing floors; hypothetical decreasing floors | C1-R06 lookup outcomes below; decreasing floors do not imply an available current recovery. |
| V13 request system pin | FI or FORCED block with current origin H and a missing pin; repeat with H already pinned | C1-R05 writes membership before manifest transactions, or leaves the existing bit unchanged; no transaction, nonce increment or receipt. **Open:** system gas/log parity per C1-R05. |
| V14 pre-executed pin | queued ordinary pin copied into a pre-signal block, using its nonce before the request block | The copied call's old pin does not suppress the request block's own system pin; C3-T11 at [C3-HATCH]. |
| V15 old replay origin | kind-FI replay with authenticated anchor timestamp below its entry's save | C3-R08's guest assertion fails under T3, independently of T11; C3-T22 at [C3-HATCH]. No qualifying A-ORIGIN-PROGRESS pin is established by that unlandable branch. |
| V16 consumed without reveal | expiry-empty BLOB/LEGACY request, or CALLDATA request with skipped/reverted reveal | A request block still applies C1-R05, but no fresh checkpoint follows from its consumed status; C3-R05(a) and §8. A void without a request block supplies neither operation. |

**[proven: V12 lookup-only vectors]** With no floors all heights select epoch 1. After `(2,100)`, height 100 selects 1 and 101 selects 2. A hypothetical later upgrade permitting a decreased floor appends `(3,80)` (not allowed by current C2-R15): 80 selects 1, 90 selects 3 and 100 selects 3, so being below the oldest floor does not imply epoch 1. Append `(4,120)`: 120 still selects 3, 121 selects 4. Appending the same floor with epoch 5 leaves 120 in 3 and selects 5 at 121. An empty selected record gives not-found, never a record from another epoch. Fixture numbers are illustrative; the array traversal limit is its length. These vectors specify lookup semantics, not EVM test results.

**[proven: ABI selector vectors]** The signatures in §8 evaluate to `pinCurrentOrigin() = 0xb5ad3e31` and `revealCheckpoint(uint64,bytes) = 0x6c7d3fdf`. The new view is `isOriginPinned(bytes32) = 0xafa0caba`.

**[proven: complete synthetic parser vector V11]** The following 78-byte RLP input has exactly twelve scalar fields. Parent hash is 32 copies of `0x11`, state root is 32 copies of `0xaa`, number and timestamp are 1, and all other fields are empty strings. It parses under C1-R08 and hashes to `0x97349d16acda015ee25d7468566d0759c8d128707dec6b16fd17254b76233723`. It is deliberately only a parser fixture, not a valid/authenticated Ethereum header: live acceptance additionally requires A-ORIGIN and the oracle/pin equality. A caller cannot make a trusted origin by constructing this input.

```text
0xf84ca011111111111111111111111111111111111111111111111111111111111111118080a0aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa8080808001808001
```

**[proven: reproduction record, limited scope]** The runtime extraction, namespace/selector/parser digests, ABI/envelope arithmetic and raw-value storage counts were recomputed in a disposable scratch script with PyCryptodome 3.23.0 `Crypto.Hash.keccak`, checked against the standard empty-input and `abc` Keccak-256 vectors. Runtime bytes matched the pinned EIP deployment inputs after constructor removal. This verifies byte arithmetic and hashes, not EVM execution, parser implementation, proof soundness or gas. The throwaway script/dependency are not part of the specification or PR.

**[open: implementation conformance suite]** The eventual implementation must provide full authenticated L1-header fixtures and independent builder/importer/guest roots for: empty first block, both standard system operations, the V13 to V16 request-block cases, legacy-zero transition, fresh/duplicate/pinned reveal, same-height conflict, malformed parser branches, ring collision, proxy-route bypass attempts and reorg rollback. C2/C4 supply the selected fork headers and deployed-code/layout manifests; C6 records their current absence. No production tests or contracts are delivered by this research PR.

## 9. Limits and rejected alternatives

| Choice | Reason and residual [proven/assumed/open as marked] |
|---|---|
| Standard utilities and optional reveal, not mandatory anchor transaction | **Proven, conditional:** C1-R02/R07 remove the transaction-position dependency while closing old writers before ordinary execution. **Open, C1/C4/C8:** specification profile, manifest and parity fixtures (C1-O02/O08); implementation execution evidence is a later deployment gate. Credit [ISSUE], [B-CHECKPOINTS], [B-CODEC]. |
| Current-root guard, not voluntary `beginEtna` | **Proven:** a voluntary transaction can be withheld or ordered after the legacy writer; the system operation precedes every ordinary transaction. |
| Permanent membership, not mandatory historical-timestamp forced reveal | **Proven:** V03 defeats a fixed old timestamp after queue delay. **Open:** permanent-state costs. |
| No global latest-checkpoint pointer | **Proven:** independent authenticated heights can be revealed out of order without creating overwrites; a latest-only gate could block delayed valid bridging. |
| No per-record administrator repair or pin pruning | **Assumed:** C2-R21 permits only forward-upgrade rollback floors on L1, preserving old slots while changing visibility; no ordinary repair/prune entry point exists. **Assumed scope:** a future storage policy is outside the accepted no-pruning design and would require a new decision plus retention/migration proofs; it is not an outstanding rule to invent for this design (C1-O09). |
| No new Bridge/SignalService/Vault address | **Assumed:** existing proxy upgrades preserve R2's address constraint; complete live-layout and selector audit is C4's responsibility. |
| No inherited B staging/rent/segment timing | **Assumed:** the merged committee design owns these choices. This section counts distinct origins and consumes C2's policy. |
| No "pin means available/final/confirmed" label | **Proven:** a hash preimage can be withheld, and its containing state can reorganize. S2/S3 must supply D1 and availability claims separately. |
| No storage tariff in this proposal | **Assumed:** public pin/reveal methods remain nonpayable ordinary calls, with the request-block system pin specified in C1-R05. **Open:** a fee only on ordinary pins would miss system pins and direct timestamp reveals; a future policy must cover all fresh persistent writes, duplicate behavior, fee sink and forced funding. Ordinary producer-recoverable gas is not a permanent-storage price proof. |

**[proven: illustrative growth only]** With 100 distinct origins, the bound in §7 is 9,600 raw value bytes. If, as a hypothetical workload rather than a selected origin policy, a year has `365*24*60 = 525,600` distinct origins, pins alone account for `16,819,200` raw value bytes and pins plus checkpoint values for at most `50,457,600`. Actual disk/archive use is larger and unmeasured. No origin-frequency or monopoly-resistance guarantee follows.

## 10. Integration dashboard and requirement impact

| Owner / obligation | Status and closure condition |
|---|---|
| C2: O_b authentication and single-chain premise | **Assumed dependency answered:** C2-R04/R19 at 4ee1dd6 authenticate every origin through the canonical tip, export A-ORIGIN-CHAIN and origin progress. **Open:** selected header-profile bound and exact metadata/full-header vectors; review is not replaced by this citation. |
| C2/S2: provisional effects and conflict recovery | **Assumed dependency answered:** C2-R19/R20 and S2 confirmation levels make unlanded effects provisional and replaceable. C1-R06 states the permanent same-epoch hole and replacement consequence. |
| C2/C4/C8: publication and rollback floors | **Assumed dependency answered:** C2-R15 avoids same-epoch conflicting publication, C2-R21 selects a new epoch above the restored height. **Accepted under D49:** C8-R15/V12 specify floor layout and slot vectors. **Open, C4/C8/C6:** access budget, migration packing/manifest and integrated restart identity fixtures (C1-O11). C4-R12's published-boundary recovery composition is accepted under D32/D63; see C1-R10 for the single cache/Bridge boundary statement. |
| S2: confirmation identity and execution-context labels | **Open.** Prove slashable D1 confirmation with S2-R18 exceptions and S2-R03 identity binding with the S2-V14/C8 reference vector under P-B-C1-01. A header word or pin does not discharge D1. |
| C2: L1 custody checkpoint publication | **Assumed dependency answered:** C2-R13/R15 at 4ee1dd6 gate publication across provisional records. **Closed as the requested W8 review under D36:** C2's acceptance records B's approval and J's regression sweep. The conditional proof/finality premises and C2-R14's L-PF residual persist (C1-O04); C1-R07 preserves authority without strengthening that policy. |
| C3: request execution and recovery | **Accepted C3 source under D59; C1 consumption accepted under D63:** [C3-HATCH] C3-R05(d) in C1-R05 and §9's conditional bound in §8. That bound ends strictly before the request becomes voidable and applies from save only within an active epoch without an intervening restart; inherited entries use close_e. **Open:** measured acquisition/proving/submission and inclusion latency, complete manifest fit, successful reveal nonce/fee/execution envelope, system-operation interface and timing gap identified in §8. The two-request construction has no general guarantee of recovery in under 9 h. |
| C2/C3: origin progress for signal recovery | **Proven conditionally:** §8 composes C3-R05/R07/R08 at [C3-HATCH] with C2's authenticated chain and signal persistence. Request-block save-before-anchor is enforced without T11; no progress is inferred from a void without a request block. **Open:** implementation conformance and the remaining A-INCLUSION premises. |
| C4: authenticated boundary and no old writer route | **Accepted requirements under D26/D30/D32/D63:** C4-R01/R02/R09 to R13 own that inventory, legacy-zero transition, guarded installation, authority removals, getters and published-boundary rollback. **Open, C4/C8:** exact manifest/schema/reference fixtures and restart identity integration (C1-O02/O11); verifying a particular deployed installation is a later gate. |
| S3/C6: retention economics | **Open.** Accept or price unbounded distinct-origin growth, recognizing fee recapture and direct-reveal writes. A new tariff/pruning proposal changes the interface and requires a decision. |
| C6: unmeasured register | **Open.** Index P-READ-GAS, parser bounds/profile, fresh/duplicate ordinary and system pin costs, reveal fit against C3's EVM/zk budgets, complete manifest length, runtime parity, state/disk growth and selected-fork gas repricing. Preserve source/derived/unmeasured distinctions and D55's accepted limitations. |
| C7/C8: composition and consolidated interfaces | **Open.** C7 invokes C1's component, including C1-R05, without treating `C1_PASS` as complete validity; C8 indexes the declarations and the open system-operation interface with C4 layouts without diverging duplicate definitions. |
| A/J: review | **Recorded acceptance:** D28 accepts the C1 component and D63 accepts the hatch-consumer update at `d997a9bc7b7489a2ac2e8c15f01b52c5280a8907`. D63 records A's closed blocking items and no J comment on #22217; it is not a new J review or the final D44 audit. Historical review dispositions below retain their original scope. |

| Requirement | C1 contribution, not a whole-design pass |
|---|---|
| R1 | **Proven conditionally:** new calls accept any address and block execution needs no checkpoint operator. **Closed authority decision:** D26 removes all three former operational powers, consumed by C4-R10 under D32 and by C1-R10 here. C4/C8's complete manifest remains open (C1-O13); other roles are specified elsewhere. |
| R2 | **Proven conditionally:** API/layout proposal reuses maps/proxies and ordinary bridge paths. **Accepted rules:** C2-R13/R15 (D36), C4-R10/R11 (D32). **Open, C4/C8:** exact manifest/layout/selector fixtures; a live deployment audit is a subsequent installation gate (C1-O14). |
| R3 | **Assumed:** caller lifecycle/failure behavior in §5; bonded roles and all-offline recovery owned by S4. |
| R4 | **Assumed target:** timestamps allow the required one-second issuance profile. **Open:** S2 propagation/confirmation and execution/proving capacity, not proven by removing Anchor. |
| R5 | **Proven for C1:** no CL lookahead, slot or CL epoch input (checkpoint epoch means a local rollback generation); timestamps and block-number windows retain their units if L1 cadence changes. C2 owns its independent timing policy. |
| R6 | **Open outside C1:** malformed calls fail objectively, but C1 creates no slash for private non-service and no anti-monopoly claim. S3/S4 must specify these. |
| R7 | **Open outside C1:** C2 binds these execution outputs in its atomic data-plus-proof action; C1 does not specify landing races, prover replacement or finality. |
| D1 / D2 | **Open / assumed scope:** D1 depends on S2/S3; D44 requires exact specification integration and conservative defaults with measurement procedures while the task stays design-only under D2. This merged C1 section alone is not spec-ready convergence. |

## 11. Evidence and credit

**[assumed: source facts]** The original source inspection was on 2026-10-01; [C3-HATCH] and [HATCH-DECISIONS] were inspected at the immutable revisions below on 2026-10-02. Repository snapshot evidence is not a live deployment audit. The Ethereum EIP snapshot was fetched at run time; fork adoption beyond the explicitly selected runtime/profile belongs to C5.

- [BASE]: convergence base `1e74435947d3d1ee1c47f9bf19cbc4a2193dace1`.
- [C3-HATCH]: [C3 at `eebc59808aa16e291ab262c31aa224c60979ef5d`](https://github.com/taikoxyz/taiko-mono/blob/eebc59808aa16e291ab262c31aa224c60979ef5d/packages/protocol/docs/Etna/spec/C3-forced-inclusion.md), especially A-HATCH-LATENCY, C3-R05, C3-R07 check 5, C3-R08, §7, §9 and §10's C1 obligations. This revised source merged under D59 owns the hatch rules consumed here; D56's earlier freeze and limited review are not acceptance of this head.
- [HATCH-DECISIONS]: [D41, D51, D55 and D56 at `47de43c0ee9ba7ecee7c01f4cd0af8d453662db4`](../DECISIONS.md). Their acceptance and review scope do not replace the open execution and measurement obligations in §8.
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
- [A-METADATA]: [A's seven-byte header and removed Anchor fields at 8ef29cd](https://github.com/taikoxyz/taiko-mono/blob/8ef29cd29497763cceb40a8c3b079f632428f70a/packages/protocol/docs/Etna/design/bridge-migration.html#L42); [A's PH definition](https://github.com/taikoxyz/taiko-mono/blob/8ef29cd29497763cceb40a8c3b079f632428f70a/packages/protocol/docs/Etna/design/preconf.html#L23); [the old anchor-calldata binding claim at line 34](https://github.com/taikoxyz/taiko-mono/blob/8ef29cd29497763cceb40a8c3b079f632428f70a/packages/protocol/docs/Etna/design/preconf.html#L34); [A's canonical publication fields](https://github.com/taikoxyz/taiko-mono/blob/8ef29cd29497763cceb40a8c3b079f632428f70a/packages/protocol/docs/Etna/design/landing.html#L26). Those historical files contain `anchorV5`; current C2/S2 text below replaces that historical mechanism. Its adoption does not by itself reproduce the outstanding exact metadata vectors.
- [Ownership confirmation](https://github.com/taikoxyz/taiko-mono/pull/22191#issuecomment-5927671024) and [working agreement](https://github.com/taikoxyz/taiko-mono/pull/22188#issuecomment-5927629688). Pending cross-module choices are recorded in [DECISIONS.md](../DECISIONS.md), not silently attributed to A or J.

## 12. W1 review disposition

**[assumed: revision record]** Applied the reviews linked below; this table is a disposition index, not a second definition of the rules or reviewer approval.

| Review item | Revised owner / result |
|---|---|
| A-1 activation order and parity | C1-R02/R09 and A-EXEC: utilities before guarded legacy writers, with sealer parity and actual zero-root writes. |
| A-2 / J-1 single chain, hole, recovery, effects | A-ORIGIN-CHAIN conditions §7 and §8; C1-R06 states the permanent same-epoch hole, whole-range C2 authentication, provisional local effects and replacement recovery. |
| A-3 guarded forward rollback | C1-R09 permits the reviewed ring reseed/client-time/void-set upgrade and requires the guard installed with every reset. |
| A-4 retained DAO-only powers | Historical W1 deferral is closed by D26: C4-R10 removes all three operational powers under D32, and C1-R10 consumes that decision. No remaining product choice is attributed to that old review item. |
| A-5 L1 behavioral change / J-2 inherited getter | C1-R06 names the L1 revert/no-event schedule and defensive inherited read change for C4's table. |
| A-6 pause | C1-R05 owns the no-pause rule for both new operations and the unconditional rejecting pause authorization hook. |
| A-7 legacy decoder and kind owners | C1-R03 names both encodings and C8/S2/C3/C4/C7 ownership. |
| A-8 legacy oracle contents | A-LEGACY-ZERO, C1-R09 and conditional §7/§8 arguments. |
| A-9 expired/absent positive timestamp | C1-R08 step 5 and V03; duplicates remain the separately specified V06 case. |
| A-10 tags and source details | §4 flow is a projection; V10 consumes S2-R03/V14 and D16; the new uint64 ABI aligns with the PH timestamp carrier, bounded by P-NUMBER; source/hash rows are tagged and arithmetic formatted. |
| W1 C2-R21 adoption | C1-R06/R10 and §4: append-ordered epochs, preserved old slots, reserved-gap floor list, below/equal/above-floor semantics, no fallback to voided values. |
| A follow-up 5933727702 items 1–4 | C8 owns floor packing; latest base decision rows merged; C1-R03 explains the new ABI width; C1-R06 states equality precisely and C1-R10 limits appended floors to the newest published height. |
| A follow-up activation and editorial items | C1-R05 owns effective proof-path pause removal; C1-R09 requires unpaused state at activation; C1-R09 distinguishes CONFLICT restart/profile rollback and names ancestorsHash/anchorBlockNumber; §7 scopes its argument to Etna landed history; C1-R10 holds the single cache/Bridge caveat; V12 moved to §8. |

- [A's ten-item verdict](https://github.com/taikoxyz/taiko-mono/pull/22195#issuecomment-5928333211), [J's J-1/J-2 review](https://github.com/taikoxyz/taiko-mono/pull/22195#issuecomment-5931075137), [arbiter note](https://github.com/taikoxyz/taiko-mono/pull/22195#issuecomment-5931124696).
- [C2 at 4ee1dd6: R04, R13 to R15, R19 to R21](https://github.com/taikoxyz/taiko-mono/blob/4ee1dd65656167ae63adaa5d8326fd970e9403d7/packages/protocol/docs/Etna/spec/C2-landing.md), [S2 at 0403a54](https://github.com/taikoxyz/taiko-mono/blob/0403a540a2186f404d7e5bff99496d29a7be3789/packages/protocol/docs/Etna/spec/S2-certificates-and-handoff.md).
- [Fee-policy input, MainnetInbox.sol:46 at BASE](https://github.com/taikoxyz/taiko-mono/blob/1e74435947d3d1ee1c47f9bf19cbc4a2193dace1/packages/protocol/contracts/layer1/mainnet/MainnetInbox.sol#L46); [sealer/importer parity issue taiko-geth#601](https://github.com/taikoxyz/taiko-geth/issues/601) is an activation audit obligation from A's review, not a claim that this PR verifies that client fix.

## W15 open-item disposition

**[assumed: bookkeeping scope]** This table dispositions C1's entries in [J's W10 task 4 census](https://github.com/taikoxyz/taiko-mono/pull/22191#issuecomment-5967553118), under [A's W15 order](https://github.com/taikoxyz/taiko-mono/pull/22191#issuecomment-5968122322), against accepted decisions through [D69](../DECISIONS.md). Locations name rules or headings so the disposition survives line movement. “Closed” below closes only the identified decision or review request, not its assumptions or D44. D2 keeps production implementation and deployment out of this task; D44 still requires exact specification fixtures, defaults and procedures. S2 and S3 remain pending. D69 accepts #22227 as a measurement-plan specification, not measured results, gas fit or D44 readiness; the plan's §11 explicitly leaves C1/C4/C8 rows outside its census scope with their owners.

| Item / census location | Disposition, owner and closure condition |
|---|---|
| C1-O01: R05 system-operation interface; V13 | **Open, B (C1) with A (C8), consuming C3-R05(d).** The order and required pin state are accepted under D59/D63. Close the remaining interface item with the exact call surface, gas allowance/accounting and log treatment, plus builder/importer/guest reference vectors covering fresh and duplicate pins. C8 must adopt the same interface; no standard-utility allowance is borrowed implicitly. |
| C1-O02: §7 legacy-writer schedule; §10 C4 boundary; §9 implementation parity/migration | **Partly closed under D26/D30/D32/D63:** C4-R01/R02/R09 to R13 specify the manifest obligations, code-installation order, authority removals and guarded rollback. **Open, B (C4) with A (C8):** complete the manifest encoding, variant/selector and layout reference fixtures. Matching an actual compiled/deployed bundle to that specification and running implementation parity checks remain pre-deployment obligations under A-HISTORY/A-EXEC, not a request for production code in W15. |
| C1-O03: §7 A-INCLUSION/A-FUNDING; §8 recovery execution and measurement | **Open, B (C1), with A (C3/C8/C6 measurement) and B (C6 index).** Supply the exact signed reveal and complete manifest fixture, conservative EVM/zk budgets with measurement procedures, and an eventual nonce/fee-funding or refresh argument over the admitted delay. Bound or retain the explicit premise for the retrieval/second-save gap. A consumed request alone cannot close this item. D69 accepts MP-14's wrapped-reveal measurement procedure, conditional on C8 first fixing the field sets; this neither supplies that exact manifest nor proves successful reveal execution or fee funding. |
| C1-O04: §7 retractable-root attack; §10 custody publication and W8 review | **Closed as the missing-rule/review request, by D36 with D32/D63's C4 consumer.** C2-R13/R15 gate checkpoint publication, C2-R14 supplies the published-boundary restart argument, and C4-R12 preserves published custody/caches. D36 records B's approval at `fb6180a` (5946014251), closing the W12 findings, and J's regression sweep. **Assumed residual, A (C2/C6):** leaf soundness, single-proof/CONFLICT assumptions and L-PF remain as specified, with unsigned limitations routed through D50; neither this disposition nor map versioning revokes an already executed Bridge effect. |
| C1-O05: §7 growth attack; §9 permanent-state costs/tariff; §10 S3/C6 | **Open user disposition, A for the D50 completion list, B (C1/C6) and A (S3) for its technical statement.** C1-R05/R08/R10 specify nonpayable calls and permanent membership without rent or pruning; §7 bounds writes per distinct origin, not lifetime state. A recorded user acceptance of that growth/economic limitation, or a separately accepted policy revision and corresponding interfaces/forced funding, closes the product question. No such signature is inferred from D28/D63. A tariff on ordinary pins alone would omit system pins and direct reveals. |
| C1-O06: V10 and §10 S2 identity | **Closed direction, partly closed byte fixtures:** D28 resolves P-B-C1-01 through S2-R03's identity, D16/D21 and C8-R16's preimage table; D49 accepts C8-V02's PH hash and C8-V09's logical opening vector. **Open, A (C2/C8) and the S2 owner/reviewers:** complete certificate/committee/envelope fixtures and guest reconstruction distinguishing sibling envelopes and interchangeable quorum witnesses. Neither D28 nor D49 merges S2 or supplies D1. |
| C1-O07: §8 unmeasured block and §10 C6 index | **Partly closed procedure dependencies under D69:** [MP-13](C6-measurement-plan.md#mp-13-l1-state-gas) and [MP-14](C6-measurement-plan.md#mp-14-focil-leg-bytes) supply selected-fork write-cost and wrapped-reveal measurement procedures, and [MP-19](C6-measurement-plan.md#mp-19-predicate-evaluation-cost-per-block) supplies a scoped component-cost default/procedure; none has run. MP-04 quotes the landing calldata cap and does not bound the forced reveal manifest. **Open, B (C1) with A (C3/C8/C6 measurement) and B (C6 index):** C1-specific conservative defaults/procedures and exact fixtures for oracle/parser cost, ordinary/system pin and reveal cost, EVM/zk fit, funding, parity and state growth. The accepted plan's §11 expressly excludes C1's owner rows, so D69 does not discharge them. C1-O01/O03 retain their behavioral and encoding obligations; actual implementation benchmark results are later evidence. |
| C1-O08: §8 conformance suite; §9 utility-parity limit | **Open specification artifacts, B (C1/C4) with A (C2/C8).** Provide complete authenticated selected-fork header fixtures and expected state/root transitions for the listed first-block, guard, parser, pin/reveal and reorg cases; synthetic parser V11 is insufficient. Future implementation must run those fixtures against builder/importer/guest and the actual installation. No implementation or live audit is claimed here. |
| C1-O09: §9 future storage policy/pruning | **Closed as a current-scope question under D28's acceptance of C1-R05/R10:** no pruning or per-record administrator repair exists. A hypothetical changed retention policy needs a new proposal and decision; W15 creates none. The actual permanent-growth limitation remains C1-O05's unsigned user item rather than being closed by excluding future features. |
| C1-O10: §10 C2 selected-header profile and metadata/full-header vectors | **Open, A (C2/C5/C8) with B (C1).** Jointly fix the supported Ethereum header profile within P-HEADER-BYTES/P-HEADER-FIELDS, bind the same profile in the proof guest, and supply complete accepted and rejected header/envelope vectors. D36 accepts C2's origin-authentication rule, not this missing joint profile evidence. |
| C1-O11: §10 C2/C4/C8 floors and recovery composition | **Closed rule composition under D28/D32/D36/D63:** C1-R06/R10, C2-R14/R15/R21 and C4-R12 preserve the published boundary and epoch lookup semantics. **Closed physical floor representation under D49:** C8-R15 and C8-V12 define the element layout and slot vectors. **Open, A (C8/C2) with B (C4/C1):** access budget, migration manifest/packing and rollback reference fixtures, and bootstrap/restart identity integration with S2. A compiled-layout comparison belongs to the later implementation gate; exact specification storage slots and codecs remain D44 work. |
| C1-O12: §10 proof/finality-review marker | **Closed under D36**, as scoped in C1-O04. The old request for W8 re-review is historical; no new review is fabricated, and a later changed owner rule still requires its own review. |
| C1-O13: R1 former retained DAO powers | **Closed by the user's D26, implemented in specification by C4-R10 and accepted under D32:** Anchor withdrawal, resolver registration and token owner mint/burn are removed; D30 additionally rejects Bridge plain-Ether receipts uniformly. Complete manifest coverage remains C1-O02. Arbitrary future upgrades stay the stated governance premise, not a retained daily operational power. |
| C1-O14: R2 live audit and publication rules | **Closed rule requests under D28/D32/D36:** retained addresses and logical layout/selector continuity are C1-R10/C4-R09 to R11; publication is C2-R13/R15. **Open, B (C4) with A (C8):** exact specification manifest/layout fixtures per C1-O02/O11. Authentication of a real deployment remains A-HISTORY/A-MANIFEST and a later installation gate. |
| C1-O15: §10 C7/C8 composition and remaining R4 capacity | **Partly accepted under D62/D63:** C7 consumes C1's execution component and C1 consumes the hatch system-pin rule. **Open, A (C7/C8) with B (C1) and the S2 owner/reviewers:** complete the mode/encoding/interface vectors and C1-O01; D62 explicitly carries genesis/restart and encoding obligations. S2 confirmation and execution/proving capacity remain open and unmeasured with S2/S4/C6; removing Anchor does not establish one-second service. |
