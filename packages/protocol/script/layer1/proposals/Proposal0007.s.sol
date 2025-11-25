// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";
import { ForkRouter } from "src/shared/fork-router/ForkRouter.sol";

// To print the proposal action data: `P=0007 pnpm proposal`
// To dryrun the proposal on L1: `P=0007 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0007 pnpm proposal:dryrun:l2`
contract Proposal0007 is BuildProposal {
    // TODO: set to the Shasta inbox proxy address before execution.
    address public constant SHASTA_INBOX_PROXY = 0x0000000000000000000000000000000000000000;

    function buildL1Actions() internal view override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](2);

        actions[0] =
            buildUpgradeAction(L1.SIGNAL_SERVICE, ForkRouter(payable(L1.SIGNAL_SERVICE)).newFork());

        actions[1] = Controller.Action({
            target: SHASTA_INBOX_PROXY, value: 0, data: abi.encodeWithSignature("acceptOwnership()")
        });
    }

    function buildL2Actions()
        internal
        view
        override
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory actions)
    {
        l2ExecutionId = 0;
        l2GasLimit = 1_500_000;
        actions = new Controller.Action[](2);

        actions[0] =
            buildUpgradeAction(L2.SIGNAL_SERVICE, ForkRouter(payable(L2.SIGNAL_SERVICE)).newFork());
        actions[1] = buildUpgradeAction(L2.ANCHOR, ForkRouter(payable(L2.ANCHOR)).newFork());
    }
}
