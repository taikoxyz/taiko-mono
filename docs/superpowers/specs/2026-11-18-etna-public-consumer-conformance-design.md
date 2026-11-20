# Etna public-consumer conformance design

The next authorized five increments target available real consumers instead of
another five scripted abstractions. The draft remains an assurance contribution,
not a protocol implementation or a claim of production readiness. Baseline is
`a1e8a9a4384da18fd145639d82db27575aab4551`.

## Authority and boundaries

Use the existing canonical SPEC and the exact reviewed scoped correspondence in
`formal/etna/conformance/spec_correspondence.json`. Keep all current pins. Actual
contracts are commit `89f419915de4b73bb57c53bf970f6dea9e8e8c8c`; stock CometBFT is
v0.40.0, commit `0880b4d378f347ab16e54ec677ff50d803f37d62`, tree
`083ecc3cf413b6333ffe47c2b0ce1d91ce84a259`. These historical implementations do
not stand in for missing current client, EL, guest or deployment interfaces.

The published mixed `testdata/etna_vectors/vectors.json` has blob
`e069e2930143cbaf126d46532a96179764ec0ab6` and SHA256
`85d9df59bbc1709950be8cd8b248a3871523229afabd3d4e65b8027d6e4529de`.
Only an explicitly allowlisted public projection may be created. Never extract,
print, use or mount private fields or the original mixed artifact in a runner.
Existing public registration projection remains independently pinned.

No production, normative SPEC, Notion, deployment, live chain, real signing,
key generation, installation, new dependency or network fallback is authorized.
Security-specific tooling is outside scope. Use offline existing tools, exact
source manifests, isolated supervised execution, physical cache locks, output
guards and process cleanup. All local Git reads disable lazy fetch.

## N01: stock signed vote and quorum boundaries

Project the public vote key, 23 named signed cases, 14 named pairs, five chain
domains and explicit public spectator points. Preserve signed timestamp seconds
and exact uint64 two's-complement seconds separately. Freeze role-specific
structural/encoding/signature expectations before engines. Refusal by an adapter
is not refusal by the real consumer. All23 published signed rows are natively
Go-encodable: require23 byte comparisons and23 Verify positives; ValidateBasic
accepts21 and rejects exactly partial_block_id and hash_only_block_id. No
published-row exclusions are permitted. Signed seconds -1 corresponds to the
uint64 bit pattern 18446744073709551615. Separately named out-of-range controls
are not published signed positives.

Use native `crypto/secp256k1eth`, `VoteSignBytes`, `Vote.ValidateBasic`,
`Vote.Verify`, `VoteSet.AddVote`, `HeightVoteSet.AddVote/POLInfo` and full
`ValidatorSet.VerifyCommit`. Genuine public precommit A plus a distinct public
absent slot must reject power 2/3 and accept 3/4. Include a below-threshold
control. Native validators are sorted by descending power, so a separate
below-threshold profile supplies the nonzero signer index; the heavy2/3 and3/4
signer is index0. ValidateBasic and Verify are independently asserted because
VoteSet admission does not call ValidateBasic. Nil signatures verify but contribute zero
to a nonnil commit. Check duplicates, same-block new timestamp, conflicting
block, domain/address/index/height/round/type changes and genuine round1/2 POL.
One-controller majority is a synthetic API arithmetic premise, not a legal Etna
launch committee. Locks, signed proposals, finalization and P2P remain open.

Require a unique real source threshold fault, intended exact failure, original
and restored positives on one private source copy, plus an independent
behavioral challenge. Start with one genuine valid signature smoke after static
input/source review before the rest of the engine products.

## N02: Solidity bytes and real double-sign effects

Call actual `LibCometVote` functions through a minimal test harness; compare
published literal bytes and domains independently of Go. The common Go rows are
an additional comparison, never the sole oracle. Exercise all 14 evidence pairs
through actual `EtnaStakingRegistry.slashDoubleSign`, fresh state for each.

The immutable deployment domain is L1=1, L2=167001, Inbox=0x1111...1111,
Registry=0x2222...2222. Install an initialized/unlocked Inbox fixture before the
real constructor; its supplied generation is a premise. Use real proxy/init and
published PoP registration, only seeding the proxy implementation pointer.
Effective 4 plus pending 4 with bounty2500bps yields reporter2, sink6 and zero
remaining principal on success. Preserve lifetime key/ownership semantics.
Require exact raw state/cash/events and equality on refusals and repeat evidence.

