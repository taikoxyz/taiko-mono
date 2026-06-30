// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { Proposal0018 } from "script/layer1/proposals/Proposal0018.s.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { Controller } from "src/shared/governance/Controller.sol";

/// @custom:security-contact security@taiko.xyz
contract Proposal0018Test is Test {
    function test_buildL1Actions_EncodesBridgeAndErc20VaultUnpause() external {
        Proposal0018Harness proposal = new Proposal0018Harness();

        Controller.Action[] memory actions = proposal.exposedBuildL1Actions();

        assertEq(actions.length, 2);

        assertEq(actions[0].target, L1.BRIDGE);
        assertEq(actions[0].value, 0);
        assertEq(actions[0].data, abi.encodeCall(IProposal0018TestPausable.unpause, ()));

        assertEq(actions[1].target, L1.ERC20_VAULT);
        assertEq(actions[1].value, 0);
        assertEq(actions[1].data, abi.encodeCall(IProposal0018TestPausable.unpause, ()));
    }
}

contract Proposal0018Harness is Proposal0018 {
    function exposedBuildL1Actions() external pure returns (Controller.Action[] memory) {
        return buildL1Actions();
    }
}

interface IProposal0018TestPausable {
    function unpause() external;
}
