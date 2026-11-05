# Etna checkpoint import and Rust client conformance

Status: approved by the user on 2026-11-06; implementation in progress.

## Intent and agreed scope

Update PR #22280 so a validator or full node can join an existing Etna generation
from a landed checkpoint using the bounded consensus window in #22338, rather
than replaying the generation from its origin. Also fix other inconsistencies
within the Rust client's existing supported scope against the current Etna design.

The user explicitly excludes the Unzen switch and public EL snapshot tooling.
Retain support for fresh S=0 deployments and their governance recoveries.
Public snapshot download, export, hosting, rotation and EL-only serving are outside
this update. Local EL state verification and canonical-header installation
necessary for app import are inside it; a header-only RPC check is insufficient.

Real proving guests, contract/governance implementation, launch economics and
production deployment are separate components. Preserve the explicit dummy-proof
development restriction. Do not change the protocol design to fit the client or
claim production acceptance from host/client tests.

## Verified baseline

- Specification: main `589b542de790861efd8b4d9bb0a4b1d066c2685f`, #22338's merge.
  Read SPEC.md together with its rule vectors and ACCEPTANCE.md.
- Client: #22280 `91bb1b8d89fa79968ed7306d9bc55124e432fe8f`,
  branch `feat/taiko-client-rs-abci`.
- Already implemented: landed validator-state commitment; five-word cut leaf,
  23-word statement, nine-field LandInput and four-word landing record;
  stock proposer-priority arithmetic and stored proposers; lander state replay;
  validator-state comparison at checkpoint trust.
- Missing: checkpoint-import command and stock-store writer. The README explicitly
  defers import. The existing Go module pins unmodified CometBFT v0.40.0 and
  includes a read-only store inspector.
- Pinned protocol fixtures: `b6e765b0fd186f67fa360d4572bea2a8d701e7cb`.
  Pinned EL: alethia-reth `6ac93d4b38e1cd72b993cef1ed1dc2cb0affa7b4`.
- Existing app schemas: 17/18; lander journal: 16. Never implicitly migrate signed
  journals, existing app stores or signer HRS.

## Required behavior

### Authenticate the starting boundary

Authenticate deployment identity, current generation, its fixed origin o and
immutable genesis, and s's retained landing on the selected settled history from
the own finalized L1. Reject unlanded grid points and discarded/other-generation
checkpoints. An older retained checkpoint in the current generation is allowed;
the latest finalized checkpoint remains the session's admission target.

For s=o, use existing fixed-genesis initialization/recovery. Do not use an
origin record's older-generation Comet hash or validator state as the new
generation's parent. For s>o, require original chain_id and InitialHeight and
the landed EL/Comet hashes, FI cursor and validator-state hash. Never make a new
same-domain genesis with InitialHeight=s+1.

### Authenticate the bounded window

Compute and independently verify the shortest (w,s] required by DATA-5.4-2:

- Cover all evidence heights stock Comet still accepts at s+1. Evidence expires
  only when both 100,000 blocks and 48 h are exceeded. Use stock height/time
  semantics: the evidence verifier evaluating s+1 reads committed post-s
  State.LastBlockHeight and State.LastBlockTime. Do not use wall-clock age,
  a guessed successor time or a fixed 100,000-block suffix.
- Include S(t), and D(t) when above o, selecting committees signing s+1 and s+2.
  A derivation parent at/below o uses authenticated origin/header context.
- Include the latest height at/below s carrying an anchor witness. Never w<o.

Verify original Comet bytes, full BlockIDs/part sets, hash/LastBlockID chains,
DataHash, original envelopes, linked EL headers and each window height's own
commit. Every supplied height's validator keys/powers must hash to its
validators_hash. Do not derive historical committees selected before w.
Independently derive only the committees signing s+1/s+2 under section 4.3,
including S(t)'s proof root, D(t)'s committed anchor and recovery's R floor.
Apply non-execution checks needed for inherited anchors, rules and metadata.

