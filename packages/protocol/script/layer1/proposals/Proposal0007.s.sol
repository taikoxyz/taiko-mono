// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0007 pnpm proposal`
// To dryrun the proposal on L1: `P=0007 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0007 pnpm proposal:dryrun:l2`
contract Proposal0007 is BuildProposal {
    // https://codediff.taiko.xyz/?addr=0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a&newimpl=0x7b4dBB1bCF546e181958B8c053806a95332553dD&chainid=1
    address public constant INBOX_NEW_IMPL = 0x7b4dBB1bCF546e181958B8c053806a95332553dD;

    //https://codediff.taiko.xyz/?addr=0x1670000000000000000000000000000000010001&newimpl=0xeaB88687835b87f9a9DF22fA42E16153fE7b25BB&chainid=167000
    address public constant ANCHOR_NEW_IMPL = 0xeaB88687835b87f9a9DF22fA42E16153fE7b25BB;

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](1);
        actions[0] = buildUpgradeAction(L1.INBOX, INBOX_NEW_IMPL);
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
