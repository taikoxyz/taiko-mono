// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0012 pnpm proposal`
// To dryrun the proposal on L1: `P=0012 pnpm proposal:dryrun:l1`
contract Proposal0012 is BuildProposal {
    // Upgrade the Shasta Inbox to the gas-optimized implementation that adds
    // `proposeDefault()` / `proposeCompact(...)` entry points and a
    // `nonReentrant` guard on `prove()`. Storage layout is unchanged.
    //
    // TODO: set to the deployed Inbox implementation address before submitting;
    // `proposal:dryrun:l1` will revert while this is `address(0)`.
    address public constant INBOX_NEW_IMPL = address(0);

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](1);
        actions[0] = buildUpgradeAction(L1.INBOX, INBOX_NEW_IMPL);
    }
}
