// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0011 pnpm proposal`
// To dryrun the proposal on L1: `P=0011 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0011 pnpm proposal:dryrun:l2`
contract Proposal0011 is BuildProposal {
    // Shasta cleanup: retire the temporary fork routers introduced by Proposal0009.
    // https://codediff.taiko.xyz/?addr=0x9e0a24964e5397B566c1ed39258e21aB5E35C77C&newimpl=0xBC442F342FE247Dc7981AC7Fbe8293c8891F8752&chainid=1
    address public constant SIGNAL_SERVICE_NEW_IMPL_L1 = 0xBC442F342FE247Dc7981AC7Fbe8293c8891F8752;
    // https://codediff.taiko.xyz/?addr=0x1670000000000000000000000000000000010001&newimpl=0x7e83Af941FDcf90EB44ED7dc8754a201B156E0BA&chainid=167000
    address public constant ANCHOR_NEW_IMPL_L2 = 0x7e83Af941FDcf90EB44ED7dc8754a201B156E0BA;
    // https://codediff.taiko.xyz/?addr=0x1670000000000000000000000000000000000005&newimpl=0x18B27428cce679DFf84D09D6b07DF1E9EBb6fE28&chainid=167000
    address public constant SIGNAL_SERVICE_NEW_IMPL_L2 = 0x18B27428cce679DFf84D09D6b07DF1E9EBb6fE28;

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](2);

        // Finalize the Shasta inbox ownership handoff to the DAO controller after the
        // current inbox owner has set `pendingOwner` to `controller.taiko.eth`.
        actions[0] = Controller.Action({
            target: L1.INBOX, value: 0, data: abi.encodeWithSignature("acceptOwnership()")
        });

        // Upgrade the L1 SignalService proxy from the Shasta fork router to the final implementation.
        actions[1] = buildUpgradeAction(L1.SIGNAL_SERVICE, SIGNAL_SERVICE_NEW_IMPL_L1);
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

        // Upgrade the L2 Anchor proxy from the Shasta fork router to the final implementation.
        actions[0] = buildUpgradeAction(L2.ANCHOR, ANCHOR_NEW_IMPL_L2);

        // Upgrade the L2 SignalService proxy from the Shasta fork router to the final implementation.
        actions[1] = buildUpgradeAction(L2.SIGNAL_SERVICE, SIGNAL_SERVICE_NEW_IMPL_L2);
    }
}
