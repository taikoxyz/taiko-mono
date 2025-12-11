// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0006 pnpm proposal`
// To dryrun the proposal on L1: `P=0006 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0006 pnpm proposal:dryrun:l2`
contract Proposal0006 is BuildProposal {
    // SignerList contract that manages the Security Council members
    address public constant SIGNER_LIST = 0x0F95E6968EC1B28c794CF1aD99609431de5179c2;

    // Gattaca address to add as a new security council member
    address public constant GATTACA = 0x6268d189E011Aa53A2f09A1FE159445BeB3d878E;

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](1);

        // Add Gattaca as a new signer to the Security Council SignerList
        address[] memory newSigners = new address[](1);
        newSigners[0] = GATTACA;

        actions[0] = Controller.Action({
            target: SIGNER_LIST,
            value: 0,
            data: abi.encodeWithSignature("addSigners(address[])", newSigners)
        });
    }
}
