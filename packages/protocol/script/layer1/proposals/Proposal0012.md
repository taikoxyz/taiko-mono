# PROPOSAL-0012: Emergency Re-arm of Shasta Inbox `pendingOwner` to Unblock Proposal28

## Executive Summary

This proposal is an **emergency proposal** intended for the **Emergency Multisig** path, not the
Standard Multisig path.

It executes a single L1 action that re-nominates `controller.taiko.eth` (the DAO controller)
as `pendingOwner` of the Shasta inbox proxy, so that the previously-approved
[Proposal28 (Proposal0011)](./Proposal0011.md) can be executed without reverting.

There are no L2 actions. No new contracts are deployed.

## Rationale

[Proposal28 (Proposal0011)](./Proposal0011.md) was approved by the Security Council on Apr 9, 2026
and passed its 10-day veto window on Apr 19, 2026. Its first L1 action calls
`acceptOwnership()` on the Shasta inbox proxy `L1.INBOX`. This action requires
`pendingOwner == controller.taiko.eth` at execution time.

The activator multisig (`0xF14Dc4EdDb43e9a6A440e6beC97ea2ea64f39Ef7`) correctly set
`pendingOwner = controller.taiko.eth` in tx
[`0x362c698c…`](https://etherscan.io/tx/0x362c698cf905d67a35d3c6d679398baa300fe2658b2c03240feea0fbb8c0eb0a),
satisfying the precondition.

Before Proposal28 was executed, EOA `0x56706F118e42AE069F20c5636141B844D1324AE1`
called the permissionless helper `Controller.acceptOwnershipOf(L1.INBOX)` on the DAO
controller in tx
[`0xf008fe58…`](https://etherscan.io/tx/0xf008fe58930f7d05f5d80421bdd02a9e03ff5329c935d77515021b75eaee1b98)
on Apr 21, 2026 at 08:09:23 UTC. That call made the DAO controller accept ownership
of the inbox outside the proposal flow, leaving the inbox in this state:

- `L1.INBOX.owner()` is now `controller.taiko.eth` ✓
- `L1.INBOX.pendingOwner()` is now `address(0)` ✗

Executing Proposal28 in this state reverts on its first action (`acceptOwnership()`)
with `Ownable2Step: caller is not the new owner`. `Controller._executeAction` does
not catch sub-call failures, so the entire `execute(bytes)` transaction reverts:
the L1 SignalService upgrade and the cross-chain bridge call carrying the two L2
upgrades never run, the fork-router cleanup never lands, and Proposal28's SC and
veto cycle is wasted.

This emergency proposal restores the precondition by having the DAO controller call
`transferOwnership(controller.taiko.eth)` on the inbox. OpenZeppelin's
`Ownable2StepUpgradeable.transferOwnership` does not require `newOwner != owner`, so
the controller can nominate itself as `pendingOwner`. With `pendingOwner` set back
to the DAO controller, Proposal28's `acceptOwnership()` action succeeds, the rest
of its bundle proceeds normally, and the temporary fork routers are retired.

## Technical Specification

### L1 Actions (1 total)

1. Call `transferOwnership(controller.taiko.eth)` on `L1.INBOX`.
   - target: `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f`
   - calldata: `0xf2fde38b00000000000000000000000075ba76403b13b26ad1bec70d6ee937314eeacd0a`
   - effect: `L1.INBOX.pendingOwner()` becomes `0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a`
     (`controller.taiko.eth`).

There are no L2 actions in this proposal.

## Verification

Before submission, confirm:

- `L1.INBOX.owner()` is `controller.taiko.eth` (`0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a`)
- `L1.INBOX.pendingOwner()` is `address(0)`

Generate calldata and dryrun on a mainnet fork:

```bash
P=0012 pnpm proposal
P=0012 pnpm proposal:dryrun:l1
```

The dryrun should revert with `DryrunSucceeded()`.

After execution, `L1.INBOX.pendingOwner()` is `controller.taiko.eth` and the inbox is
ready for Proposal28's `acceptOwnership()` action.

## Security Contacts

- security@taiko.xyz
