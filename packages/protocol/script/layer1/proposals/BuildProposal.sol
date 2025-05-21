// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Script.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/layer2/mainnet/DelegateController.sol";
import "src/layer1/governance/TaikoDAOController.sol";
import "src/shared/bridge/IBridge.sol";
import { LibMainnetL1Addresses as L1 } from "src/layer1/mainnet/libs/LibMainnetL1Addresses.sol";
import { LibMainnetL2Addresses as L2 } from "src/layer2/mainnet/LibMainnetL2Addresses.sol";

abstract contract BuildProposal is Script {
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

    function buildProposal(
        uint64 executionId,
        uint32 l2GasLimit
    )
        internal
        pure
        returns (
            bytes memory protocolCallData_,
            bytes memory l1DryrunCallData_,
            bytes memory l2DryrunCallData_
        )
    {
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

        console2.log("Proposal actions list: ================================================");
        protocolCallData_ = abi.encodeCall(TaikoDAOController.execute, (allActions));
        console2.log("Num of L1 actions:", l1Actions.length);
        for (uint256 i; i < l1Actions.length; ++i) {
            console2.log("L1 action #", i);
            console2.log("- Target:", l1Actions[i].target);
            if (l1Actions[i].value > 0) {
                console2.log("- Value:", l1Actions[i].value);
            }
            console2.logBytes(l1Actions[i].data);
        }
        console2.log("");
        console2.log("Num of L2 actions:", l2Actions.length);
        for (uint256 i; i < l2Actions.length; ++i) {
            console2.log("L2 action #", i);
            console2.log("- Target:", l2Actions[i].target);
            if (l2Actions[i].value > 0) {
                console2.log("- Value:", l2Actions[i].value);
            }
            console2.logBytes(l2Actions[i].data);
        }

        console2.log("===============================================");
        console2.log("ACTION LIST");
        console2.log("- L2 gas limit:", l2GasLimit);
        console2.log("- Target:", L1.DAO_CONTROLLER);
        console2.log("- Data:");
        console2.logBytes(protocolCallData_);

        console2.log("===============================================");
        console2.log("L1 DRYRUN");
        l1DryrunCallData_ = abi.encodeCall(Controller.dryrun, (allActions));
        console2.log("- Target:", L1.DAO_CONTROLLER);
        console2.log("- Data:");
        console2.logBytes(l1DryrunCallData_);

        console2.log("===============================================");
        console2.log("L2 DRYRUN");
        l2DryrunCallData_ = abi.encodeCall(Controller.dryrun, (l2Actions));
        console2.log("- Target:", L2.DELEGATE_CONTROLLER);
        console2.log("- Data:");
        console2.logBytes(l2DryrunCallData_);
    }
}
