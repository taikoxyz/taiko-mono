// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0006 pnpm proposal`
// To dryrun the proposal on L1: `P=0006 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0006 pnpm proposal:dryrun:l2`
// NOTE: Deploy new implementations first:
// - L1 SignalServiceForkRouter + PreconfWhitelist via script/layer1/mainnet/DeployShasta.s.sol
// - L2 SignalServiceForkRouter + Anchor via script/layer2/DeployShasta.s.sol
// Then replace all placeholder impl addresses before executing this proposal.
contract Proposal0006 is BuildProposal {
    address public constant SIGNAL_SERVICE_PROXY = L1.SIGNAL_SERVICE;

    // Placeholder; update after deploying the new SignalServiceForkRouter (L1).
    address public constant SIGNAL_SERVICE_NEW_IMPL = 0x0000000000000000000000000000000000000000;

    // Preconf whitelist proxy on L1 (rollup resolver name: preconf_whitelist).
    address public constant PRECONF_WHITELIST_PROXY = 0xFD019460881e6EeC632258222393d5821029b2ac;

    // Placeholder; update after deploying the new PreconfWhitelist implementation.
    address public constant PRECONF_WHITELIST_NEW_IMPL = 0x0000000000000000000000000000000000000000;

    // L2 proxies (Taiko mainnet L2).
    address public constant L2_SIGNAL_SERVICE_PROXY = L2.SIGNAL_SERVICE;
    address public constant L2_ANCHOR_PROXY = L2.ANCHOR;

    // Placeholders; update after deploying SignalServiceForkRouter and Anchor (L2) via
    // script/layer2/DeployShasta.s.sol.
    address public constant L2_SIGNAL_SERVICE_NEW_IMPL = 0x0000000000000000000000000000000000000000;
    address public constant L2_ANCHOR_NEW_IMPL = 0x0000000000000000000000000000000000000000;

    uint32 public constant L2_GAS_LIMIT = 1_500_000;

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](2);

        actions[0] = buildUpgradeAction(SIGNAL_SERVICE_PROXY, SIGNAL_SERVICE_NEW_IMPL);
        actions[1] = buildUpgradeAction(PRECONF_WHITELIST_PROXY, PRECONF_WHITELIST_NEW_IMPL);
    }

    function buildL2Actions()
        internal
        pure
        override
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory actions)
    {
        l2ExecutionId = 0;
        l2GasLimit = L2_GAS_LIMIT;
        actions = new Controller.Action[](2);

        actions[0] = buildUpgradeAction(L2_SIGNAL_SERVICE_PROXY, L2_SIGNAL_SERVICE_NEW_IMPL);
        actions[1] = buildUpgradeAction(L2_ANCHOR_PROXY, L2_ANCHOR_NEW_IMPL);
    }
}
