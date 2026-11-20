# Repeated recovery at one settled checkpoint

This bounded product covers the selected repeated-recovery case in
[ACCEPTANCE §2](../../../packages/protocol/docs/etna/ACCEPTANCE.md#2-recovery-acceptance-spec-section-8).
Use the current reviewed bundle selected by the fixed
`repeated-recovery` claim. The selector requires the exact SPEC, ACCEPTANCE
and SWITCH documents. Its source receipt records `NOT_EVALUATED`.

| Current rule | Model boundary |
| --- | --- |
| RECOV-8.1-4, RECOV-8.3-1–5, 8–9, 12, 14, 16 | External authorization bank, exact execution-time arguments, nonce invalidation and atomic refusal |
| RECOV-8-47, 47a, 48–49, 51, 54, 56, 58 | Rules/stop transition, unchanged settled records/FI/slot 284, discarded live suffix |
| RECOV-8.4-2–5, 7–13 | Actual finalized R, fixed origin, reset EL identity, generation domain and first-block fields |
| CONS-3.2-3, CONS-3.4-4–6, 8, 11a and BACKP-6.4-8 | Own-anchor rule and timestamp, parent linking, finality and the next anchor carrying fresh settlement |
| PROOF-6.2-8–10, 30–33 and STOR-B-9 | Four-word cuts, full statement, actual landing parent and signing committee snapshot |

## Finite domain

The Etna start is height 0. Its synthetic L1 origin is block 25 at time
94. The committee-0 cutoff is the earlier authenticated registry block
24. Six authenticated g0 blocks have BFT and anchor times 94–99, EL
times 95–100, and finalized anchors 25–30. The last was landed at L1
block 31 with reference 30. The model starts at the closed and finalized
block 31, and `Advance` opens the next execution block. `Finalize` can
only advance to an earlier block. The synthetic clock then allows six
advances through block 37, with one second per step. The selected
back-pressure bound U=6 permits the initial six blocks against the start
checkpoint. `maxAnchorAge` is 1,296 seconds, above the deployment minimum.
The selected heights
have no ordinary committee switch, for example with epoch length 16.

The highest modeled head is 8. Up to three actual `Produce` calls are
recorded, including refusals. The `produces` budget is model metadata.
Refused calls have no protocol writes. The exact governance input bank is
outside Inbox storage and persists in full in the raw frames. The bank
includes an unexecuted nonce-0 authorization invalidated at g0 and the
executed nonce-1 authorization retried after R1. The latter is stale in
both generation and nonce. The chosen execution points are part of the
offer domain. A retained argument reaches the contract predicate even
when that predicate refuses it.

R1 is block 32/time 101. Its rules-zero authorization clears stop while
retaining pending rules 1 and activation time 1397. The authenticated
fixture writes the rules and stop schedule at L1 block 29, time 98, with
stopTime 1394 and rulesTime 1397. A g0 successor can still be produced
before R1, which then truncates any live suffix above c=6. The selected
proof-capture activity starts in g1. R2 is block 35/time
104. Its authorization replaces the still-pending ruleset with rules 2,
updates both rule ids and clears activation time
and stop, and discards the live g1 suffix. The earlier origin, the initial
c=6 landing, FI head 4 and slot 284 value 24 survive both recoveries. The
live head resets to 6. The g1 suffix and captured job survive as external
archive data. The captured g1 job lacks the pair of verified backend
results in this product. Its replay after R2 is jointly stale and missing
that pair. Whether DAO operators could have settled the suffix before
authorizing recovery is outside this check.

A successful second `Observe` authenticates the g2 origin only after R2
finalizes. The first g2 block uses BFT 104, empty LastBlockID and LastCommit,
and an anchor at or after R2. The selected fresh g2 landing changes c to 7
and slot 284 to 35. After that landing finalizes, the positive endpoint
produces height 8 with the anchor that carries its exact checkpoint.
Symbolic identities encode the relevant generation, height, parent and
anchor choices. They stand for authentic EL and Comet hashes.

The selected fixture assumes initialized storage, an authenticated settled
prefix, valid EL history, empty recovery lists, no new FI entries, finalized
L1/registry authentication and the valid g2 backend result pair. Actual EL
execution, CometBFT, signing, proof generation and DA publication remain
premises or outside scope. Unzen first landing, full recovery acceptance,
liveness and deployment readiness remain outside the product.

## Profiles and readback

The profiles under `products/repeated-recovery` share one `Next` and all
bounds. `safety` checks the finite graph invariants. Each remaining profile
adds an inverted endpoint predicate to obtain a TLC witness.

| Profile | Exact observed endpoint |
| --- | --- |
| `smoke` | Accepted g1 height 7 with R1 anchor |
| `stale-nonce` | Matching g0, c and deadline with original nonce 0 is refused after invalidation |
| `old-generation` | Retained g0 authorization is refused in g1 with the original nonce still matching |
| `r1-only` | Own R2 argument is refused in g2 while only R1 is finalized |
| `progress` | Archived g1 block/job, g2 height-7 Land at L1 block 36, finality, then height 8 using its checkpoint |

`repeated_recovery.audit(text, case)` replays the entire typed Init and
every adjacent frame. Each receipt exposes the actual arguments, decision,
PRE and POST. The replay verifies the exact external inputs and reads the
modeled statements through the unchanged four-word cut adapter. A raw prefix
alone can establish an observed edge. Only a validated named endpoint
meets its case profile. The diagnostic cases `origin-overwrite` and
`missing-bootstrap` check a source-fault edge and an unready prefix. The
second requires a separate omission experiment with the actual dispatch.

`current_receipt` additionally consumes the raw native execution record.
It checks the staged TLA and cfg hashes, selected case, actual native argv
and status, and complete native transcript. The command uses the fixed
paths of the offline namespace. Offline reconsumption can use a relocated
copy when its source bytes match the captured hashes. An ordinary result requires
native 0 with a completed empty-queue graph. A named result requires native
12, the profile's exact endpoint diagnostic and complete replay. A named
result is existence evidence. Source-fault and omission diagnostics have no
success attribution.
