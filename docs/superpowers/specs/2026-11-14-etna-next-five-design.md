# Etna next five bounded verification increments

## Authorization and stopping rule

The user asked to proceed directly from M02 through up to five more worklist
modules, stopping when a credible protocol problem is found. Continue M03,
M04, M05, M06 and M07 in order on the same `formal/etna/` project/branch.
No design-approval pause is needed for routine modeling choices.

A stop-worthy problem is a concrete trace allowed by the pinned normative rules
that violates an intended protocol safety/progress property, independently
reproduced and source-reviewed. A disabled-guard control, model bug, known
explicit limitation or ambiguity alone is not such a finding. Fix model bugs,
retain the evidence, and do not repair the protocol specification. If an
important premise cannot be established, record the verification as inconclusive;
do not narrow it silently or report success. Stop on a demonstrated protocol
problem before starting the next module.

Source: Etna SPEC at `d18357214fab30ea512ae9858a11699806d72ba1`, refreshed
2026-11-14. Refresh source at subsequent module boundaries. No production build,
new toolchain/install, deployment, push, PR or normative SPEC edit is requested.
Use existing TLC/Java and the existing isolated worktree. Keep prior modules,
configs and runner unchanged unless a demonstrated integration requirement
justifies a separately reviewed change.

## Method and evidence

Each module gets a finite model, explicit source mapping/environment contract,
structural derived properties, positive boundary witnesses and independently
weakened implementation controls. Independent source review and behavioral
verification challenge both the transition rules and the assertions. Controls
must be evaluated with the whole outcome expectation: a mutant making an
expected violation disappear is already detected by the suite.

Record exact source/module/config hashes, normal exhaustive counts and actual
counterexample traces. Keep crash, asynchronous observation and durable-state
boundaries visible rather than turn the desired property into an enabling
premise. Local results do not prove client refinement or an unbounded theorem.
Run focused new cases per module, retain prior configurations unchanged, and run
the complete suite at the five-task or discovered-problem stopping boundary.
Maintain per-module local commits and GitHub worklist progress; publication and
actual-code trace replay remain separate pending work.

## M03: signer and ABCI/EL crash recovery

Use two focused modules, `EtnaSignerCrash.tla` and `EtnaAppCrash.tla`, with
`signer-crash-*.cfg` and `app-crash-*.cfg`. They study different persistence
contracts; do not claim their product or transitive composition with M02.
`CRASH_RECOVERY.md` maps them to SPEC CONS-3.1-9, RECOV-8.2 and SYNC-9-10..14,
and pinned CometBFT v0.40.0 persistence/signing source.

Signer model: separate per-domain durable HRS/message/signature records from
volatile signing work and network delivery. Permit crashes before/after durable
write and before/after reply. Every delivered signature must match a durable
record; no two delivered messages differ at the same domain/HRS; same-step retry
returns the same recorded message/signature; lower HRS and uncertain/lost state
refuse signing. App trust is re-established before reconnect after a restart.
Different generations use distinct domains, not a global HRS counter. Single
serialized state owner is an explicit source contract, not a derived property.
Learned generation refusal requires a source-reviewed durability/interface
contract; do not assume that per-domain HRS alone records generation knowledge.
Keep ambiguous generation-fence mechanism separate from an actual violation of
the explicit old-generation refusal obligation.

App model: distinguish durable block store, FinalizeBlock response store,
application completed-Commit height, EL effects/identity and Comet state. Model
write boundaries and physical process crashes. Handshake reports only completed
Commit, replays with real app when app is behind, and uses saved responses/mock
app only when app already committed. Repeated FinalizeBlock must be idempotent
on the same stored block even when EL is already ahead. Ready state must not
claim committed effects absent from the actual durable app; Info must match an
EL/app-agreed committed checkpoint. Do not assume all stores commit atomically.

Include initial_height=1 and a later-height/recovery profile. Explicitly reach
the already documented stock failure after storing the first block at an
initial_height above 1 before saving its state. This is a known limitation,
not a new protocol bug; do not suppress the crash by a hidden constraint. No
operator database surgery or automatic cure is invented.

## M04–M07: bounded boundaries to refine against current source

- M04 committee derivation/activation: fixed authenticated selection snapshot,
  current/next/pending sets, switch at H and activation at H+2, recovery clearing
  pending old-domain updates. Compare actual effective sets with an independent
  schedule/history observer; arithmetic/crypto assumptions remain explicit.
- M05 registry lifecycle: delayed stake/top-up activation, displacement, effective
  exit, landed snapshot confirmation and withdrawal. Include old/captured
  confirmations across registry changes and ensure withdrawn funds cannot remain
  effective membership; define occupancy versus identity lifetime separately.
- M06 forced inclusion: fixed queued identities, due-head include/legal skip,
  per-block cursor movement, landed consumption and recovery blanking retaining
  timestamps/order. Derive FIFO and no unauthorized omission from actual
  consumed history, not just the action's chosen head value.
- M07 proving/DA/back-pressure: produced/committed versus authenticated anchored
  and L1-landed heads, delayed/failed jobs, reference availability/expiry and
  resumption. Separate bounded unsettled safety from conditional progress;
  explicitly model the progress/resource assumptions and check for circular
  waits rather than assert that proof/DA inevitably arrives.

Root writes a concrete per-module brief/source map before each implementation.
These module descriptions do not claim full module coverage or pre-approve
unexamined source assumptions.
