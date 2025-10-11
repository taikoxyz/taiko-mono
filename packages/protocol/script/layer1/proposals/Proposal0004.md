# Verifier and PreconfRouter Contract Upgrade

This proposal updates the verifier configurations for the Taiko protocol's proof systems and upgrades the PreconfRouter implementation on Layer 1.

## L1 Actions

This proposal executes 11 actions on Layer 1 through the DAOController:

### SP1 Verifier Updates (4 actions)

**Target**: `0xbee1040D0Aab17AE19454384904525aE4A3602B9`

- Action 0: `setProgramTrusted(0x008f96447139673b3f2d29b30ad4b43fe6ccb3f31d40f6e61478ac5640201d9e, true)`
- Action 1: `setProgramTrusted(0x47cb22384e59cecf65a536612d4b43fe36659f987503db9828f158ac40201d9e, true)`
- Action 2: `setProgramTrusted(0x00a32a15ab7a74a9a79f3b97a71d1b014cd4361b37819004b9322b502b5f5be1, true)`
- Action 3: `setProgramTrusted(0x51950ad55e9d2a6973e772f471d1b01466a1b0d95e064012726456a02b5f5be1, true)`

All these image ids come from release 1.12.0, which can be found here: https://github.com/taikoxyz/raiko/blob/v1.12.0/RELEASE.md.
To verify the image id, checkout the release and run `./script/publish-image.sh` to build the corresponding zk image, and the log will be like:

```
#43 131.2 sp1 elf vk bn256 is: 0x008f96447139673b3f2d29b30ad4b43fe6ccb3f31d40f6e61478ac5640201d9e
#43 131.2 sp1 elf vk hash_bytes is: 47cb22384e59cecf65a536612d4b43fe36659f987503db9828f158ac40201d9e
...
#43 143.6 sp1 elf vk bn256 is: 0x00a32a15ab7a74a9a79f3b97a71d1b014cd4361b37819004b9322b502b5f5be1
#43 143.6 sp1 elf vk hash_bytes is: 51950ad55e9d2a6973e772f471d1b01466a1b0d95e064012726456a02b5f5be1
```

Enables support for updated SP1 proof generation systems.

### Risc0 Verifier Updates (3 actions)

**Target**: `0x73Ee496dA20e5C65340c040B0D8c3C891C1f74AE`

- Action 4: `setImageIdTrusted(0x3d933868e2ac698df98209b45e6c34c435df2d3c97754bb6739d541d5fd312e3, true)`
- Action 5: `setImageIdTrusted(0x77ff0953ded4fb48bb52b1099cc36c6b8bf603dc4ed9211608c039c7ec31b82b, true)`
- Action 6: `upgradeTo(0xDF6327caafC5FeB8910777Ac811e0B1d27dCdf36)`

All these image ids come from release 1.12.0, which can be found here: https://github.com/taikoxyz/raiko/blob/v1.12.0/RELEASE.md.
To verify the image id, checkout the release and run `./script/publish-image.sh` to build the corresponding zk image, and the log will be like:

```
#41 550.0 risc0 elf image id: 3d933868e2ac698df98209b45e6c34c435df2d3c97754bb6739d541d5fd312e3
...
#41 551.7 risc0 elf image id: 77ff0953ded4fb48bb52b1099cc36c6b8bf603dc4ed9211608c039c7ec31b82b
```

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

### Automata SGX Attester Updates (3 actions)

#### SGXGETH Attester

**Target**: `0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261`

- Action 8: `setMrEnclave(0x3e6113a23bbdf9231520153253047d02db8f1dd38a9b52914ab7943278f52db0, true)`

#### SGXRETH Attester

**Target**: `0x8d7C954960a36a7596d7eA4945dDf891967ca8A3`

- Action 9: `setMrEnclave(0xe5774b71990b0d5f3eca8d4d22546764dd9549c743a1a6d4d4863d97f6b8c67a, true)`
- Action 10: `setMrEnclave(0x605ad10c1a56ed7289f198d64a39a952cd3b8a0bed3fcb19c8301c1847dc3a2f, true)`

These actions add trusted MR_ENCLAVE values for the Automata SGX attesters on both geth and reth.
The reth-sgx has 2 enclave measurements because of the edmm feature, which is not supported by geth-sgx.

These MR_ENCLAVE values correspond to updated enclave builds, which can be found here: https://github.com/taikoxyz/raiko/blob/v1.12.0/RELEASE.md.

To verify the MR_ENCLAVE values, checkout the release and run `./script/publish-image.sh [0|1]` (0 for non-edmm, 1 for edmm) to build the corresponding sgx image, the log will be like:
For non-edmm mode:

```
#30 0.205 2025/10/09 03:10:00 INFO EGo version=1.7.0 git_commit=3a3f54a1d1cd9318dd1ade411f9f439f53bb6694
#30 0.205 3e6113a23bbdf9231520153253047d02db8f1dd38a9b52914ab7943278f52db0
...
#48 3.653     mr_enclave: e5774b71990b0d5f3eca8d4d22546764dd9549c743a1a6d4d4863d97f6b8c67a
```

and
For edmm:

```
#30 0.205 2025/10/09 03:10:00 INFO EGo version=1.7.0 git_commit=3a3f54a1d1cd9318dd1ade411f9f439f53bb6694
#30 0.205 3e6113a23bbdf9231520153253047d02db8f1dd38a9b52914ab7943278f52db0
...
#48 3.653     mr_enclave: 605ad10c1a56ed7289f198d64a39a952cd3b8a0bed3fcb19c8301c1847dc3a2f
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
