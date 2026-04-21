// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0012 pnpm proposal`
// To dryrun the proposal on L1: `P=0012 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0012 pnpm proposal:dryrun:l2`
contract Proposal0012 is BuildProposal {
    address public constant INBOX_IMPL = 0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261;

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        // L1: 4 protocol upgrades + 6 ZK verifier registrations + 3 SGX mrenclave updates = 13
        actions = new Controller.Action[](1);

        // --- Protocol upgrades (4) ---
        // Upgrade L1 Inbox proxy to the optimized Shasta implementation.
        actions[0] = buildUpgradeAction(L1.INBOX, INBOX_IMPL);
    }

  
}
