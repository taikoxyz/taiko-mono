# Exact source correspondence at source360

This review freezes `SPEC.md`, `ACCEPTANCE.md` and `SWITCH.md` at
`3602629758beb653423a23608fd1960810efcfac` (source360). It admits exactly these
three original byte streams as source-review metadata. `SOURCE_REVIEWED` means
recognition of reviewed documents; it establishes no execution, proof validity,
imported history, checkpoint trust or deployment readiness. Selection by revision
is metadata selection and does not authenticate an actual workspace.

| Document | Bytes | Git blob | SHA-256 |
| --- | ---: | --- | --- |
| SPEC.md | 284625 | `0b7f70096dc6250861a01209f30be7d23a7e234b` | `383760a1e7df211a9c74835a4e2446db57a05bd21eb52f030980afd205748d3c` |
| ACCEPTANCE.md | 60050 | `95d9569fc0954b9ba97abbddfe184c197811827a` | `7283c47bec643d3054a41ec3266ead387431b82ae3caa4102c4866dfc8b39a7b` |
| SWITCH.md | 25483 | `b8ff8e16b9b19614f6f8a572cda13c0192f5b2d8` | `a1652de6d0f57eae119bb26f6a5c63bab83f8dead41e6ad81021709a133d30d4` |

The manifest retains the four older bundles unchanged. Removing source360 yields
canonical JSON SHA-256
`d7a4dbf50cd5de37c7d8b27d0e60dbf6f993c9dff65d84841b89e5a2ebbe5bfc`.
The complete claim inventory remains
`d127d53a73905b701d950d75c1021433f05de6c6dfc3e21a0b96394ab79ef958`.
Product qualification remains `2e6763e21bc236cfcda6011d164b32040f9e0c8d`.
The f556 source-only scope remains independently selectable with its original
11 obligations; its canonical scope SHA-256 is
`40baba560d022244f57a6d034a117ca78662da8e34cf0ee07baae5738c82e2ee`.
Source360 has a separate 14-obligation ledger. Every obligation is `WAITING`,
execution is `NOT_EVALUATED`, and evidence is null in both scopes. Neither scope
inherits a product claim. Old implementation, model, configuration and evidence
pins remain unchanged.

## Disposition vocabulary

**Historical** preserves the exact old consumer, sources, premises and outcome.
**Unaffected within premises** describes a narrower relation that remains useful;
it grants no new execution attribution. **Superseded** identifies a changed
requirement for which an old projection cannot be cited as current conformance.
**Waiting** names the actual implementation or measurement still required.
Limitations and assumptions remain limitations and assumptions, even when cited
by a waiting acceptance obligation.

The following is the changed-clause review from f556 to source360. Rule IDs refer
to the frozen source360 SPEC. ACCEPTANCE and SWITCH references identify their
sections/items directly; those documents do not introduce independent rule IDs.
Formatting-only table alignment and unchanged surrounding rules need no new
behavioral claim.

