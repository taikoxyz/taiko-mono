// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0018 pnpm proposal`
// To dryrun the proposal on L1: `P=0018 pnpm proposal:dryrun:l1`
contract Proposal0018 is BuildProposal {
    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](2);

        actions[0] = Controller.Action({
            target: L1.BRIDGE, value: 0, data: abi.encodeCall(IProposal0018Pausable.unpause, ())
        });

        actions[1] = Controller.Action({
            target: L1.ERC20_VAULT,
            value: 0,
            data: abi.encodeCall(IProposal0018Pausable.unpause, ())
        });
    }
}

interface IProposal0018Pausable {
    function unpause() external;
}
