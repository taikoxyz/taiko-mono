// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BuildProposal.sol";

// To print the proposal action data: `P=0001 pnpm proposal`
// To dryrun the proposal on L1: `P=0001 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0001 pnpm proposal:dryrun:l2`
contract Proposal0001 is BuildProposal {
    address public constant L1_FOO_CONTRACT = 0x4c234082E57d7f82AB8326A338d8F17FAbEdbd97;
    address public constant L2_BAR_CONTRACT = 0x0e577Bb67d38c18E4B9508984DA36d6D316ade58;

    function proposalConfig()
        internal
        pure
        override
        returns (uint64 l2ExecutionId, uint32 l2GasLimit)
    {
        l2ExecutionId = 0;
        l2GasLimit = 1000000;
    }

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) { 
        actions = new Controller.Action[](1);
        actions[0] = Controller.Action({
            target: L1_FOO_CONTRACT,
            value: 0,
            data: abi.encodeCall(Ownable.transferOwnership, (address(0x1)))
        });
    }

    function buildL2Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](1);
         actions[0] = Controller.Action({
            target: L2_BAR_CONTRACT,
            value: 0,
            data: abi.encodeCall(Ownable.transferOwnership, (address(0x1)))
        });
    }
}
