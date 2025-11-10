// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposalV2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// To print the proposal action data: `P=0005 pnpm proposal`
// To dryrun the proposal on L1: `P=0005 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0005 pnpm proposal:dryrun:l2`
contract Proposal0005 is BuildProposalV2 {
    // L1 contracts
    address public constant TAIKO_TOKEN = 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
    address public constant TAIKO_CONTROLLER = 0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a; // controller.taiko.eth
    address public constant TAIKO_TREASURY = 0x363e846B91AF677Fb82f709b6c35BD1AaFc6B3Da; // treasury.taiko.eth

    function buildL1ActionsView()
        internal
        view
        override
        returns (Controller.Action[] memory actions)
    {
        actions = new Controller.Action[](1);

        // Get the current balance of TAIKO tokens held by the Controller
        uint256 controllerBalance = IERC20(TAIKO_TOKEN).balanceOf(TAIKO_CONTROLLER);

        // Transfer all TAIKO tokens from Controller to treasury.taiko.eth
        actions[0] = Controller.Action({
            target: TAIKO_TOKEN,
            value: 0,
            data: abi.encodeCall(IERC20.transfer, (TAIKO_TREASURY, controllerBalance))
        });
    }

    function buildL2ActionsView()
        internal
        view
        override
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory actions)
    {
        l2ExecutionId = 0;
        l2GasLimit = 0;
        actions = new Controller.Action[](0);
    }
}
