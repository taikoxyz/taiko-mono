// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0006 pnpm proposal`
// To dryrun the proposal on L1: `P=0006 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0006 pnpm proposal:dryrun:l2`
// TODO: run L1 / L2 deployment scripts after the audit, then update the new implementation addresses
// below, and generate `Proposal0006.action.md`.
contract Proposal0006 is BuildProposal {
    // TODO: update these addresses after deployment.
    address public constant L1_SIGNAL_SERVICE_FORK_ROUTER =
        0x0000000000000000000000000000000000000000;
    address public constant L1_PRECONF_WHITELIST_NEW_IMPL =
        0x0000000000000000000000000000000000000000;
    address public constant L2_SIGNAL_SERVICE_FORK_ROUTER =
        0x0000000000000000000000000000000000000000;
    address public constant L2_ANCHOR_FORK_ROUTER = 0x0000000000000000000000000000000000000000;

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](2);

        actions[0] = buildUpgradeAction(L1.SIGNAL_SERVICE, L1_SIGNAL_SERVICE_FORK_ROUTER);
        actions[1] = buildUpgradeAction(L1.PRECONF_WHITELIST, L1_PRECONF_WHITELIST_NEW_IMPL);
    }

    function buildL2Actions()
        internal
        pure
        override
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory actions)
    {
        // Since we only have one actions list to execute, we set `executionId` to `0`, to
        // skip the `executionId` check in `DelegateController.onMessageInvocation`.
        l2ExecutionId = 0;
        l2GasLimit = 1_500_000;
        actions = new Controller.Action[](2);

        actions[0] = buildUpgradeAction(L2.SIGNAL_SERVICE, L2_SIGNAL_SERVICE_FORK_ROUTER);
        actions[1] = buildUpgradeAction(L2.ANCHOR, L2_ANCHOR_FORK_ROUTER);
    }
}
