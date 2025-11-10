// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/shared/governance/TaikoTokenTransferHelper.sol";

// To print the proposal action data: `P=0005 pnpm proposal`
// To dryrun the proposal on L1: `P=0005 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0005 pnpm proposal:dryrun:l2`
contract Proposal0005 is BuildProposal {
    // L1 contracts
    address public constant TAIKO_TOKEN = 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
    address public constant TAIKO_CONTROLLER = 0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a; // controller.taiko.eth
    address public constant TAIKO_TREASURY = 0x363e846B91AF677Fb82f709b6c35BD1AaFc6B3Da; // treasury.taiko.eth

    // TaikoTokenTransferHelper must be deployed before executing this proposal
    // TODO: Update this address after deployment
    address public constant TRANSFER_HELPER = address(0); // REPLACE WITH ACTUAL DEPLOYED ADDRESS

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](2);

        // Action 1: Approve the transfer helper to spend Controller's TAIKO tokens
        // Using type(uint256).max for unlimited approval (only needed once)
        actions[0] = Controller.Action({
            target: TAIKO_TOKEN,
            value: 0,
            data: abi.encodeCall(IERC20.approve, (TRANSFER_HELPER, type(uint256).max))
        });

        // Action 2: Call the helper to transfer all TAIKO tokens from Controller to Treasury
        // The amount is determined at execution time by reading balanceOf(TAIKO_CONTROLLER)
        actions[1] = Controller.Action({
            target: TRANSFER_HELPER,
            value: 0,
            data: abi.encodeCall(
                TaikoTokenTransferHelper.transferAllFrom,
                (TAIKO_TOKEN, TAIKO_CONTROLLER, TAIKO_TREASURY)
            )
        });
    }
}
