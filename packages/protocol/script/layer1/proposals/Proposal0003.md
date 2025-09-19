# Cross-Chain Proposal Test (3rd)

This proposal demonstrates the Taiko DAO's capability to execute multiple cross-chain actions involving only Layer 2 (L2) operations.

## L1 Actions

There is no L1 actions in this proposal.

## L2 Actions

The following L2 actions will be executed via the DelegateController contract:

- Transfer 0.0001 Ether from DelegateController to Daniel Wang
- Transfer 1 TAIKO from DelegateController to Daniel Wang
- Upgrade BarUpgradeable to use a new (but identical)implementation
- Transfer BarUpgradeable's ownership to Daniel Wang
- Transfer 0.0001 Ether from BarUpgradeable to Daniel Wang
- Transfer 1 TAIKO from BarUpgradeable to Daniel Wang

These actions aim to validate that the DelegateController can also securely manage and transfer both Ether and tokens.

## Action Verification

### Action Generation

All actions in this proposal are generated using the following script:

https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/script/layer1/proposals/Proposal0003.s.sol

Please review the `proposalConfig()`, `buildL1Actions()`, and `buildL2Actions()` functions for logic verification.

### proposalConfig()

This function returns execution parameters for L2:

- `l2ExecutionId`: Determines the execution order. Here, `l2ExecutionId = 1`, which enforces that the proposal must execute in sequence. Setting this value to `0` would skip ordering constraints, allowing execution at any time after approval.
- `l2GasLimit`: Specifies the minimum gas required for executing L2 actions. This proposal sets the limit to `25,000,000`, allowing any L2 address to trigger execution.

### buildL1Actions()

This function generates all L1 transactions. The final action in the list sends a cross-chain message via the Taiko bridge, embedding the L2 action payload. This message targets the L2 DelegateController contract to execute the L2 actions sequentially.

###buildL2Actions()

This function defines the atomic set of L2 transactions. If any single action fails, the entire batch is reverted. Nevertheless, the proposal is still marked as executed from the DAO's perspective.

L2 execution is permissionless and may be initiated by any address that supplies a gas limit of at least `25,000,000`.

### Action Bytecode Verification

To confirm the action data matches this proposal, clone the Taiko [monorepo](https://github.com/taikoxyz/taiko-mono), navigate to `packages/protocol`, run `pnpm install`, then:

```bash
P=0003 pnpm proposal
```

This will print the generated calldata and write it to Proposal0003.action.md for comparison. Byte-by-byte validation can then be performed.

### Dryrun Execution

To test the executability of the actions, use:

```bash
P=0003 pnpm proposal:dryrun:l1
P=0003 pnpm proposal:dryrun:l2
```

If the execution ends in a revert with `DryrunSucceeded`, this indicates the current on-chain state allows for successful execution. Note that state changes from other proposals may affect future outcomes.

Please be aware that `l2ExecutionId` won't be verified during the dryrun.

## Risks and Contingencies

Despite thorough testing, execution risks remain. Should the actions fail, a follow-up proposal will be submitted. This process contributes to continuous improvement in proposal reliability and infrastructure resilience.
