// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0009 pnpm proposal`
// To dryrun the proposal on L1: `P=0009 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0009 pnpm proposal:dryrun:l2`
contract Proposal0009 is BuildProposal {
    address public constant PRECONF_WHITELIST_NEW_IMPL = 0xDBae46E35C18719E6c78aaBF9c8869c4eC84c149;
    address public constant PROVER_WHITELIST_PROXY = 0xEa798547d97e345395dA071a0D7ED8144CD612Ae;
    address public constant SIGNAL_SERVICE_FORK_ROUTER_L1 =
        0x6a4B15E4b0296B2ECE03Ee9Ed74E4A3E3ECA68D6;
    address public constant ANCHOR_FORK_ROUTER_L2 = 0x38e4A497aD70aa0581BAc29747b0Ea7a53258585;
    address public constant SIGNAL_SERVICE_FORK_ROUTER_L2 =
        0x2987F6Bef39b03F8522EC38B36aF0f7422938EAb;

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](3);

        // Upgrade L1 PreconfWhitelist proxy to the Shasta implementation.
        actions[0] = buildUpgradeAction(L1.PRECONF_WHITELIST, PRECONF_WHITELIST_NEW_IMPL);

        // Accept ownership for Shasta ProverWhitelist to finalize DAO ownership transfer.
        actions[1] = Controller.Action({
            target: PROVER_WHITELIST_PROXY,
            value: 0,
            data: abi.encodeWithSignature("acceptOwnership()")
        });

        // Upgrade L1 SignalService proxy to the Shasta fork router.
        actions[2] = buildUpgradeAction(L1.SIGNAL_SERVICE, SIGNAL_SERVICE_FORK_ROUTER_L1);
    }

    function buildL2Actions()
        internal
        pure
        override
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory actions)
    {
        l2ExecutionId = 0;
        l2GasLimit = 5_000_000;
        actions = new Controller.Action[](2);

        // Upgrade L2 Anchor proxy to the Shasta fork router.
        actions[0] = buildUpgradeAction(L2.ANCHOR, ANCHOR_FORK_ROUTER_L2);

        // Upgrade L2 SignalService proxy to the Shasta fork router.
        actions[1] = buildUpgradeAction(L2.SIGNAL_SERVICE, SIGNAL_SERVICE_FORK_ROUTER_L2);
    }
}