Authenticate window evidence and w+1's LastCommit as block bytes; do not run
historical stock block/evidence revalidation, which can require history below w.
Do not fetch pre-window consensus blocks, execute pre-s EL blocks, run pre-s FI
counterfactual trials or call normal FinalizeBlock for them. Only boundary
context expressly required by 5.3/5.4 may be outside the consensus window.

### Reconstruct the exact post-s state

Strictly decode the landed validator-state preimage. Check height, canonical
ordering, key/power bounds, priorities and stored-proposer indexes.
Require the s+1 set to hash to header(s).next_validators_hash, and both future
sets' keys/powers to equal the independently derived committees. Do not trust
RPC priorities or guess proposers from priorities.

Restore app active/pending committees, inherited anchor/witness context,
FI cursor and generation/rules context. Persist the terminal Comet ID and
landed validator state through interfaces used by trust and the lander.
Retain the first FI trial's state and checkpoint ancestry context.

Use unmodified CometBFT's pinned Go types/APIs in an offline helper:

- Save the window's blocks, their successor LastCommits and s's verified terminal
  commit using stock block-store semantics.
- Rebuild historical validator/consensus-param records for every required lookup,
  including full sets at change/periodic checkpoint heights. Priorities through
  s are not consensus inputs.
- Rebuild committed-evidence markers from authenticated evidence lists without
  revalidating them. Pending evidence may start empty. New evidence uses stock
  validation after import.
- Install LastBlockHeight=s, full BlockID/time(s), LastValidators for s,
  landed Validators for s+1 and NextValidators for s+2. Store all three sets
  in full. LastHeightValidatorsChanged=s+2 and
  LastHeightConsensusParamsChanged=s+1.
- Preserve original chain_id, InitialHeight, consensus params and app version.
  AppHash and ABCI Info.LastBlockAppHash are ELHash(s). LastResultsHash derives
  from the fixed single ExecTxResult, not an invented empty result.
  header(s).AppHash is ELHash(s-1), not the installed app hash.

No s+1/s+2 block is required to complete import. Never copy peer databases or
fork CometBFT.

### Prepare the local EL

Input is a complete offline local EL state dataset at s obtained independently;
there is no public snapshot acquisition/distribution feature in this update.
The import adapter verifies actual accounts/storage/code against the authenticated
stateRoot and checks/rebuilds derived indexes through the pinned EL database
types. Checksums, metadata, an existing trie root or an RPC header alone cannot
authenticate the imported state.

Install authenticated EL headers max(o,s-U+1)..s, plus any earlier context
required by 5.3, into the EL's canonical number/hash and header-by-hash indexes.
Use a narrowly scoped local helper built against pinned EL libraries; keep heavy
database dependencies outside consensus validation.

After restart, normal forkchoice must resolve and accept a proven checkpoint
q<s, including s-q>255 when U permits. Never substitute s/zero for its finalized
hash or keep headers only in an app sidecar. Preserve s's state and parent states
of executed post-s blocks for FI trial/replay. Imported state is not independent
pre-s execution evidence for bad-landing monitoring or governance recovery.

### Publish a durable installation boundary and resume normally

Operate offline with the signer disconnected, into fresh EL/app/Comet/evidence
destinations. Reuse existing ownership/lease rules; refuse live/ambiguous owners,
aliases and non-fresh destinations. Do not overwrite a live validator installation,
its WAL, registered keys or HRS.

Stage and fsync all stores and directories, then publish one completion manifest
binding the import identity, authenticated generation/checkpoint, store paths/
identities and helper versions. Startup paths reject partial/mixed installations.
The manifest coordinates durable publication; it does not authenticate peer data.
After a crash, reverify/resume the same staging or discard only its own staging.
Reauthenticate generation before admission; a superseded generation cannot join.

Start stock P2P at s+1 and normal FinalizeBlock from there. Import completion
remains untrusted; both older and latest imported checkpoints must satisfy the
session's latest own-finalized-L1 EL/Comet/validator-state target before trust,
signing or trusted public service. Preserve all registered keys and per-chain HRS
outside imported stores. Packages contain no key, signer state, WAL or authority
lease. Import does not repair uncertain/lost signing history.

### Preserve failure classifications

- Missing material/source/finality: incomplete and untrusted; retry without
  advancing installation or admission.
