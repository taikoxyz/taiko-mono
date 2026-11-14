# M02: first bounded L1 trust increment

[`EtnaL1Trust.tla`](EtnaL1Trust.tla) explores startup/session checkpoint trust,
signing/serving gates, and learned supersession when nodes see different progress
on **one canonical finalized L1 history**. It uses the existing `check.py` and
`l1-trust-*.cfg` configurations in this directory. The earlier settlement and
checkpoint-identity models and their 31 configurations are unchanged.

Normative source: [Etna SPEC at
`d18357214fab30ea512ae9858a11699806d72ba1`](https://github.com/taikoxyz/taiko-mono/blob/d18357214fab30ea512ae9858a11699806d72ba1/packages/protocol/docs/etna/SPEC.md).
This is a bounded specification model, not verification of deployed contracts,
client code, Ethereum finality, CometBFT consensus or cryptographic algorithms.

## Small environment trace

| Snapshot index | Generation | Checkpoint | Current generation origin | Meaning                                   |
| -------------- | ---------- | ---------- | ------------------------- | ----------------------------------------- |
| 0              | 0          | 0          | 0                         | Initial state                             |
| 1              | 0          | 1          | 0                         | Landing                                   |
| 2              | 1          | 1          | 1                         | Ordinary recovery, retaining checkpoint 1 |
| 3              | 1          | 2          | 1                         | Landing in the new generation             |

This finite trace feeds interface events already studied in the settlement and
identity models. It is **not their formal composition or refinement**, nor a
second implementation of `land`/`recover`. Identities are collision-free symbolic
tokens, without execution proofs or actual hashes.

`included` and `finalized` advance separately. Each node's `provider` can lag or
return an older canonical snapshot, and may expose included-but-unfinalized data.
Only successful authenticated finalized reads may establish a normal trust
target. Thus the finality negative control has a real input to reject, rather
than being prevented by an environment that only generates finalized inputs.

Provider visibility is not node knowledge. `AuthenticateTarget` authenticates a
startup/session target; `ObserveGeneration` represents an authenticated running
process learning an Inbox generation. The latter only models the generation
observation, not the rest of anchor validation. `knownGeneration` retains the
continuous process's fence; `everGeneration` independently observes authenticated
knowledge so session changes or provider regression cannot silently forget it.
The global chain's generation is not automatically known to every node.

## Node state and evidence

| State                               | Meaning                                                                          |
| ----------------------------------- | -------------------------------------------------------------------------------- |
| `target`                            | Actual authenticated target and whether finality was verified when read          |
| `local`                             | Checkpoint evidence at one height, with a kind/provenance tag                    |
| `certificate`                       | Captured local identity and provenance that granted app trust                    |
| `trusted`, `halted`, `haltHistory`  | App trust, operational safety halt and an independent permanent halt observation |
| `knownGeneration`, `everGeneration` | Operational generation fence and independent knowledge observation               |
| `lastRead`                          | Last own-L1 read outcome, separate from per-signature app response               |
| `missingSeen`, `missingAt`          | One retry witness, not an unbounded history                                      |
| `faults`, `event`                   | Event-time fault observations and one finite last event                          |

`local` describes evidence **at the trust checkpoint**, not the node's current
tip. An evidence bundle at another height means the required checkpoint evidence
is missing; a node whose tip is higher is not required to rewind its tip.
`LoadEvidence` does not change a trusted node's certified checkpoint; a new
logical session first clears trust and obtains a new target/certificate.

Evidence kinds are `Missing`, `Exact`, `WrongEL`, `WrongComet`, `WrongVal`,
`MissingVal`, `ForeignVal` and `LookupVal`. The latter two can have matching
validator-state bytes but lack current-generation recorded-state provenance.
They remain missing evidence rather than being silently accepted as a matching
record or treated as a contradictory validator value. Actual per-height priority
arithmetic and authentication of an import preimage are assumptions represented
by these tags, not algorithms verified here.

## Checkpoint certificate and origin exception

A grant must have a finalized authenticated target in the configured generation,
local evidence at its height, exact EL and historical Comet identity, and the
required validator state from a record of the current generation. Structural
invariants inspect the resulting certificate independently of the acceptance
switches. They also link it to the actual authenticated target and the actual
local evidence, so self-consistent canonical metadata for another checkpoint is
insufficient. The fixed-origin exception in certificate assertions is evaluated
independently of the acceptance helper, so broadening that helper cannot also
broaden the expected certificate property.

For generation 1, the fixed origin is checkpoint 1 even when the latest target
has advanced to checkpoint 2. At that fixed origin only, the retained validator
state is not compared with new genesis state. EL and **historical Comet boundary**
still match the retained record; an empty LastBlockID of the new Comet chain is
not substituted for that boundary. Authenticated genesis construction is outside
this increment. A positive witness obtains trust with the new genesis validator
state different from the retained value. At the later checkpoint 2, ordinary
validator-state value and provenance checks apply again.

## Actions, source and error classification

| Behavior                                                                          | Source                                          |
| --------------------------------------------------------------------------------- | ----------------------------------------------- |
| Logical app/signer session starts untrusted                                       | SYNC-9-4                                        |
| Authenticate own-finalized target and match EL/Comet/required validator state     | SYNC-9-5/5b/5c                                  |
| Missing record or own-L1 timeout retries; contradictory own-source evidence halts | SYNC-9-2/7; RECOV-8-5/12/13                     |
| Canonical hash-matching but unsupported header format pauses for upgrade          | CONS-3.3-7; SYNC-9-8; RECOV-8-6                 |
| Running process learning newer generation revokes trust                           | RECOV-8-14/15; RECOV-8.2-5                      |
| Startup/session authenticated generation mismatch safety-halts                    | RECOV-8-16, within the origin-floor scope below |
| Every block, nil and retained-block signature requires app trust confirmation     | SYNC-9-10/11                                    |
| Public serving consumes app trust                                                 | SYNC-9-15                                       |

Own-L1 `ReadTimeout` and the `appReply` argument to `Sign` are independent. A
previously trusted app need not make a new L1 RPC for each vote. Its unrelated
own-L1 read can time out while a current app-status reply still confirms trust.
An app-status timeout, however, refuses a signature with no fallback. Refused
attempts are represented by the absence of a successful signing transition;
retry timing, signer I/O and the supervisor's restart mechanism are not modeled.
A safety halt is sticky within this continuous-process model: logical session
changes cannot clear it. `haltHistory` observes halts independently and is never
used to enable an action. Manual investigation or a new process is outside scope.

Fault observations are captured when a sign/serve event succeeds. An honest
old-domain signature does not become retroactively wrong after the node later
learns recovery. Signing from a stale-but-authenticated view can be legitimate
until that node learns supersession; a positive witness exhibits precisely this.

The module covers checkpoint-evidence contradictions, not every malformed or
unverifiable own-source response. Untrusted peer/import inputs are not classified
as authenticated own-source evidence. Continuous anchor refresh, ancestry,
candidate-relative age and planned-stop processing remain outside this increment;
in particular the startup triple match is not imposed on every new anchor.

## Explicit profiles and checks

All profiles use finite domains and no hidden state constraints. Every normal
single-node profile includes the complete selected action set, all three
signature kinds and all app-response outcomes.

| Baseline                         | Bounds/profile                                                                              |
| -------------------------------- | ------------------------------------------------------------------------------------------- |
| `l1-trust-baseline-startup`      | One g0 node, snapshots 0..1, all evidence kinds, read errors                                |
| `l1-trust-baseline-recovery`     | One g1 node, snapshots 2..3, all evidence kinds, read errors                                |
| `l1-trust-baseline-supersession` | One g0 node, snapshots 0..2, Exact/Missing evidence, read errors                            |
| `l1-trust-baseline-two-nodes`    | Two g0 nodes, snapshots 0..1, Exact/Missing evidence, no timeout/unsupported-header actions |

The two-node profile checks differing views and trust gates with explicit reduced
evidence/error domains. It does not establish equivalence to the full single-node
error profile or cover every two-node failure interleaving.

Named negative controls independently remove finality, EL/Comet/validator value,
validator provenance, session reset, sign/serve trust, app reply, supersession,
knowledge retention, the fixed-origin exception boundary, the continuous-process
halt fence and error-classification checks. Write-only certificate
controls leave acceptance guards enabled and substitute a different finalized
target or expected rather than observed evidence. Every configuration's first
line states the exact expected invariant; parser/runtime errors and a different
violation are failures, not successful controls.

The two certificate write controls are
`l1-trust-certificate-target-rewrite` (`TrustedCertificateFromTarget`) and
`l1-trust-certificate-evidence-rewrite` (`TrustedCertificateFromLocal`). The
unsafe-session control `l1-trust-missing-halt-fence` must violate
`SafetyHaltSticky`; `l1-trust-missing-origin-boundary` must violate
`TrustedCheckpointExact` at an ordinary, non-origin checkpoint. These controls
mutate the modeled implementation, not the normative protocol.

Independent review found that a canonical-looking certificate was previously
not linked to its actual target/local evidence and that automatic clearing of a
safety halt lacked an independent assertion. The added structural properties
and permanent controls cover those model-assertion gaps. Separating the origin
oracle from its acceptance helper also strengthens a normal baseline's
sensitivity. Earlier missing-guard controls could already reject broad certificate
rewrites or a globally broadened origin exception through unexpected outcomes;
this is not a claim that the prior entire suite could not detect them. None is a
demonstrated production protocol defect.

Positive reachability cases show valid startup, missing-then-retry trust,
unsupported-format pause, two legitimate unequal views, stale-view signing,
signing after an own-L1 timeout, learned supersession revoking trust, and valid
recovery-origin trust. These witnesses certify existence, not eventual progress.
No fairness or liveness claim is made.

Use the same command as the other models; for example:

```sh
python3 formal/etna/check.py --java java --tlc-jar "$TLA2TOOLS_JAR" \
  --output-dir "$TLC_OUTPUT_DIR" --case l1-trust-baseline-startup
```

## Source ambiguity deliberately excluded

A new-generation node whose own finalized provider still predates recovery R
could see the older Inbox generation. RECOV-8-16 says a startup/session generation
mismatch halts, while SYNC-9-2/RECOV-8-5 classify provider lag as a retry; the spec
does not uniquely order the origin/finality-floor check before that comparison.

The generation-1 profile therefore starts inclusion, finality and the provider
at snapshot 2 and allows no pre-R provider snapshots. This is an explicit scope
restriction, not an adopted protocol rule. Its handling of pre-R startup remains
unverified; no protocol bug is claimed from that textual ambiguity.

## Remaining boundaries

No physical crashes, signer HRS durability, ABCI replay, supervisor reconnect,
manual investigation/unhalt procedure, full committee/genesis reconstruction,
L1 finality violation, real chain forks, QC/STF/blob verification, switch-network
Unzen-origin checks, anchor age, refresh-frequency guarantee, implementation
refinement or unbounded theorem is claimed. The canonical identity trace and
proof authentication are assumptions. Later modules must revisit these
assumptions when adding the omitted state and actions.
