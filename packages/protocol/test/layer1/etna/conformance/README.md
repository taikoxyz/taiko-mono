# Etna contract conformance vectors

The historical vectors come from formal PR [#22292](https://github.com/taikoxyz/taiko-mono/pull/22292)
at commit `4f38cfcc8cbcfad10ec159110f5a8f74ca3e7ea5`, translated to one leaf per height for
[#22412](https://github.com/taikoxyz/taiko-mono/pull/22412) and adapted by hand to the Inbox of
L2 staking, which has no registry, committee snapshot or epoch length.

| File                  | Cases | Model scope                                  | SHA-256                                                            |
| --------------------- | ----- | -------------------------------------------- | ------------------------------------------------------------------ |
| `vectors/forced.json` | 114   | Historical forced inclusion and fee sweeping | `c85c42abb27b874601ca6e77b8154c564c90c37b1d70a066930447551ae8858e` |
| `vectors/land.json`   | 78    | Historical landing                           | `d20bc6d9787250883fc31e80bbe1a49ce6c24d38913e51168d1abb22d1bf4690` |

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
and swapped leaves) and unchecked interior-leaf cases. The harness compares landing records and
SignalService checkpoints at every height up to the highest landed height. The L1 SignalService is
the root-only `EtnaSignalService`, so the harness compares each checkpoint's state root with the
model's and requires its hash to read back as zero; the landing records still carry the model's
hashes. These families do
not exercise validator-state hashes, which no landing carries any more, nor landings of one
block or to a non-grid height; the dedicated landing tests cover those. Passing these two
families does not establish conformance to the complete current specification.

The staking contract moved to L2, so the Inbox no longer has a registry, committee snapshot,
epoch length or recovery exclusions, and both files were then adapted by hand, editing lines
and touching no other byte:

1. every landing's `activeCommitteeSnapshot` input is removed (10 in `forced.json`, 212 in
   `land.json`), and so is every observed `snapshot` (114 and 78 lines);
2. each deployment drops `activationDelay`, `bountyBps`, `exitDelay`, `forfeitBps`, `minStake`,
   `registrySize` and `withdrawalDelay` (798 and 546 members); the harness passes `unsettled` to
   the Inbox as its U, and the EtnaStaking proxy is the test constant;
3. `constants` drops `registeredAt`, `genesisKey`, `genesisOwner`, `epochLenL2`, `vpUnit`,
   `sMin` and `nMax` (7 lines each);
4. `provenance.translation` records the adaptation.

No expected decision or other observable was edited. Every recovery in these files lists no
exclusion; the harness checks that and sends the six-argument `recover`.

## Refresh and verify

The current formal tree no longer generates these families, so they cannot be regenerated;
check the files against the checksums above with `sha256sum vectors/*.json`.

In the contract checkout, using pnpm 9 as in repository CI:

```sh
pnpm install --frozen-lockfile
cd packages/protocol
FOUNDRY_PROFILE=layer1 forge test --match-path 'test/layer1/etna/conformance/*' -vv
FOUNDRY_PROFILE=layer1 forge test --match-path 'test/layer1/etna/**' -vv
```

These vectors do not cover staking, the rules schedule, the switch, recovery authorization,
cryptography or full deployment conformance, which still require their own implementation tests
and refinements.
