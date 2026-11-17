# Etna adversarial coverage implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to execute five independently reviewed and verified increments.

**Goal:** Replace specific untested source/input assumptions with falsifiable behavior and raw evidence, with frequent blind-spot reflection.

**Architecture:** Two real-source lanes over published unsigned/public inputs and three thin companions over unchanged model actions; authoritative existing isolation, classifiers and caches remain shared.

**Tech Stack:** Configured Python stdlib, Java17/TLC release1.7.4, pinned CometBFT0.40.0 and existing Go/Foundry, offline namespace/Docker runtimes.

**Spec:** `docs/superpowers/specs/2026-11-17-etna-adversarial-coverage-design.md`.

## Global Constraints

- Start at18fb38a39b40c1f9e1e9736335c99b7430001e04 on existing codex/etna-tla-settlement; all G01–G05 are complete and must not restart.
- SPEC d18357214fab30ea512ae9858a11699806d72ba1/blob649548c58d6629dd85143b33efd3644a3bb71509; contracts89f419915de4b73bb57c53bf970f6dea9e8e8c8c; Comet0880b4d378f347ab16e54ec677ff50d803f37d62; TLC jar936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88.
- Preserve32 old recursive TLA files,387 default cfgs and all archived inputs. Only additive companions; no changes to original engines to make the new tests pass.
- Configured Python/existing tools and one physical cache per toolchain with existing locks; no install or implicit fetch. Local Git reads set GIT_NO_LAZY_FETCH=1.
- Inspect entrypoints/hooks before isolated offline execution. Source/dependencies read-only, disposable outputs, no original home/Git/credentials, key generation/signing, live RPC/transactions or unsandboxed fallback.
- Root owns README/REPORT/WORKLIST, inventory/cohorts, publication and monitor; each implementer owns assigned new task files only. One implementation writer, no nested agents.
- Independent source/spec/quality review and behavioral verification, complete positive terminals, exact intended failures and actual same-copy restoration. Two material per-task fix waves maximum, then root adjudication; no unresolved material finding may be presented as passing.
- Before/after every task and after H02/H04, record omitted legal path, plausible false-green explanation, independent challenge and residual assumptions. No issue quota, no widening claims from green counts.
- Existing feedback first; stop for an independently supported actual protocol/source defect. No production/SPEC/Notion edits, merge, mark-ready, deployment, sixth increment or redundant approval pause.

Historical H01 integration accepted the exact editorial b796b007/blob07912c04/
SHA53877 pair. Before H03 publication, main advanced to991e06f6/blobaf8c32cc/
SHA753d3188 with normative shared SignalService deployment/provider changes.
Independent review finds the selected historical/bounded H01–H05 scope unchanged,
not whole-SPEC equivalence. The single current tuple and taxonomy now express
reviewed scoped correspondence; canonical source/consumer pins remain unchanged.
Unknown future bytes and superseded53877 fail closed. New D01 deployment/provider
acceptance remains WAITING. This integration maintenance/tracking is not a sixth
increment; the original five deliverables and their execution scopes remain.

## Review Focus

- A helper generates keys/signs even when an outer test appears to replay public bytes: H01 must trace all setup and use exact published PoP/domain equality.
- Expected validators are reconstructed with the implementation under test: H02 uses independently derived literal identities/powers/priorities/proposer tables and actual consecutive transitions.
- A complete proof never expires or never gets replaced: H03 requires observed expiration and mixed-result refusals, distinct recapture, finality/adoption and actual resumed production.
- FI recovery looks correct only because the discarded suffix was never built: H04 requires three Produce actions, old h2 already present, settled c1, then replacement h2 and landing.
- Imported cash makes correction conservation vacuous: H05 performs actual pre-correction transfers and independently sums transfer deltas through repeated retries.

### Task 1: H01 — public-vector Registry lifecycle

**Files:** create `formal/etna/conformance/solidity/EtnaRegistryPublicReplay.t.sol`, `formal/etna/conformance/registry_public/registration.json`, `formal/etna/conformance/REGISTRY_PUBLIC.md`; only if collection needs it, add a focused module/test under `conformance/registry_public/`/`conformance/tests/`. Root owns shared source-fault catalog/runtime and attribution reporting.
**Interfaces:** consume the exact public-only fixture/source hashes from the design and actual pinned Registry source. New test contract is `EtnaRegistryPublicReplayTest`. Use existing sensitivity Forge execution with exact full test identities and JSON output, source verification and canonical cache/lock. Fresh minimal token/Inbox/proxy test setup must avoid EtnaInboxTestBase and all EtnaTestKeys helpers; actual registration validates every published digest/PoP at chain1/registry2222 before lifecycle claims.

