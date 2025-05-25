// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BuildProposal.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/libs/LibL1Addrs.sol";

interface IBarContract {
    function withdraw(address _token, address _to, uint256 _amount) external;
}

interface IReverseRegistrar {
    function setName(string memory name) external returns (bytes32);
}

// To print the proposal action data: `P=0002 pnpm proposal`
// To dryrun the proposal on L1: `P=0002 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0002 pnpm proposal:dryrun:l2`
contract Proposal0002 is BuildProposal {
    // L1 contracts
    address public constant L1_FOO_CONTRACT = 0x4c234082E57d7f82AB8326A338d8F17FAbEdbd97;
    address public constant L1_DANIEL_WANG_ADDRESS = 0xf0A0d6Bd4aA94F53F3FB2c88488202a9E9eD2c55;

    // L2 contracts
    address public constant L2_BAR_CONTRACT = 0x877DDC3AebDD3010714B16769d6dB0Cb11abaF30;
    address public constant L2_BAR_CONTRACT_NEW_IMPL = 0xCA335abAcaDe77a8C3e2E82B551B3E3337f2CaF4;
    address public constant L2_DANIEL_WANG_ADDRESS = 0xf0A0d6Bd4aA94F53F3FB2c88488202a9E9eD2c55;

    function proposalConfig()
        internal
        pure
        override
        returns (uint64 l2ExecutionId, uint32 l2GasLimit)
    {
        l2ExecutionId = 1;
        l2GasLimit = 25_000_000;
    }

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](4);

        // Set the reverse ENS name of the DAOController to "controller.taiko.eth"
        actions[0] = Controller.Action({
            target: L1.ENS_REVERSE_REGISTRAR,
            value: 0,
            data: abi.encodeCall(IReverseRegistrar.setName, ("controller.taiko.eth"))
        });

        // Transfer 0.0001 ETH from DAOController to Daniel Wang
        actions[1] =
            Controller.Action({ target: L1_DANIEL_WANG_ADDRESS, value: 0.0001 ether, data: "" });

        // Transfer 1 USDC from DAOController to Daniel Wang
        actions[2] = Controller.Action({
            target: L1.USDC_TOKEN,
            value: 0,
            data: abi.encodeCall(IERC20.transfer, (L1_DANIEL_WANG_ADDRESS, 1e6))
        });

        // Transfer FooUpgradeable's ownership to Daniel Wang
        actions[3] = Controller.Action({
            target: L1_FOO_CONTRACT,
            value: 0,
            data: abi.encodeCall(Ownable.transferOwnership, (L1_DANIEL_WANG_ADDRESS))
        });
    }

    function buildL2Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](6);

        // Transfer 0.0001 Ether from DelegateController to Daniel Wang
        actions[0] =
            Controller.Action({ target: L2_DANIEL_WANG_ADDRESS, value: 0.0001 ether, data: "" });

        // Transfer 1 TAIKO from DelegateController to Daniel Wang
        actions[1] = Controller.Action({
            target: L2.TAIKO_TOKEN,
            value: 0,
            data: abi.encodeCall(IERC20.transfer, (L2_DANIEL_WANG_ADDRESS, 1 ether))
        });

        // Upgrade BarUpgradeable to use a new (but identical)implementation
        actions[2] = buildUpgradeAction(L2_BAR_CONTRACT, L2_BAR_CONTRACT_NEW_IMPL);

        // Transfer BarUpgradeable's ownership to Daniel Wang
        actions[3] = Controller.Action({
            target: L2_BAR_CONTRACT,
            value: 0,
            data: abi.encodeCall(Ownable.transferOwnership, (L2_DANIEL_WANG_ADDRESS))
        });

        // Transfer 0.0001 Ether from BarUpgradeable to Daniel Wang
        actions[4] = Controller.Action({
            target: L2_BAR_CONTRACT,
            value: 0,
            data: abi.encodeCall(
                IBarContract.withdraw, (address(0), L2_DANIEL_WANG_ADDRESS, 0.0001 ether)
            )
        });

        // Transfer 1 TAIKO from BarUpgradeable to Daniel Wang
        actions[5] = Controller.Action({
            target: L2_BAR_CONTRACT,
            value: 0,
            data: abi.encodeCall(
                IBarContract.withdraw, (L2.TAIKO_TOKEN, L2_DANIEL_WANG_ADDRESS, 1 ether)
            )
        });
    }
}
