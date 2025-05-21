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
    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

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

    function tryrunL1Actions(uint64 executionId, uint32 l2GasLimit) internal broadcast {
        TaikoDAOController(payable(L1.DAO_CONTROLLER)).dryrun{ value: 0 }(
            buildAllActions(executionId, l2GasLimit)
        );
    }

    function tryrunL2Actions() internal broadcast {
        DelegateController(payable(L2.DELEGATE_CONTROLLER)).dryrun{ value: 0 }(buildL2Actions());
    }

    function buildAllActions(
        uint64 executionId,
        uint32 l2GasLimit
    )
        internal
        pure
        returns (Controller.Action[] memory allActions_)
    {
        Controller.Action[] memory l1Actions = buildL1Actions();
        allActions_ = new Controller.Action[](l1Actions.length + 1);

        for (uint256 i; i < l1Actions.length; ++i) {
            allActions_[i] = l1Actions[i];
        }

        Controller.Action[] memory l2Actions = buildL2Actions();

        IBridge.Message memory message;
        message.destChainId = 167_000;
        message.gasLimit = l2GasLimit;
        message.destOwner = L2.PERMISSIONLESS_EXECUTOR;
        message.data = abi.encodeCall(
            DelegateController.onMessageInvocation, (abi.encode(executionId, l2Actions))
        );

        allActions_[l1Actions.length] = Controller.Action({
            target: L1.BRIDGE,
            value: 0,
            data: abi.encodeCall(IBridge.sendMessage, (message))
        });
    }

    function logProposalAction(uint64 executionId, uint32 l2GasLimit) internal pure {
        Controller.Action[] memory allActions = buildAllActions(executionId, l2GasLimit);

        console2.log("Proposal Action--------------------------------");
        console2.log("Target:", L1.DAO_CONTROLLER);
        console2.logBytes(abi.encodeCall(TaikoDAOController.execute, (allActions)));
    }
}