- [x] Inspect the entire reachable setup, implementation and dependency hooks; prove no createWallet/sign/signVote path runs. Copy only approved public fields into the portable fixture and validate source/extract provenance. State public-code placement and mock Inbox snapshot as premises.
- [x] Add literal independent lifecycle/event/token/history assertions. Use minStake4, activationDelay2, exitDelay2, withdrawalDelay2. Registration at block10 activates12. Repeated activation profile: topUp4 at12, refuse13, activate14; topUp4 at15, activate17, final eff12/pending0. Liability profile: topUp12 at12, mature14 without activation, forfeit5000bps at15 gives eff0/pending8/sink8. Snapshot14 refuses confirmation; snapshot15 permits first confirmation16; repeat17 keeps16; withdraw17 refuses and18 pays8. A separate legal10000bps fixture reaches zero balance/public withdrawal. Same-block two public registrations and later mutation must preserve one checkpoint per block and immutable closed checkpoints.
- [x] Independently recompute small occupied-prefix entry roots from literal fields/canonical encoding, not current entry getters or the actual mutated hash/write helper. Check lifetime key/issued/slot identity and exact failed-call equality. Few public keys do not establish full-capacity displacement, double-sign admission or gas budgets.
- [x] Execute original/private-mutated/actual-restored actual Registry source using existing isolated Forge supervisor. Omit pending-principal forfeiture deduction or first-confirmation idempotence; require an exact raw accounting/history failure with other workload identities intact. Independent tester selects another discriminating source/missing-action control.
- [x] Independent review/behavior gates, reflection and source/hash readback before root publishes. Correct historical signing attribution without relabeling old executions as public-vector replay or weakening old tests.

### Task 2: H02 — unsigned weighted multi-height Comet transition

**Files:** create `formal/etna/conformance/comet_handover/` native module/fixtures, `formal/etna/conformance/run_comet_handover.py`, focused collector tests and `formal/etna/conformance/COMET_HANDOVER.md`. Do not modify old native modules/runners/configs.
**Interfaces:** use actual stock `state.updateState` and ValidatorSet operations in a private copy. A minimal generated exported bridge may call the actual unexported operation from a separately bound new test module, with exact generated bytes audited; it must not copy updateState logic. Avoid compiling/executing upstream test packages with unreviewed global key-generation hooks. Use existing source manifest/supervisor and canonical Go cache/lock. All original1659 entries and generated overlay files are checked before/after and same-copy restoration.

- [x] Inspect actual source and imports/hooks; select existing public B/-B/2B identities, no signing. Derive reviewed literal member/power/priority/stored-proposer tables independently BEFORE execution, with current/next/last sets, change heights and header projections.
- [x] Execute consecutive actual transitions for unchanged set, unequal-power update, add/remove, replacement and a subsequent update before prior activation. Use genesis at a nontrivial global height and at least3 subsequent heights per update; do not seed each expected intermediate state independently. Check input immutability and actual MakeBlock hashes as a separate projection.
- [x] Require all actual transition/terminal receipts; missing transition is inconclusive/failure, not safe success. Reject missing/duplicate/skipped leaves, wrong diagnostics, source/generated-input/tool drift. No round locks, >2/3 voting/commit admission, registry derivation, P2P or valid signed history claim.
- [x] Execute source faults omitting the actual priority increment and/or installing updated validators one height early; independent literal observations must discriminate their exact effects with original/restored success. Tester chooses an independent challenge.
- [x] Independent source/spec/quality and actual behavior verification, preserve older native bytes, publish and perform the first cross-task reflection before H03.

### Task 3: H03 — proof recapture after expiry and resource churn

**Files:** create `formal/etna/EtnaProofRecapture.tla`, `PROOF_RECAPTURE.md`, `configs/proof-recapture-*.cfg`. Root owns shared catalog/cohorts.
**Interfaces:** consume unchanged `EtnaProvingProgress` Capture/History/Availability/Complete/Publish/Tick/Land/Finalize/PublishAnchor/Produce, bypass only the default Setup scheduler with a reviewed additive Init. Independent raw receipts describe actual attempts/enabledness before/after; no copied Ready predicate as oracle.

- [x] Define finite resource-arrival/loss order programs with MaxHead3/MaxProduces3/MaxTime4/U2/BlobCapacity2/RefWindow1/AncestryBudget3, two jobs and existing backend identities. Preserve exact existing proof/anchor abstractions and name the shared RefWindow/maxAnchorAge reduction.
- [x] Actually produce old1/2, capture job0 at0, stagger history/backend loss and restoration, complete/publish; advance2 and attempt its otherwise-complete expired Land. Capture distinct job1 with reference2; deliberately complete one backend from old job0, otherwise complete/publish; at3 attempt/refuse mixed statement, then genuinely complete the fresh result and Land. Advance4/finalize inclusion3/adopt checkpoint2 anchor/actually Produce3.
- [x] Require complete positive terminal: immutable job0, expiry/mixed refusal, checkpoint2 landed at L1block3, finalized2, adopted anchor3, exactly-once prefix and resumed head3 without recovery. Include at least two legal resource orders; disabled required actions must lose the witness.
- [x] Actual-source omission of reference-age or backend-statement equality must execute the corresponding bad Land and violate only the dedicated independent raw audit. Baseline/mutant/actual-restored and independent extra challenge required; generic setup/type/bridge failures do not count.
- [x] Independently review/verify all affected old/new profiles, complete raw terminals and hashes, reflect on remaining history/prover/clock assumptions, then publish.

