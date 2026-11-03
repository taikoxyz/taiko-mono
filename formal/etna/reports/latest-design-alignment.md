# Latest Etna H1–H3 alignment

Authority: main `1135c9b24fd03f50cb48eab250879435fd54f528`, including SPEC, ACCEPTANCE,
ANCHORLESS and SWITCH. These protocol documents are unchanged. This report concerns
conditional decoded-design safety, not production implementation or launch sign-off.

## Composed current claims

`Etna.Statements.Current.Claims` is the conjunction of the three exact current claims;
`Etna.Design.Current.Headlines.claims` proves it. The audit independently pins all four
headline types and checks that every one of the nine current premise fields is read.
Historical headlines retain their original types and separately pinned authorities.

| Obligation                   | Main current evidence                                                                                 | Boundary                                                                                                                                                                                                                                                                                                                                           |
| ---------------------------- | ----------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| H1 recognized funds          | `Custody.trace_invariant`, `funds_authorized`, `landing_edge_authorized`, `path_rooted`               | Full-header paths retain actual reachable accepted calls. Pending/refused starts and inactive archival records are not declared authentic. Genesis, authenticated Unzen and decoded header/hash separation are primitive deployment/crypto boundaries.                                                                                             |
| Actual overlapping suffix    | `Protocol.accepted_suffix_from_certificate`, `Journal.trace_frontier_record`                          | S-offset grid arithmetic, actual retained frontier lookup and cuts derive the suffix when p<c; the accepted call never receives a semantic chain or suffix as input.                                                                                                                                                                               |
| H2 same-round accountability | `ProtocolFinality.current_h2`, `protocol_same_round_accountability`, `paid_evidence_future_liability` | More than one third of power; all future issued positive unwithdrawn key bonds, including displaced and historical-generation liability. Actual token transfers and exact receipts commit atomically. Standard token semantics and sufficient future registry balance remain explicit.                                                             |
| H2 cross-round finality      | `Finality.full_chain_agreement`, `ProtocolFinality.protocol_full_chain_agreement`                     | Within one World/generation from the same full origin header, induction derives common prefixes from each chain's own complete archive and actual slot-snapshot history. Honest local round transitions, strict Byzantine minority, vote attribution and deterministic Comet/EL binding are assumed; chain agreement and context equality are not. |
| H3 actual FIFO and deadlines | `Journal.trace_invariant`, `landing_service`, `local_due_action`, `local_late_action`                 | Complete end-block snapshots include same-block calls. Selected rules enforce real byte inclusion/skip; current headlines normalize the transaction hash to admission's fixed hash. Strict canonical L1 time supports the inclusive deadline implication.                                                                                          |
| H3 call/recovery frames      | `nonlanding_never_advances`, `nonrecovery_preserves_existing`, `recovery_queue_exact`                 | Exhaustive current calls, failed-call stutter and node events; only landing advances head, rollback may rewind, and only listed recovery hashes change.                                                                                                                                                                                            |
| Permanent registry           | `RegistryMachine.trace_stable`, `evidence_stays_slashable`, `RegistryPayments.failure_atomic`         | Closed lifecycle operations replace generic caller-supplied mutation. IDs and keys persist; historical slots and evidence retain meaning.                                                                                                                                                                                                          |

Short names above are under `Etna.Design.Current` (custody under `Protocol.Custody`).
The manifest contains 195 current contracts and 1,216 preserved original contracts.
The current inventory has 24 partial/542 deferred clauses; 54 of 603 binding rule IDs have
narrow partial evidence. No clause or operational acceptance gate is marked fully proved
merely because a headline theorem exists.

## Validation and nonempty evidence

Current fixtures cover accepted nonempty landings, overlap, corrected Unzen starts,
first-generation anchors, crossing timestamp rules, deterministic include/skip decisions,
unknown/unsupported rules, permanent displaced bonds, historic-generation slash receipts,
structural recovery, rollback, full frontier lookup and signer restart preservation.
Semantic mutants must compile as model-only changes before unchanged evidence rejects them.
Exact-headline and mandatory-manifest checks protect the current conjunction separately
from historical results.

Positive finite fixtures are not a complete satisfying model of all global crypto/EL/Comet
premises. In particular, synthetic accepting verifier/hash adapters demonstrate concrete
accepted/certified paths, not global verifier soundness or collision resistance. The global
claims keep those primitive refinements explicit; this update does not infer them from tests.

The final audit passed all 1,411 exact contracts, 325 property derivation chains and
31 Lean regression modules, with only the standard axioms. All nine current and seven
historical premise fields are consumed. All 478 Python tests passed in 878.792 seconds,
including the new current semantic mutants and preserved historical gate/witness suite.
Source/library lint, fresh historical vectors, all authority pins, deterministic generated
artifacts, the current rule report and `git diff --check` also passed. All 1,243 previously
committed contract records remain unchanged; 168 public current theorem contracts were added.

## Review outcome and limits

No confirmed new defect in the latest Etna design was found. The public H1/H3 statements
require no committee honesty: the strict-minority/honest-round condition belongs only to
H2's explicit agreement antecedent, matching the stronger leaf proofs. Same-round accountability also needs no honest minority. Review did find and correct
model defects: disconnected catalogue/admission hashes; trust before initialization or
without an authenticated origin; and zero-only initial token state that made positive
standard-token calls unreachable. Deployment balances/approvals are now explicit inputs,
and a funded trace exercises actual paid transactions from that initial state.

The decoded-header separation boundary includes authenticated L1/header/storage expansion
of the anchor, not merely hashing raw EL bytes. Token environment addresses must be wired
to the intended deployment; the proof uses those fixed addresses. The node model preserves
signer state and gates trust but does not prove the stock-store importer or complete
producer membership/height refinement; H2 names honest-engine and signature attribution
separately.

DAO upgrades, image registration/revocation and verifier versions are interpreted under
explicit backend soundness. This proves no arbitrary new code safe and no supported image
combination available. Image-set coverage/launch policy, raw decoder/MPT/KZG/crypto/EL/Comet
implementation refinement, outage/recovery loss bounds and operational switch rehearsal
remain external or deferred. No liveness claim or acceptance measurement follows from
these three conditional safety theorems.