Expected success pairs: precommit_conflict, precommit_vs_nil,
prevote_conflict_round_1, generation_1_conflict,
historical_generation_conflict, backdated_conflict. Expected NotDoubleSign:
same_block_later_time, different_round, different_type,
different_round_conflicting_blocks, different_generation, different_height.
FutureGeneration: future_generation. InvalidSignature: other_deployment.
Independently check these against the SPEC, not just fixture flags. A natural
source/protocol discrepancy is escalated; do not silently edit expected results.
Require one actual source-fault control and an independent challenge.

## N03: exit, pending principal, withdrawal and slot reuse

Register two distinct published keys stake4 at h10. Top-up bond0 by4 at h12
(ready14), exit at h13 (effective15); activation at14 refuses ExitAlreadySet.
At h16 snapshot14 refuses confirmation, snapshot15 succeeds. Withdraw17 refuses,
withdraw18 pays8. Lifetime key remains retired even with another owner's valid
PoP. Reuse slot0 with a distinct key at20, producing bond2 while bond1 stays in
slot1 and entryCount remains2. Preserve the earlier empty-root checkpoint: canonical hashed zero-field slot0
alongside live slot1 at count2, never an empty Registry or zero/padding root.
Then exit bond2 at23, confirm26 with snapshot25 and withdraw28 paying4; this
second cycle discriminates bond ID from slot ID. Final deposits16, payout12,
vault4. Compare independent roots/closed checkpoints, bidirectional mapping,
all selected principal/identity/cash/event words. Include source fault and
independent wrong-ID/cleanup challenge. Six public keys cannot establish full
4096-slot capacity or deployment gas feasibility.

## N04: late transfer failures and exact-call retry

Actual register writes precede safeTransferFrom. Use a valid published PoP and
insufficient allowance; compare raw pre/post state, all8192 admission index
cells, selected bonds/keys/owners/history/checkpoints, token allowance/balances
and transfer count. Externally approve and retry the identical calldata,
requiring contiguous bond IDs and exactly one transfer.
Actual topUp writes also precede safeTransferFrom. With sufficient allowance
and insufficient balance, the fixture token decrements allowance before balance
failure. Require complete rollback, then fund externally and retry identical
calldata. Pending/admission change while effective stake/history remain fixed.
Actual register \_save/\_commit emits CheckpointWritten before the failed token
transfer, while topUp/token emit after these selected failure points. Calibrate
vm.recordLogs with an emit-then-revert control; retained reverted trace entries
are allowed and must be labeled accurately. Do not claim these traces are
committed receipt logs or require failed registration trace to be empty. Require
complete state/cash/allowance rollback independently of that observer. Capture
the actual nested token target/calldata and low-level refusal bytes with ordered
AccountAccess or equivalent trace, bracketed around the call rather than the
raw-state observation loops. Positive retry events are exactly
CheckpointWritten, Transfer, Registered. Require real source fault, exact diagnostic and restoration,
plus independent challenge. Withdraw transfer failure, callbacks and production
token behavior are deferred premises, not simulated successes.

## N05: complete archived-search disposition acceptance

Inventory every one of the 19 archived INCONCLUSIVE configurations: signer2,
Registry4, FI9, initial proving3, rollback1. Bind exact current file identity and
historical source/version (including transitive local model imports), name the
omitted dimension/property, identify what
current evidence actually covers, and retain a specific C01/R01/F01/P01/Q02
remaining obligation. Independently assess semantic reductions and old-version
hazards. This can close X01 (disposition audit) only. All19 retain INCONCLUSIVE;
no old graph is reclassified PASS or claimed exhausted. This is a substantive
acceptance artifact, not routine planning/index maintenance.

## Acceptance and final gate

Preserve all baseline executable/model/config bytes. New real-consumer controls
remain separately attributed from the historical shared80 mutation inventory.
Each new runner rejects missing/extra/duplicate cases, unrelated failures,
timeouts, setup failures, skips and source drift. Retain raw failed execution,
independent literal oracles and successful restoration, not only green totals.
Independent source review and independent behavior/artifact verification are
required. Maximum two material review/fix rounds, then root adjudication; no
unresolved material in-scope issue is published as ready. Final review covers
the complete new diff, source hashes and fresh affected regressions. Complete
exactly five and return to hourly feedback-only monitoring.
