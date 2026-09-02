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
    address public constant TAIKO_DAO_CONTROLLER = 0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a; // controller.taiko.eth
    address public constant TAIKO_TOKEN = 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800; // token.taiko.eth
    address public constant TAIKO_FOUNDATION_TREASURY = 0x363e846B91AF677Fb82f709b6c35BD1AaFc6B3Da; // treasury.taiko.eth

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
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory actions)
    {
        l2ExecutionId = 0;
        l2GasLimit = 0;
        actions = new Controller.Action[](0);
    }

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

    function buildERC20TransferAction(
        address _token,
        address _to,
        uint256 _amount
    )
        internal
        pure
        returns (Controller.Action memory)
    {
        return Controller.Action({
            target: _token, value: 0, data: abi.encodeCall(IERC20.transfer, (_to, _amount))
        });
    }

    /// @dev Internal rather than private so a proposal's tests can pin the committed
    /// `.action.md` calldata against what this actually builds. That file is the payload the DAO
    /// executes, and nothing else checks that it was regenerated after the proposal changed.
    /// @return allActions_ The L1 actions, plus the bridge message carrying the L2 batch when
    /// there is one.
    function _buildAllActions() internal pure returns (Controller.Action[] memory allActions_) {
        Controller.Action[] memory l1Actions = buildL1Actions();
        (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory l2Actions) =
            buildL2Actions();
        return _buildAllActions(l1Actions, l2ExecutionId, l2GasLimit, l2Actions);
    }

    /// @dev The parameterised form of `_buildAllActions`, so a proposal's fork rehearsal can
    /// execute exactly the L1 batch the DAO will against implementations it deployed itself.
    /// @param _l1Actions The L1 actions.
    /// @param _l2ExecutionId The DelegateController execution id; zero means unordered.
    /// @param _l2GasLimit The gas limit carried by the L1 to L2 message.
    /// @param _l2Actions The L2 actions; empty when the proposal has no L2 leg.
    /// @return allActions_ The L1 actions, plus the bridge message carrying the L2 batch when
    /// there is one.
    function _buildAllActions(
        Controller.Action[] memory _l1Actions,
        uint64 _l2ExecutionId,
        uint32 _l2GasLimit,
        Controller.Action[] memory _l2Actions
    )
        internal
        pure
        returns (Controller.Action[] memory allActions_)
    {
        uint256 len = _l1Actions.length;
        if (_l2Actions.length > 0) {
            len += 1;
        }

        allActions_ = new Controller.Action[](len);

        for (uint256 i; i < _l1Actions.length; ++i) {
            allActions_[i] = _l1Actions[i];
            require(_l1Actions[i].target != address(0), TargetIsZeroAddress());
            require(_l1Actions[i].target != L1.DAO_CONTROLLER, TargetIsDAOController());
        }

        if (_l2Actions.length > 0) {
            for (uint256 i; i < _l2Actions.length; ++i) {
                require(_l2Actions[i].target != address(0), TargetIsZeroAddress());
            }

            allActions_[_l1Actions.length] = Controller.Action({
                target: L1.BRIDGE,
                value: 0,
                data: abi.encodeCall(
                    IBridge.sendMessage, (_buildL2Message(_l2ExecutionId, _l2GasLimit, _l2Actions))
                )
            });
        }
    }

    /// @dev The L1 to L2 message that carries an L2 batch to the DelegateController. `id`, `from`
    /// and `srcChainId` are left zero: the L1 bridge assigns them when the DAO controller sends it.
    /// @param _l2ExecutionId The DelegateController execution id; zero means unordered.
    /// @param _l2GasLimit The gas limit carried by the message.
    /// @param _l2Actions The L2 actions the DelegateController executes.
    /// @return message_ The message, as `sendMessage` receives it.
    function _buildL2Message(
        uint64 _l2ExecutionId,
        uint32 _l2GasLimit,
        Controller.Action[] memory _l2Actions
    )
        internal
        pure
        returns (IBridge.Message memory message_)
    {
        message_.srcOwner = L1.DAO_CONTROLLER;
        message_.destOwner = L2.PERMISSIONLESS_EXECUTOR;
        message_.destChainId = 167_000;
        message_.gasLimit = _l2GasLimit;
        message_.to = L2.DELEGATE_CONTROLLER;
        message_.data = abi.encodeCall(
            IMessageInvocable.onMessageInvocation,
            (abi.encodePacked(_l2ExecutionId, abi.encode(_l2Actions)))
        );
    }
}
