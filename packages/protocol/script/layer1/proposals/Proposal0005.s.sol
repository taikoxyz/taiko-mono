// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0005 pnpm proposal`
// To dryrun the proposal on L1: `P=0005 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0005 pnpm proposal:dryrun:l2`
contract Proposal0005 is BuildProposal {
    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](1);

        // Get the current balance of TAIKO tokens held by the Controller
        uint256 amount = 94_020_735 ether;

        // Transfer all TAIKO tokens from Controller to treasury.taiko.eth
        actions[0] = buildERC20TransferAction(TAIKO_TOKEN, TAIKO_FOUNDATION_TREASURY, amount);
    }
}
