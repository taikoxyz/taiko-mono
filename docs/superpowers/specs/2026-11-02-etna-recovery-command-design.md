# Etna governance recovery command

Status: proposed for approval. Design only; no runtime implementation yet.

## Intent and agreed direction

Update public PR #22280 so an existing Etna deployment can start the generation
created by governance recover, produce blocks, and land a batch from that
generation. The user selected a dedicated command with an operator-triggered
switch. Proposed operations are prepare, activate and status.

Implementation choices identified as builder calls are recommendations, not
additional user requirements.

## Sources and authority

- PR #22280 head: bce302828c2c35476726d271a3741e6eec0e2a6a.
- Its protocol fixture revision: 1b14b634c8d213b5b30d8fc61ca6f6dcec344389.
- Etna SPEC and ACCEPTANCE, including #22327 at
  b9f3eb367ddde8d1566d2417fcaa1b84917e8bd8: SPEC 3.4, 4.3, 6.1/6.2,
  8.1-8.4, 9/9.1; ACCEPTANCE 2 and relevant shared vectors.
- Stock CometBFT v0.40.0. Context7 documentation was consulted and the handshake
  and FilePV behavior checked against consensus/replay.go and privval/file.go at
  that exact upstream tag.
- Pinned alethia-reth 6ac93d4b38e1cd72b993cef1ed1dc2cb0affa7b4,
  docs/engine-api-etna.md: canonical-ancestor FCU is VALID without moving head;
  with attributes it still builds on that ancestor.

Recheck the public PR head and applicable specification before implementation;
record newer applicable changes explicitly. Implement protocol rules without
amending them.

## Scope and delivery boundaries

Deliver recovery genesis/witness authentication; origin-aware app initialization,
replay, trust and scheduling; durable signer state per full chain ID; generation
aware supervisor behavior; lander recovery origins and transaction reconciliation;
the operator command; documentation and end-to-end recovery tests.

Support validators, unregistered full nodes and the independently operated lander.
Reuse registered keys, the EL, existing cryptographic verification, native signer
and stock Comet. Each key has one authoritative private state location and owner.

Builder call: require usable local EL state at the fixed recovery origin c and
the pinned EL's ancestor/history prerequisites. Report missing data precisely.
The full snapshot verifier/app importer from #22327 is separate work and may
later supply these prerequisites.

Retain the existing ProofProvider boundary and explicit dummy/MockVerifier mode
for disposable tests. This increment verifies recovery operation, not the real
two-proof production acceptance gate. It does not implement guests or a real
proving backend, Unzen migration, verifier-failure rollback, upgrade activation,
automatic DAO authorization, remote fleet management or nonce replacement.

## Command and storage

Builder call: add taiko-client abci-recover prepare, activate and status. These
are proposed interfaces. Generation-zero commands/formats stay supported without
rewriting existing app data or signed journals.

A private recovery root contains a versioned profile, immutable authenticated
plan, operation journal, fresh per-generation app/Comet directories and runtime
observations. Retain old directories/WAL/history/evidence. Keep signer key and
authority files outside all Comet mounts and out of the public plan.

The profile explicitly names deployment, own L1, EL endpoints/JWT, role, existing
signer paths when applicable, peers, executable argv and optional lander config.
Printed reports omit credentials. Never infer process ownership from names/ports.

### Prepare

1. Bind an explicitly requested target generation. Authenticate the current
   generation and its fixed origin (c, R, R.timestamp) from own finalized L1.
   Reject zero, superseded/missing origins and deployment/config contradictions.
2. Authenticate c's retained landing record, EL hash, stateRoot via its verified
   EL header, old-generation Comet hash and FI cursor. Authenticate R's canonical
   finalized header and complete registry snapshot. Independently derive the
   initial committee including exclusions and all candidates eligible at R.
   Logs and supplied files are discovery aids, never authority.
