# The anchor field: L1 block hash or state root

**Status [assumed: decision record]:** analysis behind [D80](../DECISIONS.md), written 2026-10-04 after J's finding on #22191 (comment 5976816724) and his addendum (5977189244). The user chose Option 3. This note adds no rule; C1 and C8 carry the adopted change.


## 1. The conflict in two sentences

The merged spec (origin/etna/converged-spec at cc4b077) defines `parentBeaconBlockRoot` as the L1 anchor's execution block hash. It builds origin authentication on that hash: the C1 reveal and pins, the C2 L7 tip check, A-ORIGIN/A-ORIGIN-CHAIN, C7 V5 and `T_A`, and C3's hatch `hash(A)` [proven]. The other contributor's stack instead puts the L1 anchor state root in that field and the anchor number in a 13-byte `extraData`. It removes the header reveal and checks signal proofs directly against the root via EIP-4788 (`Anchor.getL1StateRoot`, `SignalServiceL2`). So the code being built and the accepted spec disagree about the one field everything is authenticated through [proven: Derivation.md L18/L376-384 on docs/derivation-unzen-etna; Anchor.sol L159-164 on feat/protocol-etna-anchor; J's comment 5976816724].

## 2. What each side gives and costs

**Hash (spec).**
- Gives: each anchored header authenticates itself, because the guest checks `keccak(rlp) == field` [proven, C2:281]. L1 can check the tip with `blockhash` or EIP-2935 [proven, C2-R05]. L2 can learn the root, number, timestamp and receipts of any revealed origin, and multi-hop `HopProof` routes keep working [proven by construction].
- Gives: pins survive the 8,191 s ring, so the two-request censorship recovery in C1 §8 holds [proven in spec].
- Costs: a separate reveal transaction, estimated at 60-80k L2 gas once per origin [assumed, unmeasured], plus an extra step for relayers. Recovery needs two forced requests.

**State root (implementation).**
- Gives: claims go through in one transaction with no reveal and no storage growth. There is no privileged anchor transaction, and only the standard 4788 call is used [proven from code].
- Costs, item 1: the header no longer names the anchor's hash, number (to the EVM) or timestamp. L2 contracts cannot learn which L1 block a root belongs to [proven]. Number-keyed L1 checkpoints, receipt/header proofs and multi-hop via L2 state are lost [proven].
- Costs, item 2: the guest can authenticate anchored headers only by walking the parent-hash chain down from an L7-checked tip hash. That obligation was deleted from Derivation.md by #22237 and is now covered only by "driver enforces" [proven]. The C2 uniqueness argument, that the tip is a function of the blobs, no longer holds without an added L7 condition [proven by A's analysis].
- Costs, item 3: proofs are keyed by L2 timestamp in an 8,191 s (about 2.28 h) ring and there is no pin. C3's per-request bound (about 4.5 h) exceeds the ring, so the C1 §8 recovery argument (R6) fails as merged [proven arithmetic; liveness impact assumed until checked against a concrete schedule].
- Costs, item 4: the 13-byte `extraData` conflicts with C1-R03's 7-byte layout and vector V01 [proven].

## 3. Options

**Option 1: hash stays normative, implementation reverts to hash plus a separate reveal (relayers may bundle reveal and claim in one multicall).**
- Soundness: every spec proof is unchanged [proven].
- Gas/UX: a reveal costs about 60-80k once per origin, and a duplicate reveal about 10k [assumed]. A multicall can hide the extra step. Recovery takes two requests.
- Who changes what: the spec changes nothing. On the implementation side, the #22237 Etna rows are reverted, #22238 is reverted (which restores #22222's reveal), the driver/geth set the hash, and the guest keeps its keccak check.
- Spec sections affected: none.

**Option 2: adopt the state root, so the spec moves.**
- Soundness: can be made sound [assumed], but only if three things are added.
  - The journal keeps `l1AnchorTipHash`, and the guest proves `keccak(tipRLP) == tipHash` plus `rlp.stateRoot == field` and `rlp.number == PH.anchorNumber` for every anchored header, chained by parent hash.
  - The forced journal binds `hash(A)`.
  - A root pin with a pinned-root proof sentinel is added to restore R6 [open: no design exists].
- Soundness, continued: "state roots are unique per block" becomes a named premise [assumed]. The L2-side halves of A-ORIGIN-CHAIN and C1-R06 disappear.
- Gas/UX: lowest per claim, about 7-10k for the oracle call plus the MPT proof [assumed]. Relayers must pick a timestamp still inside the ring.
- Who changes what: the spec rewrites rules in C1 (R01-R10, §7, §8, vectors), C2 (R02, R04, partition/uniqueness proof, R18, R19, §10, E08), C3 (R05(d), R07, recovery obligation), C7 (R03, R04, R09, steps, TH17), S2-R03, C4, C5, C6 and C8, with new D-entries and re-review by A, B and J. The implementation adds the pin and restores the parent-hash obligation in its text.
- Spec sections affected: all five merged sections plus S2, C4, C5, C6 and C8.

