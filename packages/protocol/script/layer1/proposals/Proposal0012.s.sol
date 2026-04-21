// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0012 pnpm proposal`
// To dryrun the proposal on L1: `P=0012 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0012 pnpm proposal:dryrun:l2`
contract Proposal0012 is BuildProposal {
    // TODO(david): deploy the new inbox contract on Ethereum and update this address.
    address public constant INBOX_IMPL = address(0);

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](1);
        actions[0] = buildUpgradeAction(L1.INBOX, INBOX_IMPL);
    }
}
