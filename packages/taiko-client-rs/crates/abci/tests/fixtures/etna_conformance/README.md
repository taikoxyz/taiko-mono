# Etna client conformance fixtures

Generated from [formal PR #22292 at `4f38cfcc8`](https://github.com/taikoxyz/taiko-mono/tree/4f38cfcc8cbcfad10ec159110f5a8f74ca3e7ea5/formal/etna).
The four files contain 340 vectors: forced inclusion (151), committee scheduling (83),
block rules (92) and block size (14). Their inputs and expected decisions are unchanged
from the previous source, `4ec05bbe27bad6c65c6425fc508cae304deb343a`; only
`provenance.formalCommit` changes.

These are **historical model regressions**, as the formal source's
[vector documentation](https://github.com/taikoxyz/taiko-mono/blob/4f38cfcc8cbcfad10ec159110f5a8f74ca3e7ea5/testdata/etna_conformance/README.md)
explains. The authority is the archived pre-2026-11-03 decoded machine, not the latest
Etna specification. Updating the generator revision does not extend their rule coverage.
The separate current `registry_admission` suite tests contract registration, displacement,
lifetime bonds and token payments; this client authenticates registry checkpoints and
derives committees, and does not execute those registry transactions.

`../../etna_conformance.rs` compares every vector through the real client validation
and authenticated proof paths described in that harness. Its sole listed divergence,
`block_rules.hw.height-2pow48`, remains explicit: the historical model rejects an L2
height of 2^48, while the client accepts it. The suite requires that recorded divergence
to continue differing until deliberately resolved.

Regenerate from `formal/etna` at the pinned commit, twice to check reproducibility:

```sh
lake exe etna-vectors --write <client checkout>/packages/taiko-client-rs/crates/abci/tests/fixtures/etna_conformance \
  --families forced_step,schedule,block_rules,block_size \
  --provenance 4f38cfcc8cbcfad10ec159110f5a8f74ca3e7ea5
```

Never edit the JSON files by hand. From `packages/taiko-client-rs`, run:

```sh
cargo test -p abci --test etna_conformance -- --nocapture
```
