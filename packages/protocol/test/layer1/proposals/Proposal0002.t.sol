// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BuildProposal.sol";
import { LibMainnetL1Addresses as L1 } from "src/layer1/mainnet/libs/LibMainnetL1Addresses.sol";

interface IBarContract {
    function withdraw(address _token, address _to, uint256 _amount) external;
}

// FOUNDRY_PROFILE=layer1 forge test --mt test_proposal_0002 -vvv
contract Proposal0002 is BuildProposal {
    function test_proposal_0002() public pure {
        buildProposal({ executionId: 1, l2GasLimit: 25_000_000 });
    }

    function buildL2Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](1);

        // Upgrade DelegateController to a new implementation
        actions[0] =
            buildUpgradeAction(L2.DELEGATE_CONTROLLER, 0x15a4109238d5673C9E6Cca27831AEF1AfdA99830);
    }
}
