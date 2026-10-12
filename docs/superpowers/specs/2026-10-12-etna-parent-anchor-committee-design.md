# Etna committees from the committed derivation parent anchor

## Purpose and scope

Replace epoch-fixed L1 cutoff selection in PR22280 and PR22286 with the registry state at the committed parent of the switch block. User selected the parent-anchor direction after comparing it with fixed-cutoff selection. This document makes its historical authentication requirement concrete; implementation awaits written-spec approval.

Baselines: client367466179027a88d599e780dd8954590f17fd2de; protocol1a964fb41275d2717d570b2b2bb7bf914cc94b98. Etna starts at L2 genesis0, CometBFT height1. Preserve back-pressure, generation, execution/replay, membership/power/MEM08/heartbeat rules and no per-epoch set/land publication. Do not redesign registry lifecycle, implement a real guest or add generation recovery.

## Alternatives and selected approach

1. Selected: derive at the committed switch-parent anchor; authenticate the historical derivation parent with a short EL ancestor chain for arbitrary landing cuts. Node selection loses lag/grid/epoch-cutoff arithmetic; proof jobs gain authenticated header context.
2. Keep an epoch-fixed point with lag0/grid1. This avoids extra EL committee history, but does not implement the user's requested parent-state selection.

The selected design is sound within the existing prefix-checkpoint proof model. Finality is necessary but does not by itself identify which finalized state selected an epoch's set: the state must be the committed derivation parent, not a caller-selected finalized head.

## Runtime selection and activation

For target epoch t>=1:

- Epoch starts H(t)=1+t\*epochLenL2.
- Switch S(t)=H(t)-2.
- Derivation parent D(t)=S(t)-1=H(t)-3, with checked arithmetic.
- At S(t), snapshot height is exactly committed state.anchor.number, belonging to EL block D(t).
- Runtime registry proofs verify under that same committed parent's authenticated stateRoot. Select its latest registry checkpoint and verify complete entry count/root; evaluate active/exit eligibility at the parent anchor number, not the checkpoint's mutation height.
- Never choose the newly proposed block's anchor or a fresh finalized head as the derivation point.
- Prepare/Process recompute and verify the incoming record; Finalize inserts it before returning updates; Commit persists it; CometBFT activates at H(t).
- Non-switch heights forbid runtime committee witnesses. H0 still forces an anchor witness; ordinary anchor moves still prove the four Inbox facts.

The committed anchor has already passed canonical/finalized checks during initialization or live proposal processing. Do not add L1 calls to deterministic Finalize/replay. Different valid L2 histories can now select different epoch sets; all nodes replaying one decided history must derive the same set.

## Genesis and retained membership algorithm

Committee0 remains independently verified at the explicit genesisCutoff and bound to plain Inbox slot278. Retain slot279 and the existing initialization rules. Parent-derived runtime anchors are >=L1_0>genesisCutoff by existing anchor-progress validation, so no separate runtime genesis-floor calculation is needed.

Keep active_from<=snapshot_height<exit_effective, effective stake threshold, earliest eligible bondId pubkey deduplication, nMax ranking, MEM08 order/root, voting-power division and overflow caps. Keep heartbeatWindow and the existing target-epoch two-epoch evaluation predicate, including exemptions0/1/2. The fixed two-epoch constant now belongs only to heartbeat evaluation, not snapshot selection.

Remove cutoff_grid/cutoff_lag from node/CLI derivation configuration and obsolete fixed-cutoff helpers. CommitteeRecord.cutoff_l1_block remains the actual snapshot L1 number; it is no longer an epoch-fixed value. Retain the generic explicit-snapshot verifier/discovery for genesis and host proof jobs.

## Arbitrary batch starts: authenticated EL history

The current lander reconstructs starting sets using only epoch plus fixed cutoff. That shortcut must be replaced rather than silently deriving from the checkpoint's newer anchor.

Let p be the contract-bound checkpoint height/hash. The source fetches the checkpoint EL header and the minimal descending EL ancestors needed for the current and next signing epochs. At nonzero p, include p-1 for authenticated base-fee grandparent timestamp. For each required epoch t>=1, include D(t).

Pure verification starts from the contract-bound EL checkpoint hash, checks each header hash/parentHash link and consecutive height, then reads the derivation anchor number from the authenticated D(t) header's Etna extraData. Check its generation and Etna anchor fields; never accept a separate unproved derivation height/anchor hint. Ancestors can come from public EL RPC or Comet envelopes because their hash links, not the source, authenticate them. No prior transactions/commits need to be re-executed.

Example with epochLenL2=10: a batch starting at16 has trusted checkpoint15. Authenticate EL headers15->14->...->8; committee1's snapshot number comes from header8, not header15. At checkpoint10, authenticate both the outgoing epoch0 bootstrap and pending committee1 derived from header8.

