// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0012 pnpm proposal`
// To dryrun the proposal on L1: `P=0012 pnpm proposal:dryrun:l1`
contract Proposal0012 is BuildProposal {
    // Emergency proposal that re-nominates `controller.taiko.eth` as `pendingOwner`
    // of the Shasta inbox proxy so Proposal0011 can execute without reverting.
    // See `Proposal0012.md` for full context.
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
