// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Script.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
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

    function proposalConfig()
        internal
        pure
        virtual
        returns (uint64 l2ExecutionId, uint32 l2GasLimit)
    { }

    function buildL1Actions() internal pure virtual returns (Controller.Action[] memory);
    function buildL2Actions() internal pure virtual returns (Controller.Action[] memory);

    function logProposalAction(string memory proposalId) internal {
        Controller.Action[] memory allActions = _buildAllActions();

        string memory fileName =
            string.concat("./script/layer1/proposals/Proposal", proposalId, ".action.md");

        string memory actionsStr;

        for (uint256 i; i < allActions.length; ++i) {
            actionsStr = string(
                abi.encodePacked(
                    actionsStr,
                    "- target: `",
                    vm.toString(allActions[i].target),
                    "`\n",
                    "  value: `",
                    vm.toString(allActions[i].value),
                    "`\n",
                    "  data: `",
                    vm.toString(allActions[i].data),
                    "`\n\n"
                )
            );
        }

        string memory actionSection =
            string(abi.encodePacked("# Proposal Action Details\n- DAO Controller: `", 
            vm.toString(L1.DAO_CONTROLLER), "`\n\n",
            
            "## Actions:\n", actionsStr));

        string memory l1DryrunSection = string(
            abi.encodePacked(
                "\n\n## L1 Dryrun\n",
                "- target (daocontroller.taiko.eth):   `",
                vm.toString(L1.DAO_CONTROLLER),
                "`\n",
                "- calldata: `",
                vm.toString(abi.encodeCall(Controller.dryrun, (allActions)))
            )
        );

        string memory l2DryrunSection = string(
            abi.encodePacked(
                "\n\n## L2 Dryrun\n",
                "- target (delegate controller):   `",
                vm.toString(L2.DELEGATE_CONTROLLER),
                "`\n",
                "- calldata: `",
                vm.toString(abi.encodeCall(Controller.dryrun, (buildL2Actions())))
            )
        );

        string memory fileContent =
            string(abi.encodePacked(actionSection, l1DryrunSection, l2DryrunSection));

        vm.writeFile(fileName, fileContent);

        console2.log(fileContent);
        console2.log("Proposal action details written to", fileName);
    }

    function dryrunL1Actions() internal broadcast {
        Controller(payable(L1.DAO_CONTROLLER)).dryrun(_buildAllActions());
    }

    function dryrunL2Actions() internal broadcast {
        Controller(payable(L2.DELEGATE_CONTROLLER)).dryrun(buildL2Actions());
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
        (uint64 l2ExecutionId, uint32 l2GasLimit) = proposalConfig();

        Controller.Action[] memory l1Actions = buildL1Actions();
        allActions_ = new Controller.Action[](l1Actions.length + 1);

        for (uint256 i; i < l1Actions.length; ++i) {
            allActions_[i] = l1Actions[i];
            require(l1Actions[i].target != address(0), "l1 action's target is zero address");
        }

        Controller.Action[] memory l2Actions = buildL2Actions();
        for (uint256 i; i < l2Actions.length; ++i) {
            require(l2Actions[i].target != address(0), "l2 action's target is zero address");
        }

        IBridge.Message memory message;
        message.destChainId = 167_000;
        message.gasLimit = l2GasLimit;
        message.destOwner = L2.PERMISSIONLESS_EXECUTOR;
        message.data = abi.encodeCall(
            IMessageInvocable.onMessageInvocation, (abi.encode(l2ExecutionId, l2Actions))
        );

        allActions_[l1Actions.length] = Controller.Action({
            target: L1.BRIDGE,
            value: 0,
            data: abi.encodeCall(IBridge.sendMessage, (message))
        });
    }
}
