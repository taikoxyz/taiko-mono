// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BuildProposal.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/libs/LibL1Addrs.sol";

interface IBarContract {
    function withdraw(address _token, address _to, uint256 _amount) external;
}

// To print the proposal action data: `P=0002 pnpm proposal`
// To dryrun the proposal on L1: `P=0002 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0002 pnpm proposal:dryrun:l2`
contract Proposal0002 is BuildProposal {
    // L1 contracts
    address public constant L1_DANIEL_WANG_ADDRESS = 0xf0A0d6Bd4aA94F53F3FB2c88488202a9E9eD2c55;
    address public constant L1_FOO_CONTRACT = 0xD1Ed20C8fEc53db3274c2De09528f45dF6c06A65;
    // address public constant L1_DAO_CONTROLLER_NEW_IMPL =
    // 0x7a7CE80502c46C768B8d341dcbaa99Ffe7338f33;

    // L2 contracts
    address public constant L2_DELEGATE_CONTROLLER_NEW_IMPL =
        0x6f4006D0f805B55D1106dFdDfb73C3D53d12c12D;
    address public constant L2_BAR_CONTRACT = 0xD381F8e696a8e20a5d0c0a8658e5C1Cb23C0AB69;
    address public constant L2_BAR_CONTRACT_NEW_IMPL = 0x4c234082E57d7f82AB8326A338d8F17FAbEdbd97;
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
        actions = new Controller.Action[](3);

        // Transfer 0.001 ETH from DAO Controller to Daniel Wang
        actions[0] =
            Controller.Action({ target: L1_DANIEL_WANG_ADDRESS, value: 0.001 ether, data: "" });

        // Transfer 1 USDC from DAO Controller to Daniel Wang
        actions[1] = Controller.Action({
            target: L1.USDC_TOKEN,
            value: 0,
            data: abi.encodeCall(IERC20.transfer, (L1_DANIEL_WANG_ADDRESS, 1e6))
        });

        // Transfer Foo contract ownership to Daniel Wang
        actions[2] = Controller.Action({
            target: L1_FOO_CONTRACT,
            value: 0,
            data: abi.encodeCall(Ownable.transferOwnership, (L1_DANIEL_WANG_ADDRESS))
        });
    }

    function buildL2Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](6);

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

        // Transfer 1 TAIKO from Bar contract to Daniel Wang
        actions[3] = Controller.Action({
            target: L2_BAR_CONTRACT,
            value: 0,
            data: abi.encodeCall(
                IBarContract.withdraw, (L2.TAIKO_TOKEN, L2_DANIEL_WANG_ADDRESS, 1 ether)
            )
        });

        // Transfer 0.001 Ether from Bar contract to Daniel Wang
        actions[4] = Controller.Action({
            target: L2_BAR_CONTRACT,
            value: 0,
            data: abi.encodeCall(
                IBarContract.withdraw, (address(0), L2_DANIEL_WANG_ADDRESS, 0.001 ether)
            )
        });

        // Transfer Bar contract ownership to Daniel Wang
        actions[5] = Controller.Action({
            target: L2_BAR_CONTRACT,
            value: 0,
            data: abi.encodeCall(Ownable.transferOwnership, (L2_DANIEL_WANG_ADDRESS))
        });
    }
}
