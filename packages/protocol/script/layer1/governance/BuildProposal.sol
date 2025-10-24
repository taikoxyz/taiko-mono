// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/src/Script.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { LibL2Addrs as L2 } from "src/layer2/mainnet/LibL2Addrs.sol";
import { IBridge, IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { Controller } from "src/shared/governance/Controller.sol";

abstract contract BuildProposal is Script {
    error TargetIsZeroAddress();
    error TargetIsDAOController();
    error DelegateControllerNotSelfOwned();
    error DelegateControllerIncorrectL2Bridge();
    error DelegateControllerIncorrectDaoController();

    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external {
        string memory mode = vm.envString("MODE");
        if (keccak256(abi.encodePacked(mode)) == keccak256(abi.encodePacked("print"))) {
            logProposalAction(vm.envString("P"));
        } else if (keccak256(abi.encodePacked(mode)) == keccak256(abi.encodePacked("l1dryrun"))) {
            dryrunL1Actions();
        } else if (keccak256(abi.encodePacked(mode)) == keccak256(abi.encodePacked("l2dryrun"))) {
            dryrunL2Actions();
        } else {
            console2.log("Error: Invalid mode. Must be one of: print, l1dryrun, l2dryrun");
        }
    }

    function buildL1Actions() internal pure virtual returns (Controller.Action[] memory);
    function buildL2Actions()
        internal
        pure
        virtual
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory);

    function logProposalAction(string memory proposalId) internal {
        Controller.Action[] memory allActions = _buildAllActions();

        string memory fileName =
            string.concat("./script/layer1/proposals/Proposal", proposalId, ".action.md");

        string memory fileContent = string(
            abi.encodePacked(
                "# Proposal",
                proposalId,
                "\n",
                "- To (DAO Controller): `",
                vm.toString(L1.DAO_CONTROLLER),
                "`\n- Function: `Execute" "`\n- Value: `0`\n- Calldata: `",
                vm.toString(abi.encode(allActions)),
                "`\n"
            )
        );

        vm.writeFile(fileName, fileContent);

        console2.log(fileContent);
        console2.log("Proposal action details written to", fileName);
    }

    function dryrunL1Actions() internal broadcast {
        Controller(payable(L1.DAO_CONTROLLER)).dryrun(abi.encode(_buildAllActions()));
    }

    function dryrunL2Actions() internal broadcast {
        require(
            Ownable(L2.DELEGATE_CONTROLLER).owner() == L2.DELEGATE_CONTROLLER,
            DelegateControllerNotSelfOwned()
        );

        (bool success, bytes memory result) =
            L2.DELEGATE_CONTROLLER.staticcall(abi.encodeWithSignature("l2Bridge()"));
        require(
            success && abi.decode(result, (address)) == L2.BRIDGE,
            DelegateControllerIncorrectL2Bridge()
        );

        (success, result) =
            L2.DELEGATE_CONTROLLER.staticcall(abi.encodeWithSignature("daoController()"));
        require(
            success && abi.decode(result, (address)) == L1.DAO_CONTROLLER,
            DelegateControllerIncorrectDaoController()
        );

        (,, Controller.Action[] memory l2Actions) = buildL2Actions();

        Controller(payable(L2.DELEGATE_CONTROLLER)).dryrun(abi.encode(l2Actions));
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
            target: _target, value: 0, data: abi.encodeCall(UUPSUpgradeable.upgradeTo, (_newImpl))
        });
    }

    function _buildAllActions() private pure returns (Controller.Action[] memory allActions_) {
        Controller.Action[] memory l1Actions = buildL1Actions();
        uint256 len = l1Actions.length;

        (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory l2Actions) =
            buildL2Actions();
        if (l2Actions.length > 0) {
            len += 1;
        }

        allActions_ = new Controller.Action[](len);

        for (uint256 i; i < l1Actions.length; ++i) {
            allActions_[i] = l1Actions[i];
            require(l1Actions[i].target != address(0), TargetIsZeroAddress());
            require(l1Actions[i].target != L1.DAO_CONTROLLER, TargetIsDAOController());
        }

        if (l2Actions.length > 0) {
            for (uint256 i; i < l2Actions.length; ++i) {
                require(l2Actions[i].target != address(0), TargetIsZeroAddress());
            }

            IBridge.Message memory message;
            message.srcOwner = L1.DAO_CONTROLLER;
            message.destOwner = L2.PERMISSIONLESS_EXECUTOR;
            message.destChainId = 167_000;
            message.gasLimit = l2GasLimit;
            message.to = L2.DELEGATE_CONTROLLER;
            message.data = abi.encodeCall(
                IMessageInvocable.onMessageInvocation,
                (abi.encodePacked(l2ExecutionId, abi.encode(l2Actions)))
            );

            allActions_[l1Actions.length] = Controller.Action({
                target: L1.BRIDGE, value: 0, data: abi.encodeCall(IBridge.sendMessage, (message))
            });
        }
    }
}