3. Check identity, config, encoding/width/power bounds and EL header/ancestors.
   Use nonmutating historical state reads for preliminary state availability.
   Headers alone cannot establish usable state. The actual stateful Engine build
   probe is deferred until activation has fenced old writers, because the build
   interface may also update forkchoice. Report that pending activation check in
   the plan. Prepare never changes forkchoice, the EL database, active directories,
   signer authority/files or process configuration.
4. Stage the unique new genesis and fresh configuration/directories. Record
   generation/domain, c/R, committee/config identities, software versions,
   directory paths and latest-checkpoint observation in an immutable plan.
5. Fsync and publish a content-addressed plan and summary: what will start, the
   suffix above c discarded by recovery, committee, signer identity, pending
   lander work and missing prerequisites. An incomplete check grants no startup
   or signing authority. Identical prepare retries are idempotent; changed facts
   create a new plan, never overwrite an active operation.

### Activate

The operator selects an exact prepared plan. Reauthenticate its deployment,
current generation and origin before mutation and after acquiring exclusive
ownership. Check prerequisites again. Same-generation checkpoint advancement
updates the trust target, not genesis; a new generation invalidates the plan.

Use durable phases: prepared -> stopping -> isolated -> EL-origin-ready -> installed ->
running -> trusted -> settled. A phase record does not replace inspecting actual
process/store/EL facts on every resume.

- Stop/reap old Comet before its signer, then old app. Stop the old lander before
  sharing its account/journal. Acquire deployment/key/EL ownership before mutation.
- Builder call: stop processes in this command's owned process group. Existing
  systemd/Kubernetes/external services must be stopped by their controller or
  operator first; check participating locks and refuse uncertain ownership. Add
  the same ownership contract to supported startup paths. No Kubernetes API or
  arbitrary stop hooks. Never kill unrelated processes using a bare PID.
- Once old writers are fenced, verify c's header/ancestors and perform the
  stateful Engine build probe against c without promoting its candidate.
  Builder call: keep the canonical-header unwind option disabled. On the pinned
  EL an ancestor FCU can return VALID and build on c while leaving the old head
  above c. Therefore EL-origin-ready means verified usable c state, not a rewind
  of eth_blockNumber. Verify the existing finalized boundary is consistent with
  ordinary recovery and does not require rolling back settlement beyond c.
- The first committed recovered block at c+1 follows normal newPayload and FCU
  promotion with the anchor-proven finalized checkpoint. Its different generation
  header creates the replacement branch and causes canonical reorganization of
  the discarded suffix. Verify the actual canonical header matches that Commit
  and survives restart. Keep public traffic outside this transition until new
  canonical progress/readiness is verified. Do not mistake a pre-commit old EL
  head for the new app's committed head, or require it to disappear in preflight.
  State availability is required before signing. Contradictory Engine answers
  halt; no raw DB edits or temporary unsafe flag are part of this workflow.
- Fsync the verified new bundle before atomically publishing one active-generation
  descriptor. Readers reject incomplete/mixed directories.
- Start app/EL connectivity, then guarded signer and stock Comet with the existing
  first-start handshake. Signer remains closed until trust passes. Full nodes use
  an unregistered identity. Start the optional lander with its ownership/journal
  checks satisfied; it may wait on old-account nonce reconciliation.
- Observe current-session trust, new-generation commits, and a canonical finalized
  L1 landing above c. Only then report settled. Another honest lander may advance
  settlement; tests also demonstrate the recovered lander submits successfully.

Builder call: activate stays in the foreground as local process owner; external
controllers may supervise it. On cancellation, stop only owned children in the
safe order and retain all journals. No daemon installer is added.

### Status and interrupted activation

Report plan ID, generation, c/R, phase, component state, trust target, committed
height, landed/finalized height and actionable waiting reason. Local progress,
signature authorization and settlement are distinct observations.

