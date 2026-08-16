// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0016 pnpm proposal`
// To dryrun the proposal on L1: `P=0016 pnpm proposal:dryrun:l1`
contract Proposal0016 is BuildProposal {
    address public constant INBOX_NEW_IMPL = 0x349Ae3578f48F758d79451EeAB61Cdd5fedD0098;

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](1);

        // Upgrade the L1 Shasta Inbox proxy to the new implementation.
        actions[0] = buildUpgradeAction(L1.INBOX, INBOX_NEW_IMPL);
    }
}
