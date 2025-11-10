// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BuildProposal.sol";

/// @title BuildProposalV2
/// @notice V2 of BuildProposal that supports view functions to enable reading blockchain state
/// @dev This version changes buildL1Actions and buildL2Actions from pure to view,
///      allowing proposals to query on-chain data like token balances.
///      This contract cannot directly override the base functions due to Solidity's state
///      mutability restrictions (cannot change pure to view in override). Instead, it provides
///      new virtual functions that child contracts should implement, and adapts the base
///      contract's behavior through wrapper functions.
abstract contract BuildProposalV2 is BuildProposal {
    /// @notice Override to provide view version of buildL1Actions
    /// @dev Child contracts should implement buildL1ActionsView instead of buildL1Actions
    function buildL1Actions() internal pure override returns (Controller.Action[] memory) {
        // This pure function should never be called in V2 proposals
        // Instead, child contracts implement buildL1ActionsView
        revert("BuildProposalV2: Use buildL1ActionsView");
    }

    /// @notice Override to provide view version of buildL2Actions
    /// @dev Child contracts should implement buildL2ActionsView instead of buildL2Actions
    function buildL2Actions()
        internal
        pure
        override
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory actions)
    {
        // This pure function should never be called in V2 proposals
        // Instead, child contracts implement buildL2ActionsView
        revert("BuildProposalV2: Use buildL2ActionsView");
    }

    /// @notice View version of buildL1Actions that can read blockchain state
    /// @dev Child contracts should override this instead of buildL1Actions
    function buildL1ActionsView() internal view virtual returns (Controller.Action[] memory);

    /// @notice View version of buildL2Actions that can read blockchain state
    /// @dev Child contracts should override this instead of buildL2Actions
    function buildL2ActionsView()
        internal
        view
        virtual
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory actions);

    /// @notice Override the base contract's _buildAllActions to use view versions
    /// @dev This is a workaround since we can't directly change the base private function
    function logProposalAction(string memory proposalId) internal override {
        Controller.Action[] memory allActions = _buildAllActionsView();

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

    /// @notice Override dryrunL1Actions to use view version
    function dryrunL1Actions() internal override broadcast {
        Controller(payable(L1.DAO_CONTROLLER)).dryrun(abi.encode(_buildAllActionsView()));
    }

    /// @notice Override dryrunL2Actions to use view version
    function dryrunL2Actions() internal override broadcast {
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

        (success, result) = L2.DELEGATE_CONTROLLER.staticcall(
            abi.encodeWithSignature("daoController()")
        );
        require(
            success && abi.decode(result, (address)) == L1.DAO_CONTROLLER,
            DelegateControllerIncorrectDaoController()
        );

        (,, Controller.Action[] memory l2Actions) = buildL2ActionsView();

        Controller(payable(L2.DELEGATE_CONTROLLER)).dryrun(abi.encode(l2Actions));
    }

    /// @notice View version of _buildAllActions
    /// @dev Replaces the base contract's private pure _buildAllActions with a view version
    function _buildAllActionsView() private view returns (Controller.Action[] memory allActions_) {
        Controller.Action[] memory l1Actions = buildL1ActionsView();
        uint256 len = l1Actions.length;

        (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory l2Actions) =
            buildL2ActionsView();
        if (l2Actions.length > 0) {
            len += 1;
        }

        allActions_ = new Controller.Action[](len);

        for (uint256 i; i < l1Actions.length; ++i) {
            allActions_[i] = l1Actions[i];
            require(l1Actions[i].target != address(0), TargetIsZeroAddress());
            require(
                l1Actions[i].target != L1.DAO_CONTROLLER, TargetIsDAOController()
            );
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
                target: L1.BRIDGE,
                value: 0,
                data: abi.encodeCall(IBridge.sendMessage, (message))
            });
        }
    }
}