Retrying the same activation resumes by checking durable records against real
state. Reject competing plans, live ownership, incompatible formats, mixed stores
and inconsistent completed phases. After publishing the new active generation,
failure leaves it stopped/waiting and resumable; never automatically reopen old
signers or roll back signing authority.

L1 lag/timeouts, missing witnesses/state and unavailable quorum cannot grant
trust. Preserve safety evidence and durable halt latches. The explicit recovery
plan acknowledges an expected superseded-generation transition only. An
independent prior safety halt requires documented manual investigation/repair;
routine recovery does not clear that evidence or its latch.

## Origin-aware app and consensus

Keep immutable deployment genesis separate from verified generation origin.
Recovery genesis uses the new full chain_id, initial_height=c+1,
genesis_time=R.timestamp and app_hash=ELHash(c). Derive validators at R with
targetEpoch=floor(c/L). InitChain independently verifies all witnesses, finality,
domain/config, representable consensus parameters, members and EL origin state.

After InitChain the logical EL boundary is c. Before any new-generation Commit,
Info reports height 0 and the stock empty pre-commit app hash so an empty stock
Comet store can handshake/re-send InitChain. InitChain itself returns ELHash(c).
After first Commit, Info reports actual global height/EL hash. Persist the
distinction; repeated InitChain and app-only/Comet-only restarts are idempotent.

The first block at c+1 has empty LastBlockID/LastCommit. The landing record's old
Comet hash at c remains an authenticated trust/proving boundary, not a fabricated
new-generation block/parent. Trust handles that origin case explicitly and then
checks current-generation committed Comet hashes at later checkpoint targets.

The first block must carry a finalized anchor witness no earlier than R, even
when c's EL header has an old-generation anchor. New-generation roots obey that
R floor. Start FI from c's authenticated landing cursor and keep ordinary
include/skip/blanking behavior.

Keep global epoch H(t)=1+t\*L and global K grid. The R-selected initial committee
acts at c+1; discard old pending updates. Apply the next S(t) actually occurring
in the new generation, including c+1=S(t); normal H+2 follows. When D(t) is in the
old prefix, select snapshot max(the committed D(t) anchor, R) and verify under
S(t)'s own anchor root. Retain the authenticated prefix context needed for D(t).

If another node has landed past c before startup, replay from the same fixed
origin to the session's latest finalized-L1 target and match both hashes before
trust/signing. A later checkpoint never becomes a new same-domain genesis.

Builder call: keep generation-zero structures readable without rewriting them;
fresh recovery directories use an explicitly versioned origin/witness format.
Exact Rust types/schema are builder details. Reject incompatible formats.

## Private signer authority

FilePV HRS is not independently namespaced by chain_id. Add a private
deployment/key authority registry with one stock FilePV state per full chain_id,
retaining the original registered key and every old state file.

Builder call: explicitly enroll the existing generation-zero state path once,
after activation has fenced the old signer, without copying/rewriting its HRS.
Check its native key identity and, when present, canonical signed-byte domain
against the original generation-zero deployment. Record a durable enrollment
marker at that original state location. Missing previously initialized authority metadata is an error,
not permission to enroll again. These markers/registry are authoritative signer
state, kept outside app/Comet recovery roots and preserved on every restart.

Hold a deployment/key-wide ownership lock as well as the active state lock.
Authenticated newer generations advance a private durable generation watermark;
old domains remain refused after restart. The signer owns this watermark, not
the public plan or app alone. Avoid path aliases creating parallel owners.

Only an explicit authenticated new-domain transition can exclusively create its
initial stock HRS file. Fsync state creation, manifest enrollment and watermark
before any signature. Resume enrolled files; missing/uncertain enrolled HRS never
creates replacement state. Specify crash recovery for interrupted first
enrollment, with no signing until authority is durably complete. No old HRS is
zeroed, lowered or restored from a snapshot. A prepared plan is never the
authority for this transition: the signer requires the independently verifying
app's private current-session recovery/genesis/checkpoint authentication. Allow
PubKey/Ping and Comet's initial handshake while the new domain is staged, without
creating an enrolled replacement HRS or signing. Complete new-domain authority
before its first signature, after private authorization is available.

