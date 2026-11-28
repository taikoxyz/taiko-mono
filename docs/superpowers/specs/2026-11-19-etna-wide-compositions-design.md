# Etna current-rule and wider-composition verification

The user directly authorized a new group of SEVEN after completed O01-O05, with
wider behavioral scope and continued reflection on why checks miss defects.
Continue the established independent implementation/source/behavior workflow and
publish reviewed work to the existing draft. No separate design conversation or
external-review wait is needed for this continuation. The baseline is
116cb2e3974f74fc4ec2f298aa8643f630f75bf4; old batches remain complete.

## Source and purpose

Live main is 2e6763e21bc236cfcda6011d164b32040f9e0c8d (#22412), not the PR's
baseRefOid. Its SPEC blob is 98e209c3a7781c690338751b451fe10852f00b7c, SHA256
b331b3af7b42a4645ebe3e2b4f42e912e33508893a091c3c3c289c8fdbd53a70.
Compared with reviewed9c832234, it removes displacement and fixed landing grids,
and moves validator-state authentication into the application's appHash.
These are normative changes, not editorial correspondence. First make the
version/consumer boundaries explicit; then test selected new-rule behavior.
Historical source d18357214fab30ea512ae9858a11699806d72ba1, Comet
0880b4d378f347ab16e54ec677ff50d803f37d62 and contracts
89f419915de4b73bb57c53bf970f6dea9e8e8c8c retain their identities and evidence.
No old execution is relabeled as a new-rule or new-checker execution.

## Approach and alternatives

More old scripted cases would retain old scheduling and observer assumptions;
raising bounds alone would also test removed rules. Waiting for a complete new
client/guest/Registry would prevent feasible source/model/public-API work.
The chosen approach is explicit current-source classification, new versioned
operational models for changed rules, and real stock public-input APIs where the
interface already exists. All seven outputs are separately rejectable review
units, not seven names for one test campaign.

## Seven selected outputs

1. W01: exact new-SPEC/ACCEPTANCE/SWITCH delta and consumer boundary inventory;
   current versus historical evidence classification, strict future-byte refusal,
   and effective-merge validation without blanket semantic equivalence.
2. W02: current lowest-empty-slot admission and free bond lifecycle, occupied-zero
   preservation, atomic full refusal, delayed withdrawal and repeated reuse.
3. W03: finite closed-supply capacity/recycling and stalled-release composition;
   separate exact 4096-slot/10^27 integer deployment inequality.
4. W04: real per-height Comet validator arithmetic versus sparse store lookup,
   current valStateHash/appHash encoding and selected stock acceptance/Bootstrap.
5. W05: actual framed signer transport, public cached FilePV replies, explicit
   remote refusal versus bounded transport retries/cancellation.
6. W06: arbitrary-height proof/landing with live origin capture, actual recovery,
   old job/resource retention or refusal, and a fresh-generation landing.
7. W07: current timestamp-only planned stop, terminal-height settlement, nonzero
   rules recovery and fresh first block/landing, with free scheduling interleavings.

## Binding constraints

- Exactly seven W01-W07 plus final gates; never restart completed batches or start an eighth automatically.
- Formal/test tooling and associated reports only; no production/SPEC/Notion/live transactions, merge/ready, signing keys, new signing or dependency installation.
- One implementation writer at a time. Root owns shared REPORT/WORKLIST/README, plan/ledger, monitor and publication. Read-only reconnaissance/review may run independently.
- Preserve historical module/config/fixture/source bytes and retained raw artifacts. Add distinctly named current-rule models; source-version mismatches remain explicit.
- Only managed Python and existing pinned offline Go/Forge/TLC tools/caches. Inspect entrypoints; isolated execution has no Git/secrets/network, RO inputs and disposable RW outputs.
- No native/TLC engine before root approves exact interfaces, observations, source/tool/input hashes, argv and budgets. Smoke precedes full GO; no watched-input edits during guards.
- Independent adversarial source review and independent behavioral verification before publication; at most two material fix rounds per gate and one consolidated final repair wave.
- Every selected claim needs actual reachable positive progress, a precise intended-failure control and same-copy source restoration. Missing input/timeout/panic/skip/setup failures are INCONCLUSIVE, not semantic detections.
- Observe attempted inputs and every relevant state/output field independently; also corrupt expected metadata with actual execution unchanged. Expected values must not choose the execution scheduler.
- Queue zero is required for exhaustive safety PASS; named counterexamples establish reachability only. Resource reductions must disclose the omitted dimension and preserve the selected claim.
- Historical native signatures remain public projections only. Never load mixed/private fixture artifacts, call key loaders, advance cached SignVote to new signing, or invoke upstream test globals.
- Initial per-profile TLC ceiling300s; native Go90s/isolation100s/supervisor110s/outer120s. Any changed budget needs a ledger ruling and a new frozen packet, never an unbounded retry.
- A supported actual protocol/source defect stops for discussion; checker defects are repaired separately without inventing a protocol finding.

## Required observations and boundaries

W01 preserves the legacy three-argument single-SPEC guard unchanged, including
its refusal of2e6763 bytes. A separate exact three-document bundle classifier
checks byte lengths/Git blobs/SHA256 and rejects partial/mixed/unknown bundles.
A distinct closed consumer+claim selector binds historical evidence authority and
current disposition at the actual runner receipt, not only in a side inventory.
Changing/switching/dropping valid metadata rows cannot upgrade an old execution.
Registry must never inherit a signed-vote claim selector. Source identity review
and historical-only/current-model/selected-public-operation/WAITING are separate.
W01 binds exact three-document bytes and amended clause IDs, names each affected
model/export/native consumer, and distinguishes source review from conformance.
Unknown current bytes and pin-only identity/coverage corruption must reject.
Changed Registry/import/grid consumers cannot keep unqualified current labels.
Old defaults may run as historical regression; current cases carry their own
reviewed source identity. Current implementation/deployment rows stay WAITING.

W02 uses initially two slots/four lifetime identities, bounded time1..8 and
funded-call premises. Presence, not balance or exit, controls admission. Include
zero occupied lower slot plus higher vacancy, two holes, all-held zero/pending
states, no key/ID/cash consumption on refusal, full confirmation/delay and public
zero withdrawal. Do not infer global supply reachability from funded calls.

W03 closes the supply ledger: liquid, held/pending principal, reporter and sink
sum to a fixed total. For4096 slots the minimum valid base-unit stake is
244140625000000000000001; equality244140625000000000000000 rejects. Full
occupancy is possible after penalized-token recycling, including reporter-only
recycling without sink return. A normalized supply7/min4 example has held-zero A,
sink3, live B4 and both slots full. Recovery alone cannot advance the confirmation
snapshot. A real covering landing, delay and withdrawal are needed to free A.
Models do not establish live token/constructor configuration or4096 gas costs.

W04 must search for a genesis/update-reachable sparse-lookup discriminator with a
bounded independent integer search (at most4096 programs, four public members,
16 steps), then freeze/replay any found witness with stock MakeGenesisState/updateState.
An exhausted search leaves that claim OPEN and earns no witness credit.
Arbitrary injected priorities cannot count as reachable history. Compare all
members/order/power/priority/stored-proposer fields, not Merkle hashes alone.
ENC-A-29a uses six ABI heads and two four-word-entry arrays;29b is three words.
Compare Python Keccak and native Go SHA3 implementations over complete observed
bytes. Header(s).AppHash authenticates pre-s state; post-s installed AppHash is
a different derived value. Real Etna app/EL/import producer remains WAITING.

W05 uses net.Pipe/finite in-memory listener with actual stock endpoint framing,
SignerClient/RetrySignerClient/SignerServer and freshly decoded cached FilePV.
RemoteSignerError ends automatic retry immediately; transport failures have a
finite retry count, deadlines and cancellation. At most10 episodes/retries3;
three retries means three total attempts; all conflict controls use safe prevotes,
never non-nil precommit extension signing. Shortened deadlines are labeled, not
production5s latency evidence. Capture
actual wire attempts/responses, unchanged HRS/disk and public signature validity.
No trust-session authentication, supervisor/WAL or failover claim follows.

W06/W07 keep actual actions operational and observers separate. W06 starts with
small unit heights and at most two immutable job slots; reserve a fresh slot for
post-recovery capture rather than claiming three simultaneous jobs. W07 must not
inherit the removed stopGrid/K premises: implement a separately named timestamp
schedule engine. W06 also needs a separately versioned four-word height/EL/Comet/FI cut adapter and
non-grid schema; validator state/appHash stays outside the proof statement.
Its fixed immutable long-range companion must remain admissible through successful
shortest competing landings while c<h, with every interior c reachable and h-c
strictly decreasing, under fixed required resources/reference.
W06 additionally has a distinct two-old-job overlap profile, without reserving
its second slot: capture long and short, land short, refuse suffix-only data,
then land the unchanged long proof with full original data. Recovery and overlap
are separate profiles, never simultaneous three-job evidence. The four-field cut
is consumed by actual capture/proof binding/Land; interior list ordering, empty
one-block interior and zero-based c-p-1 lookup are independently checked.
W07 implements expected generation/checkpoint/nonce/deadline transaction guards
and actual R on the authoritative schedule/frontier state; it cannot infer those
guards or stop clearing from W06/M07 trusted completed-recovery macro. Each
covered block keeps its own historical-anchor schedule; fresh EL and BFT times
are separate and the procedural planned-stop prerequisite is not invented as a
general contractual recover guard.
Both need full PRE/POST frames, two-way enabledness, boundary
witnesses and different author/independent source faults. Missing concrete STF,
prover, node/guest/recovery implementations remain WAITING.

## Completion

Each task ends in reviewed code and exact raw attribution/restoration, focused
ordinary checks and root-owned report/worklist status. Final review covers the
entire116cb2e39-to-final range with the most capable source reviewer and a
separate behavioral/raw auditor. Recheck current PR/main/merge-result bytes,
relevant CI and body readbacks; preserve all evidence and return feedback-only.
Selected seven completion is not overall protocol completion or coverage percent.
