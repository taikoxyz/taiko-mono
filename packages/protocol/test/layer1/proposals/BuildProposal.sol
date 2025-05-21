// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/layer2/mainnet/DelegateController.sol";
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

    function buildProposal(uint64 executionId, uint32 gasLimit) internal pure {
        Controller.Action[] memory l1Actions = buildL1Actions();
        Controller.Action[] memory allActions = new Controller.Action[](l1Actions.length + 1);

        for (uint256 i; i < l1Actions.length; ++i) {
            allActions[i] = l1Actions[i];
            require(allActions[i].target == L1.DAO_CONTROLLER, "TARGET IS NOT_CONTROLLER");
        }

        Controller.Action[] memory l2Actions = buildL2Actions();

        IBridge.Message memory message;
        message.destChainId = 167_000;
        message.gasLimit = gasLimit;
        message.destOwner = L2.PERMISSIONLESS_EXECUTOR;
        message.data = abi.encodeCall(
            DelegateController.onMessageInvocation, (abi.encode(executionId, l2Actions))
        );

        allActions[l1Actions.length] = Controller.Action({
            target: L1.BRIDGE,
            value: 0,
            data: abi.encodeCall(IBridge.sendMessage, (message))
        });

        for (uint256 i; i < allActions.length; ++i) {
            console2.log("ACTION #", 1 + i, "==========================");
            console2.log("target:", allActions[i].target);
            if (allActions[i].value > 0) {
                console2.log("value:", allActions[i].value);
            }

            console2.log("data:");
            console2.logBytes(allActions[i].data);
            console2.log("");
        }
    }
}