### Task 4: H04 — FI partially settled suffix, recovery and replacement

**Files:** create `formal/etna/EtnaFISuffixRecovery.tla`, `FI_SUFFIX_RECOVERY.md`, `configs/fi-suffix-recovery-*.cfg`. Root owns catalog/cohorts.
**Interfaces:** consume unchanged actual EtnaForcedInclusion actions. Preserve stage semantics and increment produces exactly as original AllFIActions; MaxProduces3 is essential, not a widened obsolete profile.

- [x] Define Fee fixture A/B with MaxHeight2/MaxProduces3/MaxGeneration1/MaxNonce2/MaxTime4/QueueBound2 and all correctness options TRUE. Program: enqueue A0, tick1, actual Produce oldh1 consumingA; enqueueB1 while L1head0/localcursor1, charge2; tick3/closedanchor2, actual Produce oldh2 consumingB; FIPrepare2/FIFresh1 settle onlyc1; authorize4 and actual FIRecover at3; tick4, Produce replacementh2 from anchor3, then FIFresh2.
- [x] Separate hash-only blank({1})/Skip and retain({})/First profiles. Full independent raw terminal requires all3 production receipts, actual recovery and2 accepted landings, retained parent(0,1), distinct old/newh2 histories, cursor/head/tail2, charges1+2/revenue3, unchanged timestamps/enqueue blocks and exactly-once L1 application. Normal original-source invariants remain present.
- [x] Remove actual cursor rewind, hash blanking or revenue preservation in private source copies, selecting discriminating focused raw audits. Record queue/attempt/terminal witnesses and omission controls. Do not sell old proof refusal as isolated generation testing: its origin/cut guards can also reject it.
- [x] Independent review, actual exact-outcome execution/raw trace audit, same-copy restoration and extra independent challenge; publish then cross-task reflection. Actual STF/resource/message scheduling correspondence remains open.

### Task 5: H05 — actual pre-correction payments and post-correction retry

**Files:** create `formal/etna/EtnaRollbackPayments.tla`, `ROLLBACK_PAYMENTS.md`, `configs/rollback-payments-*.cfg`. Root owns catalog/cohorts.
**Interfaces:** reuse unchanged `EtnaVerifierRollback` FreshGood/OwnerAuthorize/Confirm/SeedMessage/InjectedBad/OwnerTick/Withdraw/RetryAttempt/PauseBoth/Upgrade/Unpause/Reprove. Setup may vary order, not state by setter; imported baseline cash remains separately labeled.

- [ ] Replay profile, MaxHeight2/generation2/nonce4/MaxTime1: good1/authorize/confirm0/seedLegit/bad2/confirm1/seedForged, then Tick1. Actually Withdraw1 and RetryAttemptForged BEFORE PauseBoth/Upgrade; optional bounded nonce invalidation order, actual correction, unpause, reproveLegit against retained honest1 and complete its retry twice. Add a numeric-height reuse profile only through actual FreshGood2, not a synthetic store write.
- [ ] Independently sum every transfer delta from before/after actual attempts. Complete terminal requires prior forged payment/consumed escrow/completedTRUE and principal0/withdrawnTRUE survive correction; legitimate remaining escrow pays once after fresh proof, no second fee or retry payout. Expected total cash3/stakePaid2 separates imported1/1 from two actual message payouts and one actual withdrawal.
- [ ] Dedicated raw conservation/identity/nonce observers must not depend solely on overwritten last-transfer journal fields. Mutate actual Upgrade cash/escrow/completed preservation or RetryAttempt completed guard and require the intended action/state violation; do not invent a duplicate payment from a reset that alone cannot cause it. Missing required action loses the full terminal.
- [ ] Independently review/source-map and behaviorally verify original/mutant/actual-restored, extra tester challenge, old source/config preservation and honest remaining corrective-implementation boundary. Publish fifth increment, no sixth.

## Final gate

- [ ] Reconcile all five reflection records and master worklist; distinguish natural protocol candidates, verification defects and remaining premises. Do not silently close full K02/R01/P01/F01/Q02.
- [ ] Fresh exact discovered default TLC/Python gate and current new TLC cohorts; H01 public-input Forge source faults and H02 native actual original/mutant/restored. Old unchanged five Forge obligations retain historical test-key evidence and are not counted as new no-signing executions. Audit runtime/source/generated overlays/tool hashes and actual restoration.
- [ ] Independent complete-batch source review and independent raw artifact audit; review any closing prose separately. Confirm exact current PR feedback/head/CI and preserve all evidence.
- [ ] Root reviewed commit/push, issue22355/PR readback, monitor state5/5/feedback-only and final user retrospective. Keep draft/worktree/evidence; stop at five.
