# Verifier Configuration Update

This proposal updates the verifier configurations for the Taiko protocol's proof systems on Layer 1.

## L1 Actions

The following L1 actions will be executed by the DAOController:

### SP1 Verifier Updates (4 actions)

- Configure SP1 verifier at `0xbee1040D0Aab17AE19454384904525aE4A3602B9` with new parameters
- Update program verification keys for SP1 proof verification

### Risc0 Verifier Updates (3 actions)

- Configure Risc0 verifier at `0x73Ee496dA20e5C65340c040B0D8c3C891C1f74AE` with new parameters
- Update image IDs for RISC0 proof verification
- Upgrade proxy to the latest RISC0 verifier implementation

These actions aim to update the verifier configurations to support the latest proof systems and ensure secure block verification.

### PreconfRouter updates (1 action)

- Update PreconfRouter at `0xD5AA0e20e8A6e9b04F080Cf8797410fafAa9688a` to the version here:
`https://github.com/taikoxyz/taiko-mono/blob/taiko-alethia-protocol-v2.3.1/packages/protocol/contracts/layer1/preconf/impl/PreconfRouter.sol` at implementation `0x64F6C711F00d146c4df808eE2bFEfA146BE05EB4`.

This action is to add the `Config` and `handoverSlots` onchain, rather than as a parameter to the driver.

## L2 Actions

There are no L2 actions in this proposal.

## Action Verification

### Action Generation

All actions in this proposal are generated using the following script:

https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/script/layer1/proposals/Proposal0004.s.sol

Please review the `buildL1Actions()` function for logic verification.

### buildL1Actions()

This function generates all L1 transactions targeting the SP1 and Risc0 verifier contracts. Each action contains specific calldata for updating verifier configurations:

**SP1 Verifier** (4 configuration calls):

- Action 0: setProgramTrusted(008f96447139673b3f2d29b30ad4b43fe6ccb3f31d40f6e61478ac5640201d9e, true)
- Action 1: setProgramTrusted(47cb22384e59cecf65a536612d4b43fe36659f987503db9828f158ac40201d9e, true)
- Action 2: setProgramTrusted(004775b86041915596830bbc5464584165b2641a277b6758e83723954946bee2, true)
- Action 3: setProgramTrusted(23badc30106455655061778a464584162d9320d11ded9d63506e472a4946bee2, true)

**Risc0 Verifier** (3 configuration calls):

- Action 4: setImageIdTrusted(0xed7615813d933868e2ac698df98209b45e6c34c435df2d3c97754bb6739d541d5fd312e3, true)
- Action 5: setImageIdTrusted(0xed761581326ce3b6f13708a0691ed4bc56e8c14d6ee4e1197c533c129b441e263350b87e, true)
- Action 6: upgradeTo(0xDF6327caafC5FeB8910777Ac811e0B1d27dCdf36)

### Action Bytecode Verification

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

Despite thorough testing, execution risks remain. Should the actions fail, a follow-up proposal will be submitted. This process contributes to continuous improvement in proposal reliability and infrastructure resilience.

The verifier updates are critical for maintaining the security and functionality of the Taiko protocol's proof verification system. These changes enable support for updated proof generation systems and ensure continued protocol operation.
