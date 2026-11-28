# J02: two-node finalized-generation supersession

`EtnaTrustSupersession.tla` extends the unchanged `EtnaL1Trust` module. It starts
from its exact `Init` and schedules the actual inherited actions in two mirrored
finite histories: first observer A is physical node 1 or node 2, and B is the
other node. NodeCount=2, MaxSnapshot=2, SessionGeneration=0, Missing/Exact evidence,
no error actions, Actual certificate writes and every correctness flag TRUE.
Snapshot 1 is generation 0 at checkpoint height 1; snapshot 2 is authenticated
recovery into generation 1 retaining height 1.

The earlier two-node profiles stop at snapshot 1. Earlier supersession profiles
reach snapshot 2 with one node. This companion adds a bounded history of
simultaneously different per-node knowledge across finalized recovery. It does
not add a new generation installation API or change the original action guards.

## Source and scope

The normative source is [SPEC d18357214fab30ea512ae9858a11699806d72ba1](https://github.com/taikoxyz/taiko-mono/blob/d18357214fab30ea512ae9858a11699806d72ba1/packages/protocol/docs/etna/SPEC.md),
blob `649548c58d6629dd85143b33efd3644a3bb71509`, SHA-256
`4d81d5dadcee3eb94ff554ec5a8144a47888dd5a8263ac5852422a0f1d1dd71b`.
Current scoped correspondence at 991e06f6 does not replace that canonical source.
Unknown future source bytes remain unaccepted under the existing manifest gate.

| Model observation                                                                       | Canonical source             |
| --------------------------------------------------------------------------------------- | ---------------------------- |
| Session begins untrusted; authenticated target, exact EL/Comet/recorded validator state | SYNC-9-4/5/5b/5c             |
| Only authenticated finalized generation information establishes supersession knowledge  | RECOV-8.4-1/2; RECOV-8.2-4/5 |
| Learned newer generation revokes running-process trust                                  | RECOV-8-14/15                |
| Startup/session generation mismatch halts                                               | RECOV-8-16                   |
| Block, Nil and Retained requests require trust and reject known supersession            | SYNC-9-10/11                 |
| Public serving consumes app trust status                                                | SYNC-9-15                    |

Own-finalized authentication and symbolic evidence identities remain interface
premises. These finite histories do not verify cryptography, consensus, a live
client, a physical importer/signer restart, durable HRS state, or a supervisor.
They establish no fresh generation-1 admission, fairness or eventual progress.
Logical BeginSession preserves learned knowledge and cannot clear a safety halt.
The inherited Serve action checks trust/halt, without its own separate generation
knowledge predicate; this companion makes no independent service-knowledge claim.

## Frozen dispatch and receipts

Every listed action is attempted. `ENABLED TrustCall(i)` alone determines whether
it executes, except the deliberate sole omission of attempt 21 in omission
profiles. The literal expected masks and records are used only after dispatch,
never to prevent a bad enabled action. Disabled or deliberately omitted calls
leave all original variables unchanged. All signature app replies are TRUE.

E means enabled/executed, R disabled/refused, O enabled but deliberately omitted.
The omission column is independently derived from the original action guards;
its changed enabledness is part of the test.

| #   | Actual inherited call                 | Normal | Omit 21 |
| --- | ------------------------------------- | ------ | ------- |
| 1   | Include                               | E      | E       |
| 2   | Finalize                              | E      | E       |
| 3   | ProviderView(A,1)                     | E      | E       |
| 4   | BeginSession(A)                       | E      | E       |
| 5   | AuthenticateTarget(A)                 | E      | E       |
| 6   | LoadEvidence(A,1,Exact)               | E      | E       |
| 7   | GrantTrust(A)                         | E      | E       |
| 8   | Sign(A,Block,TRUE)                    | E      | E       |
| 9   | Serve(A)                              | E      | E       |
| 10  | ProviderView(B,1)                     | E      | E       |
| 11  | BeginSession(B)                       | E      | E       |
| 12  | AuthenticateTarget(B)                 | E      | E       |
| 13  | LoadEvidence(B,1,Exact)               | E      | E       |
| 14  | GrantTrust(B)                         | E      | E       |
| 15  | Sign(B,Block,TRUE)                    | E      | E       |
| 16  | Serve(B)                              | E      | E       |
| 17  | Include                               | E      | E       |
| 18  | ProviderView(A,2)                     | E      | E       |
| 19  | ObserveGeneration(A), before finality | R      | R       |
| 20  | Finalize                              | E      | E       |
| 21  | ObserveGeneration(A), after finality  | E      | O       |
| 22  | Sign(B,Retained,TRUE)                 | E      | E       |
| 23  | Serve(B)                              | E      | E       |
| 24  | Sign(A,Block,TRUE)                    | R      | E       |
| 25  | Sign(A,Nil,TRUE)                      | R      | E       |
| 26  | Sign(A,Retained,TRUE)                 | R      | E       |
| 27  | Serve(A)                              | R      | E       |
| 28  | BeginSession(A)                       | E      | E       |
| 29  | ProviderView(A,1)                     | E      | E       |
| 30  | AuthenticateTarget(A)                 | E      | E       |
| 31  | LoadEvidence(A,1,Exact)               | E      | E       |
| 32  | GrantTrust(A)                         | R      | E       |
| 33  | Sign(A,Block,TRUE)                    | R      | E       |
| 34  | Serve(A)                              | R      | E       |
| 35  | ProviderView(A,2)                     | E      | E       |
| 36  | AuthenticateTarget(A)                 | E      | R       |
| 37  | BeginSession(A)                       | R      | E       |
| 38  | ProviderView(B,2)                     | E      | E       |
| 39  | ObserveGeneration(B)                  | E      | E       |
| 40  | BeginSession(B)                       | E      | E       |
| 41  | AuthenticateTarget(B)                 | E      | E       |

Normal disabled positions are exactly 19, 24–27, 32–34 and 37. Both nodes first
actually sign and serve with trust. Attempt 19 observes included=2/finalized=1
and must preserve the entire original state, including faults and event.
Attempt 21 then learns generation 1 and revokes only A. It preserves A's existing
certificate, target and local evidence, and every B-owned field. B actually signs
Retained and serves from provider 1 / known 0 / trusted TRUE at 22–23. Global
finality advancing does not teach B the recovery generation automatically.

A's three signature kinds and Serve refuse at 24–27. Its actual BeginSession at
28 clears the certificate and target.ready while retaining known/ever=1 and
local Exact snapshot 1. Re-authenticating provider 1 cannot lower that knowledge;
GrantTrust, Block signing and serving still refuse at 32–34. Actual provider 2
authentication at 36 causes mismatch halt; BeginSession then refuses at 37.
B stays unchanged until its own provider switch/observation/session/authentication
at 38–41, learning generation 1, revoking trust and reaching its mismatch halt.

## Independent raw oracle

Each receipt captures enabledness, execution and the whole original before/after
state: included, finalized, provider, target, local, certificate, trusted, halted,
knownGeneration, everGeneration, lastRead, missingSeen, missingAt, haltHistory,
faults and event. Both per-node histories also retain all 12 node-owned fields
for every attempt. Continuity links every receipt to the literal initial state,
the prior receipt and the current whole original state.

`TrustRawAudit` compares complete records using explicit per-attempt changed
fields and full frames. It does not construct expected certificates with
MakeCertificate, WrittenCertificate, CertificateSound, Gen, Height or other
original getters. The original safety invariants are supplemental.

The literal trusted snapshot-1 certificate is:

```text
present=TRUE, snapshot=1, authenticatedFinalized=TRUE, height=1,
el=<<"EL",1>>, comet=<<"HistoricalComet",1>>,
val=<<"RecordedVal",0,1>>, valSource="Recorded", valGeneration=0
```

The literal cleared certificate is:

```text
present=FALSE, snapshot=0, authenticatedFinalized=FALSE, height=0,
el=<<"EL",0>>, comet=<<"HistoricalComet",0>>,
val=<<"MissingVal">>, valSource="Missing", valGeneration=0
```

The normal full witness requires all 41 receipts, the successful initial service
and signing on both nodes, selective revocation, lagging B service, every refusal,
and both complete knowledge/session/halt histories. At the terminal:

- included=finalized=2, provider=2 for both nodes;
- knownGeneration=everGeneration=1, trusted=FALSE, halted=haltHistory=TRUE for both;
- both targets are ready snapshot 2 with authenticatedFinalized=TRUE;
- both certificates are the literal cleared certificate, locals remain Exact snapshot 1;
- lastRead=OK, missingSeen=FALSE, missingAt=0 for both, all faults FALSE;
- event is StartupMismatch for physical B.

With attempt 21 omitted, A's old signatures and serving at 24–27 really execute.
Session 28 clears trust, then provider-1 authentication/evidence allow GrantTrust
at 32, so 33–34 also execute. Because A is trusted, AuthenticateTarget at 36
refuses. BeginSession at 37 now executes and clears trust/certificate again.
At the partial endpoint both nodes are untrusted, yet A remains known/ever=0,
unhalted without haltHistory, target snapshot 1 authenticated but not ready,
lastRead=None. B has the normal generation-1 halted endpoint. The full witness
must be absent; the separate complete partial-history witness must be reachable.
A PASS absence control establishes lost witness, not containment progress.

## Configurations and actual-source fault

| Configuration suffix                           | Exact expected outcome                                                  |
| ---------------------------------------------- | ----------------------------------------------------------------------- |
| normal                                         | PASS, both mirrors, inherited safety + raw/milestone/terminal audits    |
| witness-first1, witness-first2                 | TrustCompleteNotReached violation at complete normal endpoint           |
| missing-observe-first1, missing-observe-first2 | PASS, full witness absent, complete partial endpoint audited            |
| partial-first1, partial-first2                 | TrustPartialNotReached violation at complete omission endpoint          |
| audit-first1, audit-first2                     | PASS, sole TrustSelectiveRevokeAudit, immediate focused noninterference |

The author fault changes exactly the actual ObserveGeneration trust write in a
private copy, after validating one unique source match:

```tla
/\ trusted' = [trusted EXCEPT ![n] =
      IF CheckSupersession /\ Gen(provider[n]) > SessionGeneration THEN FALSE ELSE @]
```

becomes:

```tla
/\ trusted' = [m \in Nodes |->
      IF CheckSupersession /\ Gen(provider[n]) > SessionGeneration THEN FALSE ELSE trusted[m]]
```

The first actual finalized observation then wrongly revokes B as well as A.
The sole `TrustSelectiveRevokeAudit` must fail immediately on receipt 21 after the
write executes. It checks both other-node trust and equality of all 12 other-node
fields; global event changes are permitted. Conservative inherited safety alone
need not reject excessive revocation. Audit configs are changed only in private
copies to expect that precise invariant. Parse/type/setup errors, timeout, a
wrong violation or a merely missing witness cannot count as a fault kill.
Restore the exact original action in the same copy, prove all other source and
tool bytes unchanged, restore config expectations and rerun full mirrored
normal witnesses. The independent tester chooses a distinct finality/persistence
boundary challenge after source freeze.

Use the existing checker with selected `--case trust-supersession-*` stems and the
existing Java 17 / TLC 1.7.4 pin inside the existing offline namespace supervisor.
Bind the copied source and exact tools read-only; allow only disposable output
writes. Do not invoke Java directly on the host or download another tool. Exact
commands, input/tool hashes, raw outcomes, mutation/restoration identities and
limitations belong in the task evidence report. This guide specifies the test
contract; it does not itself assert an engine result.
