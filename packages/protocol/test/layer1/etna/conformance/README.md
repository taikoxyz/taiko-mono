# Etna contract conformance vectors

The historical vectors come from formal PR [#22292](https://github.com/taikoxyz/taiko-mono/pull/22292)
at commit `4f38cfcc8cbcfad10ec159110f5a8f74ca3e7ea5`, translated to one leaf per height for
[#22412](https://github.com/taikoxyz/taiko-mono/pull/22412). The current admission vectors are a
byte-for-byte copy from formal commit `37e13173abadc41f30697549e36eb4365496a01d`.

| File                              | Cases | Model scope                                                                        | SHA-256                                                            |
| --------------------------------- | ----- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| `vectors/forced.json`             | 114   | Historical forced inclusion and fee sweeping                                       | `e044c8b85a900147d8dc85ec5153ae9d306ec7b8685877461f329f226986a01a` |
| `vectors/land.json`               | 78    | Historical landing                                                                 | `ec0e5222613d2f68b5feb988f797553f397a771c21cd07521662683ef8a92a58` |
| `vectors/registry_admission.json` | 7     | Current lowest-empty-slot registry admission, slashing and standard-token payments | `7d54bac813a3dca2fbbbc01ac85e427c9f1e54b8fbb713b10d9c6a07479b13cf` |

## Historical forced and land vectors

`EtnaConformance.t.sol` consumes both historical files. Their schema is
`etna-conformance-2`, and their `provenance.formalCommit` records the source above.
They describe the pre-2026-11-03 decoded machine. The selected forced and land
behaviors remain applicable; historical registry and recover vectors are excluded
because their reused identities, registry capacity and recovery interface do not
represent the current lifetime-bond, schedule and start rules. The current formal tree no
longer generates these families, so they cannot be regenerated; they were translated instead.

That machine carried one cut leaf per grid point (K = 6, from S = 0) strictly inside (p, h);
#22412 removed the grid, and `land` now takes the h − p − 1 leaves of every height strictly
inside (p, h). A landing translates exactly when p and h are grid points and its list has the
grid's (h − p) / 6 − 1 leaves, or when h ≤ p and its list is empty. Each listed leaf then keeps
its height: the leaf at a grid point x moves to index x − p − 1, a cut leaf keeping its own
fields (including a deliberately wrong height or hash). Every other height x strictly inside
(p, h) gets the word leaf `100000 · generation + 40000 + x`, the model's own atom for an
unchecked leaf; `land` checks only the leaf at c, and c is always a grid point in these
vectors. A vector is kept only when every landing in it, setup calls included, translates
exactly; the others are dropped. The translation also removes `constants.gridInterval`,
updates `vectorCount` and `leafCount`, and adds `provenance.translation`; every other byte is
unchanged, and no expected decision or observable was edited.

| Family   | Kept | Dropped | Dropped vectors and reason                                                                                                                                                                                                                                                                   |
| -------- | ---- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `forced` | 114  | 0       | Every landing is (0, 6\] with no leaf.                                                                                                                                                                                                                                                       |
| `land`   | 78   | 22      | 20 `land.range.*` vectors land from or to a height off the old grid (p or h of 3, 9, 15 or 21), so their leaves have no heights to keep, and the old grid alone decided several of them; `land.leaves.one-missing` and `land.leaves.one-extra` test a grid leaf count that no longer exists. |

The kept vectors still cover the range, origin, generation, already-settled, batch size, FI
head, reference block, blob, proof, frontier-leaf (wrong word, head, EL or Comet hash, height
and swapped leaves) and unchecked interior-leaf cases. The harness deploys the registry with
`MIN_STAKE` in place of the historical `minStake` of 10, which is below the current deployment
bound (STAKE-4.1-14a); neither family reads a stake. It compares landing records and
SignalService checkpoints at every height up to the highest landed height. These families do
not exercise validator-state hashes, which no landing carries any more, nor landings of one
block or to a non-grid height; the dedicated landing tests cover those. Passing these two
families does not establish conformance to the complete current specification.

## Current registry admission vectors

`EtnaCurrentRegistryConformance.t.sol` consumes every case in the separate
`etna-current-registry-admission-1` schema and reads the case count from the file. The file is
copied byte for byte from formal commit `37e13173abadc41f30697549e36eb4365496a01d`, whose later
commits do not change it. Its `authorityCommit` is `2e6763e21bc236cfcda6011d164b32040f9e0c8d`,
the spec commit of #22412. It has no added provenance field. The seven cases cover the
lowest-empty-slot rule: an empty last slot, the lowest of several empty slots, a full registry,
a zero-balance slashed bond that keeps its slot, a withdrawn slot reused with a fresh id, a
pending top-up that does not change the choice, and an amount below `minStake`. No case
replaces a bond, so `oldBondId` and `oldBond` are null in every case.

The harness deploys the registry with the file's `minStake` (250,000 TAIKO) and materializes
the opening of `openingBonds` bonds (4 or 4,096) with valid keys and proofs of possession, the
pending top-ups, the exit, confirmation and paid withdrawal of `vacancyLifecycle`, and the real
double-sign slash of `slashLifecycle`: each model vote is signed by the bond's key under the
deployment's chain id, and the reporter and slash sink receive the actual bounty and remainder.
Caller 8 holds and approves 100 units of 25,000 TAIKO. The harness compares the listed bond,
slot, checkpoint and payment observations, checks that slots are used in order, and checks
that a rejected registration leaves the whole registry and token state unchanged. The model's
receipt count means successful payment receipts, not the total number of Solidity events.

## Refresh and verify

Regenerate the current admission file in a checkout of the formal branch, from `formal/etna`,
with `CONTRACTS_CHECKOUT` set to the contract checkout's absolute path:

```sh
git rev-parse HEAD
lake exe etna-vectors --write "$TMPDIR/etna-current"
cp "$TMPDIR/etna-current/registry_admission.json" \
  "$CONTRACTS_CHECKOUT/packages/protocol/test/layer1/etna/conformance/vectors/"
```

The generator also writes `validator_state.json`, which this harness does not read. Generate
twice and compare the JSON bytes, then compare with the formal checkout's committed source file.
Update the source commit, `authorityCommit` and checksum above when refreshing. Do not edit
expected decisions by hand.

In the contract checkout, using pnpm 9 as in repository CI:

```sh
pnpm install --frozen-lockfile
cd packages/protocol
FOUNDRY_PROFILE=layer1 forge test --match-path 'test/layer1/etna/conformance/*' -vv
FOUNDRY_PROFILE=layer1 forge test --match-path 'test/layer1/etna/**' -vv
```

The current vectors cover admission only. Current rules-schedule, switch, recovery,
cryptography, token callbacks and full deployment conformance still require their
own implementation tests and refinements.
