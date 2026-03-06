// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0009 pnpm proposal`
// To dryrun the proposal on L1: `P=0009 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0009 pnpm proposal:dryrun:l2`
contract Proposal0009 is BuildProposal {
    // https://codediff.taiko.xyz/?addr=0xfd019460881e6eec632258222393d5821029b2ac&newimpl=0xdbae46e35c18719e6c78aabf9c8869c4ec84c149&chainid=1
    address public constant PRECONF_WHITELIST_NEW_IMPL = 0xDBae46E35C18719E6c78aaBF9c8869c4eC84c149;
    // New contract
    address public constant PROVER_WHITELIST_PROXY = 0xEa798547d97e345395dA071a0D7ED8144CD612Ae;
    // New contract
    address public constant PACAYA_MAINNET_INBOX_NEW_IMPL =
        0x38Dd73fed93F8051E7A0dDd6FB3b9E7C25668187;
    // https://codediff.taiko.xyz/?addr=0x9e0a24964e5397B566c1ed39258e21aB5E35C77C&newimpl=0x6a4b15e4b0296b2ece03ee9ed74e4a3e3eca68d6&chainid=1
    address public constant SIGNAL_SERVICE_FORK_ROUTER_L1 =
        0x6a4B15E4b0296B2ECE03Ee9Ed74E4A3E3ECA68D6;
    // https://codediff.taiko.xyz/?addr=0x1670000000000000000000000000000000010001&newimpl=0x38e4a497ad70aa0581bac29747b0ea7a53258585&chainid=167000
    address public constant ANCHOR_FORK_ROUTER_L2 = 0x38e4A497aD70aa0581BAc29747b0Ea7a53258585;
    // https://codediff.taiko.xyz/?addr=0x1670000000000000000000000000000000000005&newimpl=0x2987f6bef39b03f8522ec38b36af0f7422938eab&chainid=167000
    address public constant SIGNAL_SERVICE_FORK_ROUTER_L2 =
        0x2987F6Bef39b03F8522EC38B36aF0f7422938EAb;

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](4);

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

        // Upgrade L1 Inbox proxy to the Pacaya mainnet implementation.
        actions[3] = buildUpgradeAction(L1.INBOX, PACAYA_MAINNET_INBOX_NEW_IMPL);
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
