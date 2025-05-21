// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/layer2/mainnet/DelegateController.sol";
import "src/layer1/governance/TaikoDAOController.sol";
import "test/shared/thirdparty/Multicall3.sol";
import "src/shared/bridge/IBridge.sol";
import { LibMainnetL1Addresses as L1 } from "src/layer1/mainnet/libs/LibMainnetL1Addresses.sol";
import { LibMainnetL2Addresses as L2 } from "src/layer2/mainnet/LibMainnetL2Addresses.sol";

abstract contract BuildProposal is Test {
    function buildL1Actions() internal pure virtual returns (Controller.Action[] memory);
    function buildL2Actions() internal pure virtual returns (Controller.Action[] memory);

    function buildUpgradeAction(
        address _target,
        address _newImpl
    )
        internal
        pure
        returns (Controller.Action memory)
    {
        return Controller.Action({
            target: _target,
            value: 0,
            data: abi.encodeCall(UUPSUpgradeable.upgradeTo, (_newImpl))
        });
    }

    function buildProposal(uint64 executionId, uint32 l2GasLimit) internal pure {
        Controller.Action[] memory l1Actions = buildL1Actions();
        Controller.Action[] memory allActions = new Controller.Action[](l1Actions.length + 1);

        for (uint256 i; i < l1Actions.length; ++i) {
            allActions[i] = l1Actions[i];
        }

        Controller.Action[] memory l2Actions = buildL2Actions();

        IBridge.Message memory message;
        message.destChainId = 167_000;
        message.gasLimit = l2GasLimit;
        message.destOwner = L2.PERMISSIONLESS_EXECUTOR;
        message.data = abi.encodeCall(
            DelegateController.onMessageInvocation, (abi.encode(executionId, l2Actions))
        );

        allActions[l1Actions.length] = Controller.Action({
            target: L1.BRIDGE,
            value: 0,
            data: abi.encodeCall(IBridge.sendMessage, (message))
        });

        bytes memory callData = abi.encodeCall(
            TaikoDAOController.execute, (allActions)
        );
    
        console2.log("Num of L1 actions:", l1Actions.length);
        console2.log("Num of L2 actions:", l2Actions.length);
        console2.log("L2 gas limit:", l2GasLimit);
        console2.log("Target:", L1.DAO_CONTROLLER);
        console2.log("Data:");
        console2.logBytes(callData);
    }
}
