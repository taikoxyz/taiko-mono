// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

contract TaikoL1Test is Test {
    modifier givenANewlyDeployedTaikoL1ContractWith10SlotsForBlocks() {
        _;
    }

    modifier givenProposalIsInTheLastStage() {
        _;
    }

    function test_WhenPropose11BlocksWithValidParameters()
        external
        givenANewlyDeployedTaikoL1ContractWith10SlotsForBlocks
        givenProposalIsInTheLastStage
    {
        // It should allow up to 10 blocks to be proposed and the 11-th will revert
        vm.skip(true);
    }
}
