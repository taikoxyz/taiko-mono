// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BuildProposal.sol";
import { LibMainnetL1Addresses as L1 } from "src/layer1/mainnet/libs/LibMainnetL1Addresses.sol";

interface IBarContract {
    function withdraw(address _token, address _to, uint256 _amount) external;
}

// FOUNDRY_PROFILE=layer1 forge script script/layer1/proposals/Proposal0002.s.sol
contract Proposal0002 is BuildProposal {
    // L1 contracts
    address public constant L1_DANIEL_WANG_ADDRESS = 0xf0A0d6Bd4aA94F53F3FB2c88488202a9E9eD2c55;

    // L2 contracts
    address public constant L2_DELEGATE_CONTROLLER_NEW_IMPL =
        0x15a4109238d5673C9E6Cca27831AEF1AfdA99830;
    address public constant L2_BAR_CONTRACT = 0x31de0330c9FDa46FE8a7d84A88531bB8Fc72185f;
    address public constant L2_BAR_CONTRACT_NEW_IMPL = 0x8f752026dC3f53003C4772a81c7b38EA7430fECB;
    address public constant L2_DANIEL_WANG_ADDRESS = 0xf0A0d6Bd4aA94F53F3FB2c88488202a9E9eD2c55;

    function run() external pure {
        (
            bytes memory protocolCallData_,
            bytes memory l1DryrunCallData_,
            bytes memory l2DryrunCallData_
        ) = buildProposal({ executionId: 1, l2GasLimit: 25_000_000 });
    }

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](2);

        // Transfer 0.001 ETH from DAO Controller to Daniel Wang
        actions[0] =
            Controller.Action({ target: L1_DANIEL_WANG_ADDRESS, value: 0.001 ether, data: "" });

        // Transfer 1 USDC from DAO Controller to Daniel Wang
        actions[1] = Controller.Action({
            target: L1.USDC_TOKEN,
            value: 0,
            data: abi.encodeCall(IERC20.transfer, (L1_DANIEL_WANG_ADDRESS, 1e6))
        });
    }

    function buildL2Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](5);

        // Upgrade DelegateController to a new implementation
        actions[0] = buildUpgradeAction(L2.DELEGATE_CONTROLLER, L2_DELEGATE_CONTROLLER_NEW_IMPL);

        // Transfer 1 TAIKO to Daniel Wang
        actions[1] = Controller.Action({
            target: L2.TAIKO_TOKEN,
            value: 0,
            data: abi.encodeCall(IERC20.transfer, (L2_DANIEL_WANG_ADDRESS, 1 ether))
        });

        // Upgrade Bar contract to a new implementation
        actions[2] = buildUpgradeAction(L2_BAR_CONTRACT, L2_BAR_CONTRACT_NEW_IMPL);

        // Transfer 0.001 Ether from Bar contract to Daniel Wang
        actions[3] = Controller.Action({
            target: L2_BAR_CONTRACT,
            value: 0,
            data: abi.encodeCall(
                IBarContract.withdraw, (address(0), L2_DANIEL_WANG_ADDRESS, 0.001 ether)
            )
        });

        // Transfer 1 TAIKO from Bar contract to Daniel Wang
        actions[4] = Controller.Action({
            target: L2_BAR_CONTRACT,
            value: 0,
            data: abi.encodeCall(
                IBarContract.withdraw, (L2.TAIKO_TOKEN, L2_DANIEL_WANG_ADDRESS, 1 ether)
            )
        });
    }
}
