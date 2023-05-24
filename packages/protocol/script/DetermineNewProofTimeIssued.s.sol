// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {LibLn} from "../test/LibLn.sol";

uint16 constant DESIRED_PROOF_TIME_TARGET = 160;
uint16 constant ADJUSTMENT_QUOTIENT = 32000;

contract DetermineProofTimeIssued is Script {
    function run() public view {
        uint16 proofTimeTarget = DESIRED_PROOF_TIME_TARGET; // Approx. value which close to what is in the simulation
        uint64 feeBase = 1e8; // 1 TKO
        uint64 initProofTimeIssued =
            LibLn.calcInitProofTimeIssued(feeBase, proofTimeTarget, ADJUSTMENT_QUOTIENT);

        console2.log("The proof time target is:", proofTimeTarget);
        console2.log("The associated proof time issued is:", initProofTimeIssued);
    }
}
