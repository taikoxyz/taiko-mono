# M08-A: recovery lists and the public atomic transaction

`EtnaRecoveryTransaction.tla` extends the unchanged `EtnaSettlement` module and
calls its actual authorization, time, nonce, proof preparation, landing and
recovery actions through wrappers. `Recover` runs only at successful commit;
there is no raw base `Next` branch bypassing the transaction projection.

Authority: Etna SPEC `d18357214fab30ea512ae9858a11699806d72ba1`,
RECOV-8-37a..50 and 8.3-1..19, STAKE-4.1-13a and appendix B. Main at the refreshed
pin has the same SPEC content. This is a bounded public-transition model, not a
proof of the whole protocol, EVM execution or production implementation.

## Checked boundary and private workspace

One attempt captures the original supplied exclusion/FI sequences, authorization
arguments and execution context. The input fixture generators are outside `Begin`;
operational and observation records independently copy its raw arguments. The
request/context remain immutable throughout validation, tentative work and completion.

The model logically checks exclusion order/issued identity/key and FI order/range,
then stages force-exits, FI blanking and origin/schedule effects in a private
workspace. Canonical state stays equal to an independently captured pre-call
projection until commit or abort. A second-exclusion dependency failure occurs
after a real tentative first-bond exit change in the held fixture. Abort compares
the complete modeled canonical before/after values, not just a success flag or
selected balance. Commit uses actual base `Recover` and checks all modeled writes
against an independent transformation of the original request and raw pre-state.

A nested registry-mutation attempt has an explicit returned acceptance and actual
workspace before/after observation. Correct rejection changes no workspace state.
The dependency may catch that rejection and let the outer recovery succeed. This
is one abstract blocked mutation class, not concrete coverage of every reentrant
Inbox/registry API, caller role or callback path.

The pinned implementation at contract revision
`89f419915de4b73bb57c53bf970f6dea9e8e8c8c` uses a different private order:
`EtnaInbox.recover` checks ordering/FI bounds, then each `forceExit` checks its
issued id and key while applying exclusions. A later failure reverts earlier
writes. This was independently inspected in `EtnaInbox._checkRecoveryLists` and
`EtnaStakingRegistry.forceExit/_issuedBond`. The model's logical prevalidation
matches the public acceptance/revert and atomic effect boundary; **its internal
steps are not instruction-order or microstep refinement of those contracts**.
Different revert-selector precedence is not a protocol discrepancy here.

## Canonical projection and independent expectations

| Projection        | Modeled fields                                                                                                                                      |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base public state | Checkpoint, generation, current recovery nonce, fixed start and retained landing metadata                                                           |
| Registry          | Issued/withdrawn identity, key/owner, effective/pending/ready, exit/confirmation, slot flags/maps, lifetime key/forfeiture flags, principal custody |
| FI                | Head/tail, hashes, enqueue timestamps/blocks and admission fee balance                                                                              |
| Other Inbox state | Per-generation origin, active snapshot, active/next rule/time and stop time/grid                                                                    |

“Complete canonical” means all fields in this selected model projection. It does
not mean every Solidity slot, account balance or log is represented. Caller gas,
block metadata, proof internals, EL/Comet/validator hashes and external dependency
storage are excluded. Offchain authorizations/pending proof caches are separate
base-model state, not fictional onchain authorization storage.

The independent oracle requires strict increasing ids and indices, permanent
issued identity and matching key, and FI indices in the **execution-time**
`[head,tail)`. A genuine unissued default record has zero values and its own
`DefaultKey` token; the missing-issued control supplies that matching default key
so another accidental key mismatch cannot make the control vacuous.

Successful effects are exactly: exits `min(old,R)` for selected ids; only selected
FI hashes become empty; current nonce/generation increment once; exact c/R/time
origin; stop fields clear. Checkpoint/landing records, FI head/tail, principal,
queue timestamps/blocks/fees, confirmations, lifetime flags and active snapshot
remain unchanged. With `rules=0`, the rule schedule is carried forward.

## Finite source-valid fixtures and workload

Bounds: L2 grid points 0..2, generation 0..1, nonce 0..2 and normalized time 0..1.
L1 execution block is `100+time`, timestamp is `1000+time`; these are distinct from
L2 heights. Valid-until uses the same timestamp offset. The no-exit sentinel is
10000 in this finite model. Real implementations use their actual packed sentinel.

All scenarios execute one abstract valid landing to checkpoint 1 (FI head 1), then
an authorization with deadline 1. Before entry, all selected base wrappers remain
available: another landing, fresh authorization, proof preparation, invalidation
and time can create changed-state/stale arguments. Entry is not offered at an
exhausted model-only generation/nonce bound, avoiding a false exported protocol
rejection caused solely by a finite-state cap.

After entry the transaction context is fixed, as for one serialized L1 transaction.
`Done` ends this **single public attempt per run** workload; it is not a protocol
rule preventing later recovery, registry calls or new-generation landing. The
model does not explore arbitrary sequences of completed recoveries.

