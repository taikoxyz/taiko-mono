# Verifier and PreconfRouter Contract Upgrade

This proposal updates the verifier configurations for the Taiko protocol's proof systems and upgrades the PreconfRouter implementation on Layer 1.

## L1 Actions

This proposal executes 8 actions on Layer 1 through the DAOController:

### SP1 Verifier Updates (4 actions)

**Target**: `0xbee1040D0Aab17AE19454384904525aE4A3602B9`

- Action 0: `setProgramTrusted(0x008f96447139673b3f2d29b30ad4b43fe6ccb3f31d40f6e61478ac5640201d9e, true)`
- Action 1: `setProgramTrusted(0x47cb22384e59cecf65a536612d4b43fe36659f987503db9828f158ac40201d9e, true)`
- Action 2: `setProgramTrusted(0x004775b86041915596830bbc5464584165b2641a277b6758e83723954946bee2, true)`
- Action 3: `setProgramTrusted(0x23badc30106455655061778a464584162d9320d11ded9d63506e472a4946bee2, true)`


All these image ids can be found here: https://github.com/taikoxyz/raiko/blob/7db0044e932ac76aae190ee8f53c0ee2fdda2d8f/RELEASE.md

Enables support for updated SP1 proof generation systems.

### Risc0 Verifier Updates (3 actions)

**Target**: `0x73Ee496dA20e5C65340c040B0D8c3C891C1f74AE`

- Action 4: `setImageIdTrusted(0x3d933868e2ac698df98209b45e6c34c435df2d3c97754bb6739d541d5fd312e3, true)`
- Action 5: `setImageIdTrusted(0x326ce3b6f13708a0691ed4bc56e8c14d6ee4e1197c533c129b441e263350b87e, true)`
- Action 6: `upgradeTo(0xDF6327caafC5FeB8910777Ac811e0B1d27dCdf36)`

All these image ids can be found here: https://github.com/taikoxyz/raiko/blob/7db0044e932ac76aae190ee8f53c0ee2fdda2d8f/RELEASE.md


Enables support for updated RISC0 proof generation systems.

### PreconfRouter Upgrade (1 action)

**Target**: `0xD5AA0e20e8A6e9b04F080Cf8797410fafAa9688a`

- Action 7: `upgradeTo(0xafCEDDe020dB8D431Fa86dF6B14C20f327382709)`

This upgrade adds a new pure function for onchain configuration:

```solidity
function getConfig() external pure returns (IPreconfRouter.Config memory) {
    return IPreconfRouter.Config({ handOverSlots: 8 });
}
```

## L2 Actions

There are no L2 actions in this proposal.

## Action Verification

### Action Generation

All actions in this proposal are generated using the following script:

https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/script/layer1/proposals/Proposal0004.s.sol

Please review the `buildL1Actions()` function for logic verification.

### Bytecode Verification

To confirm the action data matches this proposal, clone the Taiko [monorepo](https://github.com/taikoxyz/taiko-mono), navigate to `packages/protocol`, run `pnpm install`, then:

```bash
P=0004 pnpm proposal
```

This will print the generated calldata and write it to Proposal0004.action.md for comparison. Byte-by-byte validation can then be performed.

### Dryrun Execution

To test the executability of the actions, use:

```bash
P=0004 pnpm proposal:dryrun:l1
```

If the execution ends in a revert with `DryrunSucceeded`, this indicates the current on-chain state allows for successful execution. Note that state changes from other proposals may affect future outcomes.

## Risks and Contingencies

Despite thorough testing, execution risks remain. Should the actions fail, a follow-up proposal will be submitted.

### Rollback

All contracts use UUPS upgradeable pattern. In case of critical issues, the contracts can be upgraded again through a new governance proposal to revert to previous implementations or deploy fixes.
