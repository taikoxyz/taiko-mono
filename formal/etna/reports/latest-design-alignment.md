# Latest Etna design alignment

Authority: main `1135c9b24fd03f50cb48eab250879435fd54f528`, including SPEC, ACCEPTANCE,
ANCHORLESS and SWITCH. These protocol documents are unchanged. This report concerns
conditional decoded-design safety and the review corrections to its model/evidence.
It does not certify production implementations, complete acceptance or launch readiness.

## Semantic contracts and boundaries

| Obligation              | Current evidence                                                                 | Precise boundary                                                                                                                                                                                                                                                                |
| ----------------------- | -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Reference identity      | Closed-prefix reference commitments and separation                               | A reference binds the complete supplied closed L1 prefix, including financial state. Hashing/authentication implementations remain primitive refinements. Changes after the fixed reference do not rewrite that prefix.                                                         |
| Retained funds custody  | Current custody and coherent retained-chain invariants                           | Signals and retained checkpoints share a parent chain. Accepted Unzen first-fence and implementation-check evidence are distinct from off-chain pre-fork origin duties. No unrelated node-trust obligation is inferred.                                                         |
| Lifecycle and rollback  | One-shot start write, post-landing start freeze, checkpoint-associated snapshots | Corrections do not reopen the start after a landing. Rollback truncates the retained chain and signals and restores the snapshot actually associated with its trusted checkpoint.                                                                                               |
| Economic accountability | Issued-bond history, atomic principal/payment accounting and evidence clock      | Election identities come from real issued bonds. Reserve backing and evidence-window retention are derived from initial state and actual lifecycle calls; raw signature/token refinements remain explicit.                                                                      |
| Chain agreement         | Own-archive committee derivation and round/codec binding                         | The exact agreement conclusion remains conditional on its declared honest-round/minority and primitive codec/signature assumptions. It does not prove liveness.                                                                                                                 |
| Forced inclusion        | Complete journal, timed byte actions, actual FIFO interval and nondue inclusion  | Inclusion authenticates the complete decoded payload's head. A skip must be due. Parser/body/EL/singleton execution is relative to the selected fixed interpreter; no production EIP-2718 or full-budget EL implementation is proved.                                           |
| FI admission            | Exact payment/refund, balance/revenue, append and failure contracts              | Positive configured fees, underpayment rejection, failed-refund rollback and exact byte/hash/time/block admission are exercised with nonzero fees. Event encoding and production ETH transfer execution remain separate.                                                        |
| Import publication      | Complete original-generation header-number interval and closed readiness         | The model installs numbers and closes readiness/trust while preserving HRS/log state. It does not represent the actual original EL headers, execution indexes or full stock stores required by SPEC 5.4. This remains an abstraction gap, not an implemented complete importer. |
| Rulesets and images     | Per-block selected definitions and actual-image certificate support              | A declared image must implement every ruleset in its complete decoded batch. Three-ruleset fixtures reject a missing middle definition. Backend/guest implementation refinement and availability remain explicit.                                                               |

Exact exported definitions and theorem types are the authority for the strength and
quantifiers of each result. The global accepting realization is now proved by
`Etna.Design.Current.Protocol.NonVacuity.accepting_deployment`: all 13 current Premises
hold together, with an actual registered/funded bond, nonzero FI admission and a reachable
accepted landing that advances the FI head. The full decoded Snapshot state-root encoding
is globally injective. `verifier_sound` covers every reachable accepting World; its
verifier accepts only image 11 and the two fixed certified statement templates. This is a
restricted new-network interpreter witness, not a switching-network or production
crypto/EL realization. Other finite fixtures do not replace that global proof or the final
kernel/type/axiom audit.

## Review disposition

The [per-finding disposition](current-review-corrections.md) records the critical,
important, earlier and minor feedback individually, with corrections and explicit limits.

The review identified substantive model/evidence gaps in reference binding, coherent
custody, economic provenance, due-qualified FI skips, admission accounting, complete payload
position zero, importer readiness/prefix range and proof-image ruleset support. The current
semantic layers expose these contracts rather than adding their conclusions to Premises.