| Profile                 | Registry fixture                                                                                                                                  |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `recovery-tx-held`      | Two slots/two holders; first tentative force-exit changes a no-exit bond before a possible second dependency failure                              |
| `recovery-tx-displaced` | One-slot projection; bond 0 is issued, unheld, still funded/confirmed; replacement bond 1 holds the slot                                          |
| `recovery-tx-withdrawn` | Same one-slot projection; bond 0 has withdrawn, keeps its issued/key/lifetime identity and accepts exclusion without touching replacement custody |

These are prepared, normalized registry histories, not registration executions in
this module or proof that all deployed slot/amount settings map automatically.
Stake lifecycle reachability is an imported interface. Id/slot 0 remain valid
through presence flags. Two issued identities plus a zero/default unissued id and
two queued entries plus a future invalid index form the finite domains.

The request workload is a declared curated vector family: empty/mixed/unheld,
duplicate ids, late wrong key/unissued id, future/consumed FI index and duplicate
FI indices. It is not the Cartesian set of all possible lists, permutations,
lengths or arbitrary keys. K is fixed to 1 and only rules 0 is offered; structural
K changes, other rules and integer overflow are deferred. No assumption that
capturing R proves the actual end-of-R registry snapshot/committee/genesis is made.
M02/M03/M04 handle related interfaces separately, not as a composed proof here.

## Completed-attempt interface for C03

`PublicAttempt` is a version-1 record available once the attempt completes:

| Field                          | Interpretation                                                                                                              |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| `schemaVersion`, `present`     | Schema/availability, never a skipped-as-passed marker                                                                       |
| `calldata`                     | Original expected generation/C/nonce, timestamp valid-until, ordered `(bondId, entryKey)` sequence, FI sequence and rules 0 |
| `execution`                    | L1 block number and timestamp fixed at entry                                                                                |
| `injection`                    | Separate test metadata: dependency failure or callback class; not Solidity calldata                                         |
| `outcome.accepted`             | Public call succeeds or reverts                                                                                             |
| `before`, `after`              | Actual complete modeled canonical projection at call boundaries                                                             |
| `outcome.reason`, `nestedCall` | Model diagnostics; not Solidity error selectors or intermediate onchain states                                              |

Internal validation/apply transitions collapse to **one** real `recover` call.
Callback workspace diagnostics must not be replayed as public intermediate
contract states. In particular a real late invalid id can make earlier registry
calls before reverting, whereas the model rejects during logical prevalidation.

`SecondRegistry` injects a failure at the second requested exclusion-processing
operation. It is a modeled dependency outcome, not an extra deployed API or a
claim that every implementation makes the same number of EVM CALLs. The adapter
must identify the corresponding concrete call/target, label injected dependency
behavior, and record unsupported injection as a GAP rather than invent a match.

C03 must pin this module, base and configuration hashes, export actual model
execution/receipt values, and compare a declared real-code projection. Authorized
owner, initialized Inbox and written start are premises. Logical L2 grid points
map through the contract grid (currently 6); FI indices, registry L1 exits, L1
block/timestamp and nonces are **not** multiplied by that grid. Symbolic keys,
owner/address roles, slot/amount normalizations and the sentinel require explicit
mapping. Real getters may additionally check opaque record fields unchanged;
those checks must not be represented as if this scalar model proved the values.
No adapter implementation or code conformance PASS is supplied by this module.

## Evidence and limitations

Three normal profiles check the original request, no intermediate canonical
publication, independently derived acceptance, full abort equality, exact success
effects and rejected nested mutation. Nine controls remove order/issued/key/range
checks, leak tentative abort state, accept a nested mutation, advance the snapshot
or corrupt the fixed origin. Six witness searches cover mixed success at inclusive
positive expiry, unheld and withdrawn ids, a valid first/invalid later exclusion,
a dependency failure after tentative work, and caught callback rejection with outer
success. Fault controls are model-sensitivity evidence, not protocol findings.

The workspace is a specification-level transaction abstraction, not an EVM rollback
interpreter, reentrancy proof or literal bytecode execution. A callback is one
abstract mutation class. Authority, initialization, start validity, token behavior,
correct underlying landing proofs and packed-width safety are premises. Actual R
finalization/selection, signer shutdown after local authentication, rules upgrades,
bridge rollback, arbitrary workloads and actual-code conformance remain outside
this slice. No liveness/fairness or unconditional completion guarantee is asserted.

## Checked candidate

Module SHA-256: `4d33545dbeffa396b40864620788ab688ceb51c9d323d85b46acb29a75c046a2`. The implementer ran all 18 exact expected outcomes:
three normal queue-zero searches, nine deliberate fault controls and six boundary
witnesses. No timeout or input drift occurred.

| Normal profile          | Generated | Distinct | Final queue |
| ----------------------- | --------: | -------: | ----------: |
| `recovery-tx-displaced` |     3,700 |    3,242 |           0 |
| `recovery-tx-held`      |    10,420 |   10,010 |           0 |
| `recovery-tx-withdrawn` |     3,700 |    3,242 |           0 |

Independent review and the task owner’s actual-worktree/real-code results are
reported separately. These local model results do not establish C03 conformance.
