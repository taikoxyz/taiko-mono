// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BuildProposal.sol";
import { LibMainnetL1Addresses as L1 } from "src/layer1/mainnet/libs/LibMainnetL1Addresses.sol";

interface ITestDelegateOwnedV2 {
    function withdraw(address _token, address _to, uint256 _amount) external;
}

contract Proposal0002 is BuildProposal {
    // L1 contracts
    address public constant L1_TAIKO_DAO_CONTROLLER_NEW_IMPL =
        0x6aC624FD2b3Bf8fbf1b121f7Aba0d1eC51f4c347;

    // L2 contracts
    address public constant L2_DELEGATE_CONTROLLER_NEW_IMPL = address(0); // TODO
    address public constant L2_TEST_CONTRACT = address(0); // TODO
    address public constant L2_TEST_CONTRACT_NEW_IMPL = address(0); // TODO
    address public constant L2_DANIEL_WANG_ADDRESS = 0xf0A0d6Bd4aA94F53F3FB2c88488202a9E9eD2c55;

    // FOUNDRY_PROFILE=layer1 forge test --mt test_proposal_0002 -vvv
    function test_proposal_0002() public pure {
        buildProposal({ executionId: 0, gasLimit: 25_000_000 });
    }

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](1);

        // Upgrade TaikoDAOController to a new implementation
        actions[0] = buildUpgradeAction(L1.DAO_CONTROLLER, L1_TAIKO_DAO_CONTROLLER_NEW_IMPL);
    }

    function buildL2Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](5);

        // Upgrade DelegateOwner to a new implementation
        actions[0] = buildUpgradeAction(L2_DELEGATE_CONTROLLER, L2_DELEGATE_CONTROLLER_NEW_IMPL);

        // Transfer 1 TAIKO to Daniel Wang
        actions[1] = Controller.Action({
            target: L2_TAIKO_TOKEN,
            value: 0,
            data: abi.encodeCall(IERC20.transfer, (L2_DANIEL_WANG_ADDRESS, 1 ether))
        });

        // Upgrade TestDelegateOwned to a new implementation
        actions[2] = buildUpgradeAction(L2_TEST_CONTRACT, L2_TEST_CONTRACT_NEW_IMPL);

        // Transfer 0.001 Ether from TestDelegateOwned to Daniel Wang
        actions[3] = Controller.Action({
            target: L2_TEST_CONTRACT,
            value: 0,
            data: abi.encodeCall(
                ITestDelegateOwnedV2.withdraw, (address(0), L2_DANIEL_WANG_ADDRESS, 0.001 ether)
            )
        });

        // Transfer 1 TAIKO from TestDelegateOwned to Daniel Wang
        actions[4] = Controller.Action({
            target: L2_TEST_CONTRACT,
            value: 0,
            data: abi.encodeCall(
                ITestDelegateOwnedV2.withdraw, (L2_TAIKO_TOKEN, L2_DANIEL_WANG_ADDRESS, 1 ether)
            )
        });
    }
}
