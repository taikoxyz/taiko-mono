// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0007 pnpm proposal`
// To dryrun the proposal on L1: `P=0007 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0007 pnpm proposal:dryrun:l2`
contract Proposal0007 is BuildProposal {
    // https://codediff.taiko.xyz/?addr=0x1670000000000000000000000000000000010001&newimpl=0xf381868dd6b2ac8cca468d63b42f9040de2257e9&chainid=167000
    address public constant ANCHOR_NEW_IMPL = 0xf381868DD6B2aC8cca468D63B42F9040DE2257E9;

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](0);
    }

    function buildL2Actions()
        internal
        pure
        override
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory actions)
    {
        l2ExecutionId = 0;
        l2GasLimit = 1_000_000;
        actions = new Controller.Action[](1);

        // Upgrade TaikoAnchor to update BASEFEE_MIN_VALUE
        actions[0] = buildUpgradeAction(L2.ANCHOR, ANCHOR_NEW_IMPL);
    }
}
