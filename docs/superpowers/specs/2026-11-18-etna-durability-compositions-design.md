# Etna durability and asynchronous composition verification

The user authorized continuing the established next-five cadence, fixing confirmed
feedback and proceeding without waiting for external reviewer confirmation.
Internal independent source and behavioral gates remain required. The starting
head is fe04c11223dbaeae408dc1581d1756c8a11207e1, whose current hosted checks passed.

## Goal and approach

Move selected C01/R01/P01 obligations from model-only or scripted observations
toward actual public-input consumers and freely interleaved current models.
Retain the existing offline Go/Forge/TLC stack and source authority. This design
does not change the protocol. Five separately reviewable outputs are selected:

1. O01: stock FilePV public last-sign-state persistence and cross-process decode,
   cached nil-precommit/prevote replay, exact timestamp recovery and HRS refusals.
2. O02: actual stock signer request handler response/error semantics after that
   decode, wrong chain refusal and valid retry, without sockets or new signing.
3. O03: actual Registry mature top-up, forced exit and confirmed historical slash,
   occupied-zero displacement, then public zero withdrawal preserving replacement.
4. O04: a free current proving graph with capacity one/two, resource arrivals,
   retry, original-full-range publication and overlapping settlement.
5. O05: a free current signer two-rank graph with Nil/value choices, two salts,
   crash/retry/delivery and one live recovery with a reduced fresh domain.

Increasing scripted case counts alone would preserve known scheduler blind spots.
Full live consensus/proving/importer implementation is unavailable in this scope.
Selected real consumers plus bounded nondeterministic products are the chosen
middle ground. Complete C01/R01/P01 acceptance remains open.

## Binding constraints

- Exactly five new increments O01–O05; prior N04 repair and N/J/H/G/F batches remain complete. No automatic sixth.
- Formal/test tooling only. No production, normative SPEC, Notion, deployment, live chain, merge or ready conversion.
- No private-key access, key generation or new signing. Only existing allowlisted public vote/registration projections may enter execution; never mount the mixed source artifact.
- Pin canonical SPEC d18357214fab30ea512ae9858a11699806d72ba1/blob649548c58d6629dd85143b33efd3644a3bb71509/SHA2564d81d5dadcee3eb94ff554ec5a8144a47888dd5a8263ac5852422a0f1d1dd71b, Comet0880b4d378f347ab16e54ec677ff50d803f37d62 and contracts89f419915de4b73bb57c53bf970f6dea9e8e8c8c.
- Reuse reviewed offline isolation, supervisor, exact source/tool/input guards and existing physical cache locks; writable runtime artifacts are disposable and separately attributed.
- One implementation writer at a time. No native/TLC engine before root approves its exact static interface/oracle/argv/hash packet. Do not edit watched inputs while guards run.
- Independent adversarial source review and independent behavioral verification precede publication. At most two material fix rounds per gate and one consolidated final fix wave.
- Expected values must be source/public-input derived before execution. Bind actual attempted inputs, full selected state, history and events, including refusal paths; terminal counters alone are insufficient.
- Same-copy original/fault/restored is required for each selected source control, with the intended semantic failure and real restored positives. Setup errors, accidental panic, timeout, skips and stale outputs get no detection credit.
- Root owns shared REPORT/WORKLIST/README, plan markers, ledger, publication and monitor state. Preserve completed worktrees, raw evidence, input pins and old executable/config bytes unless a named task explicitly owns a shared change.

## Native consumer boundaries

O01 injects a published signature at stock saveSigned. Writer and reader execute
in separate processes over the actual disk bytes, native state encoder/decoder
and unmodified replay API. The key is absent. Restrict SignVote to nil precommit
or prevote HRS-equal/regression/conflict paths, because non-nil precommit signs
extensions before replay. Never run LoadFilePV, LoadOrGenFilePV, key generation,
fresh ascending-HRS SignVote or upstream test packages. Direct CheckHRS may test
ascending authorization without producing a signature. No production loader,
sign-before-save/expose, fsync power-loss, two-writer or failover claim follows.
The known qualified Registry unittest import issue is a prerequisite repair;
preserve discovery while allowing package-qualified invocation.

O02 exercises DefaultValidationRequestHandler and its concrete response union,
separate Go error and actual attempted chain/vote context captured before the
handler mutates its shared vote pointer. Rehydrate from disk
produced in this invocation. A rejection followed by genuine cached retry must
preserve durable HRS/bytes. This establishes synchronous handler behavior, not
trusted session/reconnect, socket timeout, supervisor restart or WAL integration.

O03 uses the existing default 5000-bps deployment, three distinct public PoPs,
the existing public double-sign pair, exact-transfer token and mocked initialized
Inbox generation/snapshot. At heights10/12/14/15/16/17/18: register A4/B4; top-up
A5; activate A9; Inbox forceExit15; snapshot15 confirmation16; generation1 accepts
historical generation0 slash at17, paying reporter2/sink7; register C4 at17 into
held zero slot0; public zero-withdraw old A18. Compare the opposite order which
withdraws A before C registration. Lifetime key, exit/confirmation, intermediate
same-block checkpoints, replacement entry and token conservation are explicit.
This is real occupied-zero displacement, not 4096 positive-principal capacity
or authentic recovery committee derivation. Total deposits17, vault8, reporter2,
sink7, payee0; the primary path has six actual transfers.

## Model products and runtime budgets

O04/O05 import unchanged operational models and add bounded schedulers plus
independent action-local raw observers. No unbounded journal or expected mask
chooses execution. Enabledness refusal is observed in both directions, including
same-result histories and repeated set-idempotent returns. Exact witness configs
must prove reachability of each decisive prestate, separately from safety PASS.

O04 fixes only the two origin captures at time0. Then History, Availability,
Complete (including cross-source), Publish, Tick, Land, Finalize, PublishAnchor
and Produce interleave freely. Bounds MaxHead3/MaxProduces3/MaxTime2/U2/window1/
ancestry1, variable resources, capacity1 or2, no recovery or authority rewrite.
Capacity1 must separately refuse both suffix-only data and full original-range
data of length2 after short settlement. Only the full-data prestate isolates
the capacity-budget fault. Capacity2 permits full re-publication and overlap.
No fairness/throughput claim follows; Tick may miss a valid dispatch window.

O05 permits all domain0 rank1/2 × A/B/Nil × salt0/1 requests and domain1 rank1/A/
salt0, optional once-only live recovery, arbitrary actual crash/restart/delivery,
and uncertainty. Do not pre-filter old requests using the expected floor. Saved
byte identity is checked against pre-action durable state and incoming arguments,
with actual request/return events rather than only post-set differences.

The larger products have an explicit opt-in checked config directory rather
than silently extending every default CI run. Reuse check.py's exact outcome,
module resolution and input-drift logic with --config-dir; default remains
configs/. A normal exhaustive run needs queue0. Start a reviewed bounded smoke,
then a root-approved per-profile cap no greater than300seconds. Retain any failed
or inconclusive attempt and disclose the omitted dimension if reduction is
necessary. A timeout never closes an exhaustive profile or an archived search.
CI success for defaults is separate from the opt-in product evidence.

## Verification and exit

Each increment needs a scoped independent source gate and a different behavioral
challenge, exact raw input attribution/restoration and focused ordinary tests.
At the final gate inspect all new commits, complete ordinary regressions,
source/receipt witnesses, current head/feedback/CI and unchanged baseline inputs.
Publish to the existing draft only and read back bodies/head. Preserve raw
artifacts and return to feedback-only after five. Stop for discussion if an
independently supported natural protocol/source defect is found.