- Invalid peer/publisher bytes, DataHash or preimage hash: reject candidate.
- After L1/Comet hash/DataHash authenticate the terminal envelope, an execution
  hash contradicting the same landing record is an authenticated contradiction.
  A hash-matching preimage contradicting next_validators_hash or independently
  derived committees is also an authenticated contradiction. Durably safety-halt
  and alert rather than reject/retry a publisher.
- Preserve section 9 own-L1/EL safety handling. Missing local target validator
  state waits; its verified mismatch keeps validator_state_mismatch halt behavior.

## Proposed implementation choices

These are implementer proposals, not additional requirements from the user.

- A thin `taiko-client abci-import` CLI with export/prepare/install/status.
  Deterministic verification/reconstruction lives in the ABCI crate; lifecycle
  orchestration lives at the CLI.
- A versioned streaming package of original consensus bytes, per-height sets,
  witnesses, fixed genesis/origin and terminal preimage. Hashes detect corruption,
  never authority. Bound resources without shortening the necessary window.
- A consensus/app-import package exporter using existing block/archive sources,
  not a public EL snapshot exporter. Packages must remain obtainable after source
  apps prune local sidecars; preserve an archive path for required preimages.
- A stock-store helper beside the existing inspector in the pinned Go module.
  A separate local EL verifier/header installer uses pinned EL database libraries.
- Typed durable status and startup guards shared with existing supervisor/
  recovery ownership. Offline status never authorizes signing.
- Reuse existing native block/commit and witness verification where practical.
  Change the implemented validator-state/lander path only when a meaningful
  conformance regression demonstrates a defect.

The builder may settle filenames, framing, helper boundaries and new schema
numbers without changing these contracts or adding implicit migrations.

## Other conformance gaps

Audit all applicable client rules in SPEC sections 3-11, appendices A/B,
ANCHORLESS and current rule vectors. Record the code path and meaningful
validation for each applicable rule. Distinguish implemented/tested behavior,
confirmed defects, deliberate exclusions and unverified operational acceptance.
Fix confirmed in-scope discrepancies with behavioral regressions.
Historical model vectors cannot by themselves certify current semantics.
The agreed Unzen/public-snapshot exclusions do not exclude other client defects.

## Acceptance and completion

1. Differential import against independent full replay at ordinary heights,
   S(t), S(t)+1, H(t), and recovery boundaries. Compare app metadata, stock stores,
   future sets/priorities/stored proposers and actual later-round proposers.
2. Test bad candidates versus authenticated contradictions, generation changes,
   older/latest checkpoints, unknown rules, no successor-block requirement and
   absence of pre-window consensus reads/pre-s execution/FI trials. Instrument
   sources so forbidden operations fail the test.
3. Real stock evidence validation at s+1, repeated committed evidence, evidence
   inside w+1 pointing below w, its LastCommit boundary, exact expiry equalities,
   and validator-store change/periodic checkpoint boundaries.
4. Pinned EL account/storage/code tampering and canonical-index installation;
   next-block base fee/BLOCKHASH; a first post-s checkpoint more than 255 headers
   old before/after restart; first FI skip and later cold replay; non-retryable
   missing-parent-state safety halt.
5. Crashes at every store/publication boundary; mixed/live stores refused;
   HRS preservation and rollback/copied/lost-HRS rejection; stock P2P, subsequent
   landing and normal consensus from latest and older import points.
6. Export/archive availability after sidecar pruning; archived full history still
   supports fixed-origin replay. This is app-import availability, not a public
   EL snapshot service.
7. Increasing prefix lengths with the same required window: bound consensus
   reads/cost and record tested heights/window, bytes, authentication/EL-index
   times, memory/disk and interrupted-import timing. Do not claim unmeasured
   deployment budgets or completeness of unrelated launch acceptance.

Run the mandatory final `just verify`: signer/supervisor, formatting/docs/Clippy,
unit tests, artifact reproduction and full Docker tier with the new scenarios.
Update package/operator docs and #22280 with the final commit, exact validation
and explicit exclusions. Leave the source specification unchanged. Do not merge
or deploy.