**Option 3: hash stays normative, and the signal proof carries the L1 header inline (no separate reveal).**
- Soundness: same as Option 1 [proven by construction]. `SignalServiceL2` checks `keccak(rlp) == 4788(ts)` or that the hash is pinned, extracts `stateRoot`, and verifies the MPT proof. It may save the checkpoint through C1-R06.
- Gas/UX: one transaction, like the implementation's. It costs about 600 B more calldata and 15-25k more L2 gas per claim [assumed, unmeasured]. Recovery is still pin then claim, where the claim itself is the second request.
- Who changes what: the implementation reworks #22238's proof envelope and reverts #22237's field content. Driver and guest go back to the hash. The spec adds one proof format.
- Spec sections affected: C1 (interface, proof-format rule, vectors) and C8 (interface rows, errors, selectors). No rule-level soundness change.

**Option 4: hash in the field, plus a system operation writing `(number, hash, stateRoot)` as a checkpoint whenever the origin advances.**
- Soundness: hash proofs stand. A new system-address writer is added, and C1-R07's legacy closure must exclude it. A-EXEC gains one input [assumed sound, needs proof].
- Gas/UX: claims use the existing `HopProof`/`getCheckpoint` paths unchanged, with no eviction. Recovery drops to one request [assumed, relies on V5's 1,800 s bound]. Storage grows by up to one checkpoint per L1 block, about 170 MB/yr raw [assumed]. This reverses C1 §9's "no mandatory checkpoint" choice.
- Who changes what: geth and the driver add a system call with input, the guest adds a check, and contracts replace the reveal with the writer. The spec rewrites C1-R02, R05-R08, §8 and §9, and adds a root check to C2 and C7.
- Spec sections affected: C1, C2, C3 (hatch content), C4, C6, C7, C8. A moderate amount of work.

## 4. Recommendation

Choose Option 3. Record a D-entry stating that `parentBeaconBlockRoot` holds the L1 execution block hash, and that the implementation's single-transaction UX is delivered by carrying the header inside the signal proof. Keep Option 4 on file as a later R6 improvement if one-request recovery is wanted.

Reasons:
- It keeps every merged soundness argument intact [proven], including L7, V5/`T_A`, the hatch and A-ORIGIN-CHAIN.
- It keeps the pin path, so R6 recovery holds [proven in C1 §8]. Option 2 as merged breaks it.
- It gives the implementation what it wanted (no reveal transaction, one-step claims) at a small, local code cost [assumed].
- Option 2 is strictly weaker: the root can be derived from the hash through a reveal, but not the reverse. Its spec cost is the highest, and it still needs a pin that nobody has designed [proven / open].

Also record two things the field decision does not settle:
1. The implementation stack is a Shasta-derivation variant of Etna, not the converged spec. Its 13-byte `extraData` (vs C1-R03's 7 bytes), its lack of landing and V5 age bounds, and its lack of the hatch remain divergences, so settling the field alone does not make #22222 an implementation of the spec [proven].
2. `SignalServiceL2` inherits a pauser (constructor `_pauser`), which conflicts with C1-R05's removal of pause [proven].

Separately, C1:272 has the EIP-4788 address typo `…D742…`. The canonical address is `…D732…`, as used in `Anchor.sol` L48 [proven].

Risks this carries:
- The other contributor must revert merged work (#22237's field content, #22238's envelope) and the matching driver/guest changes. That is a coordination cost outside our scope [proven that they would need to change; willingness open].
- The per-claim gas premium of 15-25k is unmeasured and could be larger. If it is materially larger, the case for Option 2's cheaper claims gets stronger [open].
- Recovery stays at two requests with the illustrative 9 h-plus bound until Option 4 or an equivalent is adopted [proven in spec].

Refs: spec at `origin/etna/converged-spec` under `/home/user/taiko-mono/packages/protocol/docs/Etna/spec/` (C1-anchor-free-l2.md, C2-landing.md L281, C3, C7, C8). Implementation: `origin/docs/derivation-unzen-etna:packages/protocol/docs/Derivation.md`, `origin/feat/protocol-etna-anchor:packages/protocol/contracts/layer2/core/Anchor.sol` and `.../shared/signal/SignalServiceL2.sol`. J: https://github.com/taikoxyz/taiko-mono/pull/22191#issuecomment-5976816724