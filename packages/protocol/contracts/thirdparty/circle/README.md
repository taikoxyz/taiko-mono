# Circle Stablecoin EVM

This directory vendors the minimal source tree required to deploy `FiatTokenProxy` and `FiatTokenV2_2` for Hoodi USDC.

- Upstream repo: https://github.com/circlefin/stablecoin-evm
- Upstream commit: `f2f8b3bb1659e3f1cf23ead72d5cdf58a2f4ebfe`
- Upstream license: Apache-2.0
- Vendored OpenZeppelin dependency version: `@openzeppelin/contracts@3.4.2`

The Circle contracts are compiled with the dedicated Foundry profile:

```bash
pnpm --filter @taiko/protocol compile:circle
```

The main Taiko contracts and tests stay on the repo's default Solidity 0.8.x toolchain. Layer1/layer2 scripts and tests deploy the vendored Circle contracts from the generated `out/circle` artifacts.