Every signature/retry/nil vote still uses the fresh private session trust gate
and stock FilePV persistence. Supervisor checks the authenticated configured
generation instead of literal zero. Its same-generation trust-loss restart is
separate from explicit generation activation. Lost/uncertain authority and prior
safety halts require operator investigation, not genesis/plan reimport.

## Lander

Authenticate fixed origin and current checkpoint independently. At proof origin
p=c equal to the recovery origin, use the retained old Comet hash as boundary,
R's initial committee and R-or-later anchor context. Do not require c's header to
encode the new generation. Beyond that origin, use ordinary current-generation
header/commit/committee checks. Support epoch-crossing batches, overlapping
landings and the generation's R-to-reference ancestry.

Preserve the existing account-wide transaction journal and nonce ownership.
A fresh app/Comet directory never authorizes a fresh Ethereum nonce sequence.
Reconcile possibly broadcast old transactions by original immutable signed bytes,
canonical receipts and account nonce. Never replace/recycle an uncertain nonce.
Retire unsent obsolete work only through the normal verified journal transition.

Unresolved old transactions leave the lander waiting and sending no new job from
that account. Node production may proceed, but status is not settled until a
landing finalizes. An operator may explicitly configure a different funded
account and independent journal; no automatic account rotation.

## Validation

Unit/process tests cover origin/witness authentication, latest-target distinction,
global scheduling/grid, first/repeated InitChain/Info, trust sessions, private
authority enrollment, ownership, durable resume and redacted status/errors.
Reject unfinalized/stale/superseded plans, changed origin/config/committee/FI,
missing state and contradictory L1/EL evidence.

Docker tests use real pinned Etna contracts and stock native-key Comet:

- Produce both settled and later unlanded old-generation blocks; execute actual
  recover with empty lists, exclusions, FI blanking and combined lists. Run the
  command, produce at c+1 and have the recovered lander submit a finalized
  new-generation landing with the explicit test verifier.
- Demonstrate excluded/standby members, removal of old pending sets and normal
  H+2 rotation. Cover c=D(t), c=S(t), c=H(t)-1 where grid-compatible, c+1=S(t),
  repeated recovery at the same c, c=0 and joining after a later landing.
- Check empty first LastCommit, old origin Comet boundary, R floor, old-prefix
  D(t), FI cursor/first trial, overlapping jobs and old-account pending nonces.
- With the pinned EL's unwind option disabled, demonstrate building on c while
  its old canonical head remains above c; first recovered Commit must promote
  the replacement branch, discard its old suffix and remain canonical on restart.
- SIGKILL/restart at durable transition boundaries and before/after InitChain,
  first Commit/signature and broadcast. Prove no mixed stores, duplicate owners,
  recreated HRS or old-domain signatures and no mutation of archived old files.
- Full nodes need no registered signing key. Missing/uncertain authority and
  unrelated safety-halt evidence fail closed. Keep gen-zero startup, ordinary
  trust-loss restart and existing lander journal regressions passing.

Run the PR's final just verify on completed implementation: signer race tests,
supervisor tests, formatting/strict lint, fast tests, artifact reproduction and
all Docker scenarios. Update PR #22280 with actual command output and real-proof/
resource limitations. Test-verifier results do not claim real-two-proof readiness.

## Left to the builder

Choose module boundaries, bounded I/O timeouts/retries, typed errors/JSON fields,
test fixtures and the smallest integration with existing Rust/Go/Python code.
Document final CLI flags/profile schema, ownership/phase protocol and runbook.
Do not weaken authentication, signer persistence or nonce ownership. Runtime
implementation starts only after approval of this full description.
