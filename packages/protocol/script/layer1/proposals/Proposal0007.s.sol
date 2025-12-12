// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0007 pnpm proposal`
// To dryrun the proposal on L1: `P=0007 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0007 pnpm proposal:dryrun:l2`
contract Proposal0007 is BuildProposal {
    // L1 TaikoInbox (proxy) and new implementation with 0.0025 gwei curve floor
    address public constant TAIKO_INBOX = 0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a;
    // https://codediff.taiko.xyz/?addr=0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a&newimpl=0x7b4dBB1bCF546e181958B8c053806a95332553dD&chainid=1
    address public constant TAIKO_INBOX_NEW_IMPL = 0x7b4dBB1bCF546e181958B8c053806a95332553dD;

    // L2 TaikoAnchor (proxy) and new implementation without BASEFEE_MIN_VALUE hard floor
    address public constant TAIKO_L2 = 0x1670000000000000000000000000000000010001;
    https://codediff.taiko.xyz/?addr=0x1670000000000000000000000000000000010001&newimpl=0x7b4dBB1bCF546e181958B8c053806a95332553dD&chainid=167000
    address public constant TAIKO_L2_NEW_IMPL = 0x7b4dBB1bCF546e181958B8c053806a95332553dD;

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](1);

        // Upgrade TaikoInbox to pick up the lowered minGasExcess (curve floor ~0.0025 gwei)
        actions[0] = buildUpgradeAction(TAIKO_INBOX, TAIKO_INBOX_NEW_IMPL);
    }

    function buildL2Actions()
        internal
        pure
        override
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory actions)
    {
        l2ExecutionId = 7;
        l2GasLimit = 500_000;
        actions = new Controller.Action[](1);

        // Upgrade TaikoAnchor to update BASEFEE_MIN_VALUE
        actions[0] = buildUpgradeAction(TAIKO_L2, TAIKO_L2_NEW_IMPL);
    }
}
