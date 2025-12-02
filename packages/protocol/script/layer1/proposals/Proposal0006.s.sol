// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0006 pnpm proposal`
// To dryrun the proposal on L1: `P=0006 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0006 pnpm proposal:dryrun:l2`
contract Proposal0006 is BuildProposal {
    address private constant _NEW_INBOX = 0xB0600e011e02eD35A142B45B506B16A35493c3F5;

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](1);
        actions[0] = buildUpgradeAction(L1.INBOX, _NEW_INBOX);
    }
}
