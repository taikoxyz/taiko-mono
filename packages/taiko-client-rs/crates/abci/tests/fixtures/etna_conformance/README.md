# Etna client conformance fixtures

Five vector families follow the Etna specification at
[`797a708e5`](https://github.com/taikoxyz/taiko-mono/tree/797a708e57badb02dc4e974dcaf9167232aa2969/packages/protocol/docs/etna),
each file's `provenance.specCommit`. `../../etna_conformance.rs` runs every vector through the
client's validation, its `missBitmap` derivation and its signing-set decision, as that harness
describes.

## Regressions from the formal model

`forced_step.json` (151 vectors), `block_rules.json` (92) and `block_size.json` (14) were
generated from [formal PR #22292 at `4f38cfcc8`](https://github.com/taikoxyz/taiko-mono/tree/4f38cfcc8cbcfad10ec159110f5a8f74ca3e7ea5/formal/etna),
their `provenance.formalCommit`. They are **historical model regressions**, as the formal
source's
[vector documentation](https://github.com/taikoxyz/taiko-mono/blob/4f38cfcc8cbcfad10ec159110f5a8f74ca3e7ea5/testdata/etna_conformance/README.md)
explains: their authority is the archived pre-2026-11-03 decoded machine, and they establish no
conformance to the current specification. They stay until #22292 generates current families.

They are adapted by hand for the current specification:

- the files add `provenance.specCommit`, and the block rules vectors no longer carry the
  `epochLen` input, since the client has no epochs, committees or registry;
- the harness gives every block the 29-byte `extraData`, a parent LastCommit in which every
  signer committed (so the derived `missBitmap` is 0), and the fallback keys `F1` to `F4` as the
  set that signs it, proven by its anchor with a `minTotalStake` of 2^256 − 1.

Their inputs and expected decisions are otherwise the model's. The harness lists one divergence,
`block_rules.hw.height-2pow48`: the model rejects an L2 height of 2^48, while the client accepts
it. The suite requires that recorded divergence to continue differing until deliberately
resolved.

When #22292 generates current families, copy them byte for byte in place of these, generated
twice to check reproducibility:

```sh
lake exe etna-vectors --write <client checkout>/packages/taiko-client-rs/crates/abci/tests/fixtures/etna_conformance \
  --families forced_step,block_rules,block_size \
  --provenance <formal commit>
```

## Client-owned families

`miss_bitmap.json` and `candidate.json` are written by hand from the specification's
accept/reject vectors. Each vector's `row` names the file and row it transcribes; `id`s
describe the case in words.

- `miss_bitmap.json` (30 vectors): every row of the miss bitmap table in `rules/vectors/3.4.md`
  and the `extraData` rows of `rules/vectors/3.2.md`. A vector gives the set that signs the
  parent, the LastCommit flag of each of its validators, the key-to-seat words and snapshot seat
  records of the parent's post-state (and, where the row needs it, the block's own post-state)
  and the header's `missBitmap` or whole `extraData`; it expects the bitmap the client derives
  and whether the block is valid. The rejected rows are exactly those the table marks reject.
- `candidate.json` (25 vectors): the candidate usability, valid key, valid set and fallback rows
  of `rules/vectors/4.3.md` (rows 3a.a to 3a.h, 4.b, 4.c, 8.a to 8.k, 8b.b, 8b.e and 16.c). A
  vector gives H, the minimum total stake and fallback key list that H's anchor (and its
  parent's) proves, and the candidate snapshot of each block from H on; it expects the set that
  signs two blocks later, as `candidate` or `fallback` and its members. Keys are named: `C<s>` is
  the key of a range record's seat s, `F<n>` a fallback key.

Rows that do not map to exactly one vector:

- 4.c has three vectors, one per invalid key form it lists.
- 8.d (129 members) has none: a snapshot holds exactly 128 seat records, so a candidate read from
  it has at most 128 members.
- 8.k's vector uses powers whose 64-bit wrapping sum is 1, not 8.j's powers, whose sum wraps to
  0, so the two rows do not share one input.
- 7a.r and 8b.e state a seat limit `n_max`, which the client never reads.

Edit these two files by hand, keeping every cited row covered, and update `specCommit` with the
specification revision they then follow.

From `packages/taiko-client-rs`, run:

```sh
cargo test -p abci --test etna_conformance -- --nocapture
```
