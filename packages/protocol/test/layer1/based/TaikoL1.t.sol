// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

contract TaikoL1Test is Test {
    modifier givenProposalExists() {
        _;
    }

    modifier givenProposalIsInTheLastStage() {
        _;
    }

    function test_WhenProposalCanAdvance() external givenProposalExists givenProposalIsInTheLastStage {
        // It Should return true
    }
}