| Changed source and direct rules | Current requirement and affected consumer disposition | Next acceptance step / source360 obligation |
| --- | --- | --- |
| SPEC §3.1 `CONS-3.1-1`, `CONS-3.1-2`; §5.4 `DATA-5.4-5` | Official upstream consensus executable; stopped offline store tooling may link the pinned module, fence signing, durably stage aligned Comet/app/EL and publish before startup. Old seen-commit/bootstrap/native tests are historical component observations. | Actual complete import and certified first-block repair with retained originals and aligned publication: Y06, STOCK_DEPLOYMENT; ACCEPTANCE §2.4, §7.6. |
| §3.1 `CONS-3.1-9` | Reconcile committed EL lag before stock handshake, independently of Info/callbacks; missing material keeps signing fenced while the node reports the missing height and retries acquisition outside the handshake; contradiction stops startup. Old app-crash and native handshake projections are superseded as evidence for this supervisor path. | Crash each boundary, withhold then restore inputs and verify identical committed hashes: STOCK_DEPLOYMENT, SIGNER_SESSION; ACCEPTANCE §2.4. |
| §3.1 `CONS-3.1-10`; §10 `START-10-21`; §12 `LIMIT-12-22` | Stock evidence remains unbounded in a running halt. Clear only pending-evidence stores at every stopped startup; age limits become 16 blocks/3 minutes. Neither peer lists nor startup clearing proves a running-halt bound. Old stock evidence operations stay historical. | Measure all enabled inputs, memory/disk/work/relay growth, alerts, retained signed pair, full slash, peer attribution and coordinated restart: Y07, RESOURCES; ACCEPTANCE §4 evidence pool, §7.5. |
| §3.1–3.2 `CONS-3.1-11`, `CONS-3.2-8`, `CONS-3.2-9`; Appendix A `ENC-A-10a`, `ENC-A-10b` | New-network (S=0) block 1 has a fixed 0.025 gwei base fee (25,000,000 wei). Every other block uses the exact EIP-4396 formula with the 4-second target; switching (S>0) S+1 uses its Unzen parent and grandparent. Independently, mixHash has two static ABI words. Existing fee discussions or host checks supply no actual EL/guest agreement. | Separate fixed new-network block-1 and switching S+1 vectors, later adjustment vectors and independent mixHash vectors against pinned EL/guest execution: ENCODINGS; ACCEPTANCE §3. |
| §3.3 `CONS-3.3-4`, `CONS-3.3-5`; §8 `RECOV-8-5` | Proposer may retain parent anchor while age permits; ProcessProposal immediately rejects a not-yet-locally-finalized anchor, but FinalizeBlock waits/retries a decided block. Generic missing-finality models are unaffected only within their stated abstractions. | Independent app traces for behind views, decided blocks and contradictions; measure rounds with/without anchor delay: CHECKPOINT_TRUST; ACCEPTANCE §3, §7.9. |
| §3.4 `CONS-3.4-16`; §8 `RECOV-8-14`, `RECOV-8-15`; §9 `SYNC-9-6a` | An ahead finalized checkpoint closes signing until matched; available EL mismatch revokes trust without waiting for slot285. A larger generation revokes even with unchanged c, no proposal and no reconnect. Old anchor-triggered trust projections are superseded for continuous monitoring. | No-proposal/no-reconnect tests, catch-up, immediate EL mismatch and larger-generation rejection: CHECKPOINT_TRUST; ACCEPTANCE §2.4, §7.9. |
| §4.1 `STAKE-4.1-33`, `STAKE-4.1-34`; Appendix A `ENC-A-49` | Recovered nonzero equal vote addresses must resolve permanently to the specified bond; slashDoubleSign does not decompress the key again. Historical registry replay remains tied to its old implementation. | Actual current ABI, lifetime address map, foreign-key rejection and withdrawn-bond cases: Y04; ACCEPTANCE §3. |
| §4.3 `COMM-4.3-10`, `COMM-4.3-13`; §6.2 `PROOF-6.2-32` | At selection height S(t)=H(t)-2, updates differ from the set signing S(t)+1=H(t)-1, not the initial committee at fixed start S+1; selected record and snapshot activate at H(t) even with unchanged keys/powers and empty updates. No extra intermediate commit is implied. Old set-delay/validator-state operations are historical; Z04 does not implement this full app/guest path. | Both guest statements immediately before/at activation and actual FinalizeBlock updates, including a second rotation after membership changed: Y03, Y05; ACCEPTANCE §2.2. |
| §5.2 `DATA-5.2-1`–`DATA-5.2-6`; Appendix A `ENC-A-23` | Nested executionBlock is encoded once as an RLP list; transactions remain byte strings; each encoded block is at most 124,000 bytes, with complete canonical RLP and bounded one-stream zlib decoding. Different valid compressed streams of identical canonical RLP are accepted. Old envelope/proof mock vectors do not implement this codec. | Actual shared guest/EL decoder acceptance/rejection, trailers/dictionaries/size boundaries and alternate compression: ENCODINGS; ACCEPTANCE §3. |
| Appendix A `ENC-A-23a`–`ENC-A-23d` | Exact Unzen version0 packing: 130,044 payload bytes, low-six-bit field-element headers, top two header bits zero, version/length/zero-padding checks. Ordinary Unzen decoding alone can miss a first-header padding rejection. | Run fixed valid and invalid blobs through every actual EL/guest decoder: ENCODINGS; ACCEPTANCE §3. |
| §5.3 `DATA-5.3-8`; §6.1 reference Solidity after `LAND-6.1-10`–`LAND-6.1-13` | Import trust cross-reference now requires SYNC-9-5. Sketch names committeeConfigHash slot269 and verifier/maxBatchBlocks immutables, removes misleading mutable genesisHeight/startStateRoot locals. Existing storage pins are historical; Appendix B remains layout authority. | Concrete current layout vectors and complete importer trust admission: Y05, Y06, CHECKPOINT_TRUST. |
| §6.2 `PROOF-6.2-17`, `PROOF-6.2-18` | One-round type2 precommits for one full BlockID, correct own timestamps, recomputed chain_id and strict >2/3 distinct power. Prevotes, mixed rounds, nil or wrong block do not count; a valid other-round commit can serve independently of successor LastCommitRound. Old stock public-vote tests are unaffected only for their stock API premises. | Real guest rejects each wrong certificate and accepts a valid independent-round commit: Y03, ENCODINGS; ACCEPTANCE §3. |
| §6.3 `BATCH-6.3-5`, `BATCH-6.3-7` | Recovery initial committee R remains outside settled-selection exception until its last signed block settles; exceeding reference ancestry bounds there requires another recovery. Earlier finite progress projections are conditional, not an unbounded proof. | Actual guest ancestry boundary, prolonged pause and recovery drill: Y03; ACCEPTANCE §1.4, §2. |
| §8 `RECOV-8-29`, `RECOV-8-32`, `RECOV-8-35` | Already withdrawn bonds are not made slashable by verifier-failure rollback; accepted unbonded voting-power interval remains until settlement, with no generation change solely for that bond. Historical funded forfeiture does not eliminate the gap. | Current rollback/withdrawal ordering and operations acknowledgement of the limitation: Y04. |
| §8 `RECOV-8-39`; §10 `START-10-14`, `START-10-18` | Positive bytecode capacity F<=4096; K=min(4096,floor(10^27/minStake)); initialization rejects K>F. Full DAO/Inbox/Registry recovery for all 0..F candidate exclusions and zero/one FI must fit both L1 gas limits before refunds. n_max-only tests are insufficient. | Publish F/K/minStake and complete conservative bounds, K=F/F+1, adverse distributions, redo on code/supply/gas changes: Y02, RESOURCES; ACCEPTANCE §2.1. |
| §8.2 `RECOV-8.2-2`; §10 `START-10.1-14b`; §12 `LIMIT-12-2` | Authenticated Comet endpoint/session/store binding and retained WAL prefix; stock 1GiB trimming can erase the bound marker. Planned undecided-height upgrade must serialize at persisted precommit, and upgraded replay confirms it before fresh signing. Z01/frozen crash models do not prove this new implementation path. | Both transports, WAL-loss floor, stop requested after nil prevote, precommit admission/replay and conflict refusal: Y01, SIGNER_SESSION, STOCK_DEPLOYMENT; ACCEPTANCE §2.4, §6. |
| §8.4 `RECOV-8.4-14a`; §9 `SYNC-9-4`, `SYNC-9-5` | Session starts untrusted; current-generation origin compares EL only because old-generation Comet hash at c need not exist in new history. After first landing compare both hashes. Old trust models demanding an origin Comet block are superseded. | New committee without old consensus history obtains trust and signs first block, then dual-hash comparisons: CHECKPOINT_TRUST; ACCEPTANCE §2.2. |
| §9 `SYNC-9-4`, `SYNC-9-6a`, `SYNC-9-10`–`SYNC-9-13`; §10 `START-10-6` | Every authenticated connection is a session; disconnect ends signing/replay admission, reconnect rechecks without losing HRS/floor. All proposals/votes/nil/retries/retained requests require current session, full domain and next durable app height before HRS mutation. Explicit errors and supervisor restart remain required on deadline. | Wrong peer/session/domain/height and non-one initial/imported heights, timeout/reconnect, trust-return restart: SIGNER_SESSION; ACCEPTANCE §2.4, §3, §7.9. |
| §9 `SYNC-9-6a`, `SYNC-9-7` | Known pending target survives failed reads; pending status is untrusted. Retry slot285 at pinned finalized L1 block, restore only on complete latest-known match and still-current generation; last result persists only without pending/contradiction. At/below matched checkpoint no new Comet comparison is needed, including a below-import anchor. Startup contradiction halts; running contradiction revokes. | Immediate EL mismatch before285, prompt and timed-out matches, pinned retries, public status, stale reads and below-window anchor cases: CHECKPOINT_TRUST; ACCEPTANCE §7.6, §7.9. |
| §9.1 `SYNC-9.1-7`, `SYNC-9.1-9`; §12 `LIMIT-12-3` | Reporter responsibility is independent of pool age; stock has no conflicting-vote/pending-evidence query/event, and a nonvalidator does not form evidence. A collector is required, not supplied by this source review. | Actual independent vote collection and submission: Y07; ACCEPTANCE §4, §7.5. |
| §10 `START-10-3`, `START-10-5`, `START-10-5d`; §9 `SYNC-9-5a`; §11 `PARAM-11-12a`, `PARAM-11-12b` | L1 usesBeaconRoots=false, L2=true; no L2 fork-time contract. EIP-4788 prerequisites precede readiness upgrade. Two proposals separate proven finalized L2 readiness from L1 scheduling. Node config including local overrides is checked against L1 Inbox immutable. Z06 origin.py and Z07 replacement.py old timestamp getter assumptions are superseded. | Canonical code/zero-own-root precondition and installed implementation-slot proof; both layouts remain provable while unscheduled: SWITCH; ACCEPTANCE §8.3. |
| §10 `START-10-5`, `START-10-5b`; §9 `SYNC-9-5a`; ANCHORLESS §4/§8; ACCEPTANCE §8.5 | D01 current acceptance uses shared SignalService source/layout with usesBeaconRoots=false on L1 and true on L2. Resolve a saved checkpoint first; only when absent consult EIP-4788, rejecting an unresolved zero root or call/missing/wrong-return error while accepting valid saved checkpoints even after EIP-4788 expiry. Unzen forwarding accepts only its configured caller and rejects EVERY height once start slot273 is nonzero. Implementation authentication at S is distinct from every-target node actual fork-time/local-override comparison against the finalized L1 Inbox immutable; there is no L2 fork-time getter. The old9c D01 instructions are archival. | Actual node/guest and contract tests for roots present in each source, both absent, wrong L1 flag, forwarded heights below/at/above S after start, and late/pruned joins with correct/wrong local fork time; retain namespace/min-width/cache/dual-guest migration checks: SWITCH, CHECKPOINT_TRUST, D01. |
| §10 `START-10-5d`; SWITCH §7 | Schedule postponement is one L1 atomic batch, expected old schedule/unwritten start/new lead/strict inclusion<B, preserving complete Unzen proof coverage through extended interval and updating verifier images/trust together. Former L2 replacement, ack and A/E deadlines are removed. Z07 replacement.py is historical f556 only. | Before/exactly-at/after-B runs, stale/lead/start failures, prove outstanding and post-old-fork Unzen blocks, first Etna landing, no second L2 message: SWITCH; ACCEPTANCE §8.3. |
| §10 `START-10-6`; §12 `LIMIT-12-2` | Local unix socket under controlled directory or stock noise mutual peer pins on every connection; refuse bare tcp. Validators list all peers, disable pex, set inbound0 and listed unconditional IDs; sentries forward only accepted messages. Faulty listed peers can still exhaust WAL or evidence resources. | Wrong-peer/transport refusal, sentry filtration and actual admission configuration: STOCK_DEPLOYMENT, SIGNER_SESSION; ACCEPTANCE §2.4. |
| §10 `START-10-8` | Initializer requires genesisCutoff<block.number on both deployment paths, so stored snapshot precedes start-write block. Old positive-width snapshot API is not initializer evidence. | Current deployment initializers reject equal/future cutoff and retain actual shared snapshot: Y05. |
| §10 `START-10-21`; ACCEPTANCE §1.1 | block.max_bytes=1572864+4096*n_max, 2097152 at n_max128, leaving >1.5MB envelope after stock header/LastCommit allowance; max_gas=-1 and block evidence bytes=0. Old max_bytes1048576 fixture is historical. | Largest legal envelope under actual pinned Comet and n_max, without dropping mandatory data: Y07, RESOURCES. |
| §10 `START-10.1-3d`; ACCEPTANCE §3 | Interoperable official patch that changes no listed bound behavior is not ruleset/structural upgrade; source/artifact/digest manifest and repeated stock comparisons are still required. Cited stock behavior changes require rule revisions. | Fresh pinned stock comparison for every release/build change: STOCK_DEPLOYMENT. |
| Appendix A `ENC-A-5`, `ENC-A-37`, `ENC-A-38`, `ENC-A-39`, `ENC-A-39a`, `ENC-A-42` | All domain tags are static bytes32; selected set is one keccak of complete ABI SetMember array, not a Merkle setRoot; committee record uses setHash. Existing Registry leaf/snapshot set-key helpers already use static tags and remain unaffected within those narrow formulas. Z04 does not implement selected-setHash. | Fixed hex vectors including dynamic-tag rejection, array offset/length/member words/order and committee record: Y05, ENCODINGS; ACCEPTANCE §3. |
| Appendix A `ENC-A-29a` | Each one-height proposer-priority increment first rescales if needed, then always floor-centers even without changes/rescale. Old committee/proposer observations remain historical. | Compare exact pinned stock arithmetic at negative sums, no-update increments and rescale edges: Y05, STOCK_DEPLOYMENT. |
| ACCEPTANCE §1.3; Appendix C `COST-C-9`–`COST-C-12` | Incompressible full blocks allow <=6 per landing, needing about24s landing cadence at4s production; net backlog reduction is separate from20min target. Cost/operating assumptions are not runtime validity proofs. | Sustained measured production/settlement and induced-outage backlog recovery, funded operating capacity: RESOURCES. |
| ACCEPTANCE §4 archive; §2.5; §12 `LIMIT-12-2` | Second independent operator must restore expired-blob evidence with primary offline, complete ordinary recovery and land first new batch. Historical imports and19 archived INCONCLUSIVE searches do not discharge it. | Actual independent archive/proof/landing drill: PUBLIC_HISTORY. |
| SWITCH §1–§4, §6, §8; ACCEPTANCE §8.3–§8.7 | Readiness has no fork/deadline; queued message or receipt is insufficient. Scheduling checks L1 flag and times atomically. FI margin includes the proposer/preconfirmer stopped interval. Old saved checkpoints and new EIP-4788 roots both remain usable, missing both rejects. Unzen whitelist can gate final proof; SGX instance validity must cover first proof. | Complete two-proposal switch and bridge rehearsal, NEW/RETRIABLE bridge status, missing code/engine writes, finalized readiness proof, forwarding closure, permissionless origin and verifier/instance continuity: SWITCH, RESOURCES. |

