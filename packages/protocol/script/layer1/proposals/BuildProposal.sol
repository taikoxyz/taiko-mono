// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Script.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/layer1/mainnet/TaikoDAOController.sol";
import "src/shared/bridge/IBridge.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/libs/LibL1Addrs.sol";
import { LibL2Addrs as L2 } from "src/layer2/mainnet/libs/LibL2Addrs.sol";

abstract contract BuildProposal is Script {
    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external {
        console2.log("Proposal0002");
        string memory mode = vm.envString("MODE");
        if (keccak256(abi.encodePacked(mode)) == keccak256(abi.encodePacked("print"))) {
            logProposalAction();
        } else if (keccak256(abi.encodePacked(mode)) == keccak256(abi.encodePacked("l1dryrun"))) {
            dryrunL1Actions();
        } else if (keccak256(abi.encodePacked(mode)) == keccak256(abi.encodePacked("l2dryrun"))) {
            dryrunL2Actions();
        } else {
            console2.log("Error: Invalid mode. Must be one of: print, l1dryrun, l2dryrun");
        }
    }

    function proposalConfig()
        internal
        pure
        virtual
        returns (uint64 executionId, uint32 l2GasLimit)
    { }

    function buildL1Actions() internal pure virtual returns (Controller.Action[] memory);
    function buildL2Actions() internal pure virtual returns (Controller.Action[] memory);

    function logProposalAction() internal pure {
        Controller.Action[] memory allActions = _buildAllActions();

        console2.log("Proposal Action--------------------------------");
        console2.log("Target:", L1.DAO_CONTROLLER);
        console2.logBytes(abi.encodeCall(TaikoDAOController.execute, (allActions)));
    }

    function dryrunL1Actions() internal broadcast {
        console2.log("dryrunL1Actions");
        Controller(payable(L1.DAO_CONTROLLER)).dryrun{ value: 0 }(buildAllActions());
    }

    function dryrunL2Actions() internal broadcast {
        console2.log("dryrunL2Actions");
        Controller(payable(L2.DELEGATE_CONTROLLER)).dryrun{ value: 0 }(buildL2Actions());
    }

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

    function _buildAllActions() private pure returns (Controller.Action[] memory allActions_) {
        (uint64 executionId, uint32 l2GasLimit) = proposalConfig();

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
            IMessageInvocable.onMessageInvocation, (abi.encode(executionId, l2Actions))
        );

        allActions_[l1Actions.length] = Controller.Action({
            target: L1.BRIDGE,
            value: 0,
            data: abi.encodeCall(IBridge.sendMessage, (message))
        });
    }
}
