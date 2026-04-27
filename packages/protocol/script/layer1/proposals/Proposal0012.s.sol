// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0012 pnpm proposal`
// To dryrun the proposal on L1: `P=0012 pnpm proposal:dryrun:l1`
contract Proposal0012 is BuildProposal {
    // Emergency proposal that re-nominates `controller.taiko.eth` as `pendingOwner`
    // of the Shasta inbox proxy so the previously-approved Proposal0011 can execute
    // without reverting.
    //
    // Proposal0011's first L1 action calls `acceptOwnership()` on `L1.INBOX`, which
    // requires `pendingOwner == controller.taiko.eth`. The activator multisig set
    // that precondition correctly, but EOA 0x56706F11…4AE1 then called the
    // permissionless `Controller.acceptOwnershipOf(L1.INBOX)` on Apr 21, 2026 in tx
    // 0xf008fe58930f7d05f5d80421bdd02a9e03ff5329c935d77515021b75eaee1b98, accepting
    // ownership outside the proposal flow and clearing `pendingOwner` to address(0).
    // Proposal0011 now reverts atomically on its first action with
    // `Ownable2Step: caller is not the new owner`.
    //
    // The DAO controller is the current owner, so it can re-nominate itself as
    // `pendingOwner` via `transferOwnership(controller.taiko.eth)`. After this
    // proposal executes, Proposal0011's `acceptOwnership()` action succeeds.
    //
    // See `Proposal0012.md` for the full rationale and for the front-running risk
    // that requires bundling both `execute(bytes)` calls in the same block.
    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](1);

        // Re-arm `pendingOwner = controller.taiko.eth` on the Shasta inbox proxy.
        actions[0] = Controller.Action({
            target: L1.INBOX,
            value: 0,
            data: abi.encodeWithSignature("transferOwnership(address)", L1.DAO_CONTROLLER)
        });
    }
}