## Complete existing consumer disposition

The claim inventory is preserved byte-for-byte in canonical contents; the table
below covers every existing named consumer and its entire claim group. None is
silently reassigned to source360. Selection always reports `NOT_EVALUATED`.

| Consumer and claims | Disposition at source360 | Required next evidence |
| --- | --- | --- |
| comet-signed / public-votes | Historical pinned stock public operations; useful only within original vote-shape/threshold premises. | Y03 / ENCODINGS for full current guest commit admission. |
| comet-filepv / persistence, handler | Historical old pinned disk/handler operations. | SIGNER_SESSION and STOCK_DEPLOYMENT for actual session, domain, durable height and supervisor behavior. |
| registry-cases / double-sign, lifecycle, displacement, atomicity | Historical old contract source, manifests and scenario pins unchanged. | Y04/Y05 for current ABI, lifetime lookup, snapshots and gas. |
| historical-models / registry-model, landing-model, recovery-model, schedule-model, trust-and-import-model | Historical exact finite transition systems/configs. | Respective Y01–Y07; source recognition cannot expand bounds or premises. |
| historical-conformance / registry-vectors, grid-replays, recovery-replays, rules-replay, checkpoint-import, stock-consensus | Historical exact original source and input/evidence pins. | Current concrete consumer and shared vectors under the new direct rules. |
| registry-vacancy-model / lowest-empty-slot; registry-supply-model / bounded-recycling | Product2e676 qualification only; positional occupancy/recycling reasoning remains useful within that model. | Y04/Y05 current registry implementation, F/K and selected-set commitment. |
| comet-validator-state / stock-app-hash; comet-signer-transport / cached-replies | Selected public operations at product2e676 only. | Actual current app/EL/signer integration, empty-update activation and session controls. |
| proof-progress-model / arbitrary-height-landing; rules-schedule-model / timestamp-stop | Product2e676 finite models only. | Y01/Y03 current guest/rules integration and resource/ancestry limits. |
| current-implementation / registry, inbox-and-guests, app-and-import, recovery-audit, schedule-and-images, switch, resources-and-operations | Existing waiting claims remain bound to product2e676; no current execution result. | Separate source360 Y01–Y07 and operational obligations. |
| boundary-products / timestamp-projection, repeated-recovery, mixed-rule-landing, funded-forfeiture, registry-origin-selection, terminal-seen-commit, evidence-lifecycle | Fixed product2e676 only. Full terminal-seen-commit/Y06 CLI intentionally refuses source360 via reviewed_boundary; a separately supplied exact product workspace can test that historical component. | Current source360 runtime integration remains WAITING even after a historical component succeeds. |
| Z01–Z07 / current_rules governance, forfeiture, recovery, snapshot, final_snapshot, origin, replacement | Frozen f556 projections. Source identity still requires exact f556 three-document input. Changed precommit, trust, encoding and switch rules supersede corresponding current attribution, especially origin.py and replacement.py. | Source-derived implementation obligations; do not repin these projections to source360. |
|19 archived searches | INCONCLUSIVE at their original model/config identities. | Fresh complete searches or independently accepted reduction; no status transfer here. |

## Admission and verification boundary

`classify_workspace_documents` enforces exactly the three raw bytes objects at its
inner boundary, against the separately pinned complete bundle inventory. It
rejects unknown, modified, missing, extra and cross-revision inputs. Claim
selection independently pins the complete claim inventory and refuses every
nonhistorical product claim for source360 or f556. Historical receipt selection
retains the exact original spec/implementation/manifest/input/test-source pins.
The historical single-SPEC correspondence checker continues to refuse source360;
three-document admission does not extend that older evidence contract.

`select_source_revision` explicitly enumerates f556 and source360, pins the exact
ledger bytes, rejects duplicate keys, and validates every scope and nonempty
unique waiting obligation before returning either scope. Recomputing a file pin
alone cannot promote execution/status/evidence, omit a scope or empty its
obligations. Rule references in source360's14 rows directly identify the still
unverified frozen SPEC clauses; they are not claims that the code executes them.

Regression checks run on actual source360 effective documents and a separate
f556 context. Genuine cross-bundle negative controls use both retained raw
bundles in an offline disposable namespace. This avoids substituting a synthetic
fixture for a cryptographic document identity. No TLC/native run, measurement,
key operation or external state change is implied by ordinary Python checks.