Current/next starting epochs differ by at most one. The earliest required D(t) is at most epochLenL2+2 links behind p; add only required headers, use checked bounds, existing I/O deadlines and journal capacity, and do not preallocate from unbounded caller input. Header-only ancestry adds proof context proportional to an epoch, not full-history replay.

Retain historical registry checkpoints. A starting committee's registry proof may use the already authenticated checkpoint-parent proving root, with proving_number>=authenticated_derivation_anchor_number. The explicit-snapshot verifier proves the last registry checkpoint at/before that derivation number and the successor after it. Immutable historical roots and complete entries reproduce the exact derivation-parent snapshot. Thus this does not require historical metadata MPT proofs at the original derivation root; historical entry values still require RPC/cache data as today.

PreparedBatch retains the minimal EL ancestor headers and per-epoch derivation provenance. The guest independently verifies their links to its public parent hash, derives the snapshot number, opens config/schedule, verifies registry witnesses and recomputes all parent/current/pending sets. Inside the batch, switch witnesses use the actual embedded committed parent root as runtime does. Check every certificate and current/next validator hash across S/S+1/H and arbitrary cuts. Every actual proving L1 root remains covered by the authenticated reference ancestry.

## Contract/config/wire boundary

No future committee mapping, publication event, set call or committee output is restored. Keep four-field LandInput, existing storage slots, trusted identities, SignalService checkpoint saving and verifier rollback.

New committeeConfigHash is exactly nine static ABI words (288 bytes):

```text
keccak256(abi.encode(
  bytes32("ETNA_PARENT_ANCHOR_V1"),
  uint256(l2ChainId), address(stakingRegistry),
  uint256(vpUnit), uint256(sMin), uint64(nMax),
  uint64(heartbeatWindow), uint64(2), uint8(1)
))
```

The final words bind heartbeat lookahead2 and retained record/MEM08 algorithm version1. Genesis schedule remains independently authenticated from Inbox storage. Slot269 stays the opaque nonzero config hash; local opening/load checks stay mandatory.

Use envelope version3, journal schema3, and TAIKO_ETNA_LAND_V5 to explicitly separate this prelaunch semantic change. The V5 statement keeps the exact fifteen-word V4 field order, only its domain changes; helper signature and LandInput ABI remain unchanged. Record encoding stays1. Regenerate copied interface/artifacts from the exact verified new protocol commit, never hand-edit generated files.

Old envelope2 histories, fixed-cutoff genesis/state/config openings, V4 pending journals/statements reject explicitly. Never invent a migrated committee, discard a signed nonce, cancel or automatically replace an outstanding transaction. No deployed-chain migration is provided.

## Error and recovery behavior

Preserve status/generation/anchor-progress/back-pressure ordering, height-checkpoint<=dMax-marginV, epochLenL2>=unsettledCap+3, generation chainID/extraData domains, transient RPC retry, hash-pinned operational snapshot reads, durable nonce/receipt handling and SafetyHalt for committed contradictions.

Missing ancestor history prevents proof preparation with a precise required-height diagnostic; transient RPC unavailability remains retryable. Broken hash links, wrong derivation point/root/record/config or forged committees reject. Missing/invalid data in an already decided block remains SafetyHalt.

An empty set at the immutable committed derivation-parent snapshot still halts at S(t). Later L1 updates cannot repair that already committed parent; no advancing-snapshot/old-set fallback is introduced. Parent selection remains partly controlled by valid preceding L2 anchor choices, and the set is certain only after D(t) commits. This gives less guaranteed advance notice than fixed cutoffs. Outgoing quorum, old-key/stake-retention/withdrawal assumptions and lack of complete recovery-generation bootstrap remain explicit boundaries.

## Verification requirements

- Parent1010 vs1020 may deliberately derive different sets when effective entry state differs; same committed parent always yields identical set/record.
- New block anchor1030 with parent1010 still derives at1010, and a proof under1030 is rejected by runtime.
- Switch-only witness presence and exact H+2 old/new membership/power remain.
- Batch starts before/on/after S/S+1/H, mid-epoch, and crossing epochs authenticate required EL history/current/pending sets. Missing/reordered/wrong-number/hash/anchor-generation ancestor or forged hint fails.
- Later proving roots reproduce the historical parent snapshot, with wrong selected/successor/entries/config proofs rejected.
- Restart and cold replay across switch heights reproduce full responses/sets/EL hashes without Finalize L1 calls; add focused switch-height before/after Commit coverage.
- Settlement outage still stops at cap/resumes; supersession and old signed-nonce retention remain. Operational L1 reorg still retries without losing journal state.
- Independent Rust/Solidity/ethers vectors bind nine-word config, fifteen-word V5, proxy/registry/current checkpoint/reference/blob order; old domains/versions reject.
- Required client fmt/clippy/unit/Docker and protocol tests/layout/gas/provenance checks; independent final cross-repo review before updating both PR branches. Existing live-fork/coverage/tooling limitations remain reported rather than hidden.

No real guest is implemented by this work. Dummy0x00 remains explicit; host/contract integration checks do not establish production ZK soundness.
