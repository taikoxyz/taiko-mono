# PROPOSAL-0011: Retire Shasta Fork Routers

## Executive Summary

This proposal removes the temporary Shasta fork routers that were introduced in [`Proposal0009.s.sol`](./Proposal0009.s.sol) to bridge the Pacaya-to-Shasta transition, and finalizes DAO ownership of the Shasta inbox proxy deployed in PR `#21430`.

It executes **2 L1 actions** from the DAO Controller and **2 L2 actions** through the DelegateController bridge flow:

1. Accept ownership of the Shasta inbox proxy after its current owner has nominated `controller.taiko.eth` as `pendingOwner`.
2. Upgrade L1 `SignalService` from the Shasta fork router to the final Shasta implementation.
3. Upgrade L2 `Anchor` from the Shasta fork router to the final Shasta implementation.
4. Upgrade L2 `SignalService` from the Shasta fork router to the final Shasta implementation.

This proposal does **not** deploy any new contracts. All target implementations were already deployed as part of the Shasta rollout and currently sit behind the temporary routers.

## Verification

Before submission:

1. Confirm current owners:

   - `L1.INBOX.owner()` is `0xF14Dc4EdDb43e9a6A440e6beC97ea2ea64f39Ef7`
   - `L1.INBOX.pendingOwner()` is `controller.taiko.eth` (`0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a`) before executing this proposal

2. Generate proposal calldata:

   ```bash
   P=0011 pnpm proposal
   ```

3. Dryrun on L1:

   ```bash
   P=0011 pnpm proposal:dryrun:l1
   ```

4. Dryrun on L2:

   ```bash
   P=0011 pnpm proposal:dryrun:l2
   ```

After execution:

1. Confirm each proxy points directly to its final Shasta implementation via the EIP-1967 implementation slot.
2. Confirm `L1.INBOX.owner()` is `controller.taiko.eth`.

## Security Contacts

- security@taiko.xyz
