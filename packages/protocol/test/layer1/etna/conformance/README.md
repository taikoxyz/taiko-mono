# Etna contract conformance vectors

The historical copied vectors come from formal PR [#22292](https://github.com/taikoxyz/taiko-mono/pull/22292)
at commit `4f38cfcc8cbcfad10ec159110f5a8f74ca3e7ea5`.

| File                              | Cases | Model scope                                                           | SHA-256                                                            |
| --------------------------------- | ----- | --------------------------------------------------------------------- | ------------------------------------------------------------------ |
| `vectors/forced.json`             | 114   | Historical forced inclusion and fee sweeping                          | `cbebb92bec9aa6097f8b51d6d38ee425fe0f05e415e0c6e1f1a621c31cbfdd71` |
| `vectors/land.json`               | 100   | Historical landing                                                    | `f1b7f8b743ee3c6d3199ea1ba056c544443a815253632aa075d0b4096cdff253` |
| `vectors/registry_admission.json` | 8     | Current permanent-bond registry admission and standard-token payments | `df9c4e93f136c6f3b06a42dced5fd676da9fae7e9406d30685fd0d412c2ea704` |

`EtnaConformance.t.sol` consumes both historical files. Their schema is
`etna-conformance-2`, and their `provenance.formalCommit` records the source above.
They describe the pre-2026-11-03 decoded machine. The selected forced and land
behaviors remain applicable; historical registry and recover vectors are excluded
because their reused identities, registry capacity and recovery interface do not
represent the current lifetime-bond, schedule and start rules. The decoded harness supplies zero for the new terminal validator-state hash and appends a
zero validator-state word to reconstructed cut leaves; the historical JSON remains unchanged.
These families do not exercise nonzero validator-state commitments, proposer indexes or
priority encoding. Current shared vectors and dedicated landing tests cover those dimensions.
Passing these two families does not establish conformance to the complete current specification.

`EtnaCurrentRegistryConformance.t.sol` consumes all eight cases in the separate
`etna-current-registry-admission-1` schema. The current file is copied byte for byte
from formal commit `a8722e8caf570ba64597f532b6945313e3182643`. It has no added
provenance field because `--current-registry` does not accept `--provenance`. Its
`authorityCommit` is `e84a9aaac526c15597d97ee93f8803f92b02c279` (#22335). Only that
authority metadata changed in this refresh; all eight cases and outputs are unchanged.
The harness materializes the real
4096-slot opening, pending top-ups, exit/confirmation/paid withdrawal, and fresh
registration with valid keys and proofs of possession. It compares the listed
bond, slot, checkpoint and payment observations. The model's receipt count means
successful payment receipts, not the total number of Solidity events.

## Refresh and verify

In a checkout of the historical formal commit `4f38cfcc8cbcfad10ec159110f5a8f74ca3e7ea5`,
from `formal/etna`, with
`CONTRACTS_CHECKOUT` set to the contract checkout's absolute path:

```sh
git rev-parse HEAD
lake exe etna-vectors --write "$CONTRACTS_CHECKOUT/packages/protocol/test/layer1/etna/conformance/vectors" \
  --families forced,land --provenance 4f38cfcc8cbcfad10ec159110f5a8f74ca3e7ea5
```

Generate the current admission file separately at formal commit
`a8722e8caf570ba64597f532b6945313e3182643`:

```sh
lake exe etna-vectors --current-registry \
  --write "$CONTRACTS_CHECKOUT/packages/protocol/test/layer1/etna/conformance/vectors"
```

Generate into two temporary directories first and compare their JSON bytes, then
compare with the formal checkout's committed source files (excluding only the
historical copies' added provenance). Update the source commit and checksums above
when refreshing. Do not edit expected decisions by hand.

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