Rule traceability now uses an explicit reviewed rule-to-theorem map. It no longer inherits
evidence from a whole paragraph or proof module. In particular, generic list-agreement
helpers do not cover stock CometBFT process/locking rules; future-slash existence does not
cover top-up/withdrawal policy; cursor arithmetic does not cover discarded zk trial work;
and the guest implementation fence does not prove node pre-fork operational duties.
Specific landing suffix/frontier obligations are mapped separately from unrelated landing
interface, nonpayable and evaluation-order requirements. Supporting raw guards are visible
without being counted as derived partial properties.

Two review suggestions do not indicate defects. `trace_fields_fit` needs no induction
hypothesis because each successful call validates all resulting fields. `scheduleRules`'s
48-bit sum guard is implied by its representable scheduled time and lower deadline; using
a 256-bit guard would leave successful behavior unchanged. Stop cancellation has a different
arithmetic condition and is tested separately.

The review correctly identified **251 inventoried clauses in the other three in-repository
authorities**. The earlier interpretation of this number as an unsupported external-spec
count was wrong. The inventory is 315 SPEC + 113 SWITCH + 93 ANCHORLESS + 45 ACCEPTANCE
clauses. No percentage of verification follows from those counts.

| Additional authority    | Current evidence                                                                                                                                                                                                                                  | Explicitly deferred scope                                                                                                                                                                                                                                                                       |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| SWITCH — 113 clauses    | Direct links only for the accepted decoded first-fence conditions, their matching authenticated Unzen root, the fixed guest implementation checker and the L1 accepting-root portion of lines 117–128. Each source edge states its narrow result. | PROPOSE_MARGIN/FI_MARGIN arithmetic (including lines 77–83), actual Unzen proposal processing, originWriter and honest-node operational checks, bridge/signal migration and the complete switch procedure. The primitive pre-fork Unzen-header condition does not prove the margin calculation. |
| ANCHORLESS — 93 clauses | All current clauses remain deferred. Historical anchorless results do not count as current evidence.                                                                                                                                              | Bridge root resolver and HopProof verification, EIP-4788 pre-execution writes/ring-buffer expiry, cached signals, storage VERSION namespaces, deployed contract code and upgrade/migration order.                                                                                               |
| ACCEPTANCE — 45 clauses | All current clauses remain deferred. Synthetic/model fixtures do not complete acceptance gates.                                                                                                                                                   | Actual guest/resource/latency/gas measurements, maximum committee/signer/HSM tests, production two-proof combinations, launch capital/concentration gates and full switch/recovery rehearsal.                                                                                                   |

Adopted zk-gas rules, CometBFT, Ethereum transaction formats and raw cryptographic/data-store
implementations remain additional refinement obligations. Import-range/readiness proofs
operate only on header numbers and flags; they do not model or install the actual header
contents, EL indexes and stock stores SPEC 5.4 requires. Historical reports and JSON vectors
describe their named baselines and carry explicit archival labels.

## Validation

Final review-correction validation with pinned Lean 4.35.0-rc4:

- `lake build` succeeds; source lint checks 204 Lean files and the import graph checks
  170 modules in five libraries, with no Model theorem exemption.
- `audit_proofs.py` passes all **1,625 exact contracts**, mechanical roles and fresh
  whole-import-closure kernel replay, including **34 Lean regression modules**. Only
  `propext`, `Classical.choice` and `Quot.sound` occur as transitive axioms. All thirteen
  current and seven historical premise fields are read by headline proofs. The accepting
  current premise witness is mandatory. The 396 recorded property derivation chains are
  syntactic evidence records, not a count of verified protocol rules.
- The complete Python regression/mutation suite passes **504 tests in 1,051.595 seconds**,
  run serially after the audit. It includes exact-type/premise/kernel attacks and the
  new custody, economics, admission, image, payload, timed-service and source-map checks.
- Fresh historical vectors, deterministic generated artifacts, authority pins, the exact
  rule report, formatting and `git diff --check` pass. All 1,216 original historical
  contract records are unchanged; `docs/superpowers` is absent.

The current clause inventory is **30 partial / 536 deferred**. The exact rule view is
**33 narrow partial / 27 supporting / 543 deferred** binding rules, plus 32 deferred
assumption/limitation rows. No clause or whole rule is claimed fully verified. CI checks
authority and rule pins before expensive builds; local results do not assert hosted CI
completion or production conformance.
