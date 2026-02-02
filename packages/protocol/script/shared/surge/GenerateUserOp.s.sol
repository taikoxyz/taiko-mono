// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { UserOpsSubmitter } from "../../../contracts/shared/userops/UserOpsSubmitter.sol";
import { L1Sender } from "../../layer1/surge/examples/L1Sender.sol";
import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

/// @title GenerateUserOp
/// @notice Script to generate a signed user operation for calling L1Sender.calculate.
/// @dev This script generates a UserOp that calls L1Sender.calculate to perform a calculation
///      operation (ADD, SUB, MUL, DIV) with two operands.
///      The output includes the submitter address, target (L1Sender), value, data, and signature.
///      Data and signature are output as JSON arrays for compatibility with Rust's Vec<u8>.
contract GenerateUserOp is Script {
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");
    address internal submitter = vm.envAddress("SUBMITTER_ADDRESS");
    address internal l1Sender = vm.envAddress("L1_SENDER_ADDRESS");
    uint256 internal a = vm.envUint("A");
    uint256 internal b = vm.envUint("B");
    uint8 internal op = uint8(vm.envUint("OP"));

    function run()
        external
        view
        returns (
            address submitter_,
            address target_,
            uint256 value_,
            bytes memory data_,
            bytes memory signature_
        )
    {
        require(submitter != address(0), "SUBMITTER_ADDRESS not set");
        require(l1Sender != address(0), "L1_SENDER_ADDRESS not set");
        require(op <= 3, "OP_INVALID");

        console2.log("=====================================");
        console2.log("Generating User Operation");
        console2.log("=====================================");
        console2.log("Submitter:", submitter);
        console2.log("L1Sender:", l1Sender);
        console2.log("A:", a);
        console2.log("B:", b);
        console2.log("OP:", op);
        console2.log("");

        // Convert op to L1Sender.OP enum
        L1Sender.OP opEnum = L1Sender.OP(op);

        // Encode the calculate call
        bytes memory callData = abi.encodeCall(L1Sender.calculate, (a, b, opEnum));

        // Create UserOp (value is 0 since calculate doesn't accept ETH)
        UserOpsSubmitter.UserOp[] memory ops = new UserOpsSubmitter.UserOp[](1);
        ops[0] = UserOpsSubmitter.UserOp({ target: l1Sender, value: 0, data: callData });

        // Generate digest
        bytes32 digest = keccak256(abi.encode(ops));

        // Sign the digest
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Set return values
        submitter_ = submitter;
        target_ = l1Sender;
        value_ = 0;
        data_ = callData;
        signature_ = signature;

        console2.log("Generated User Operation:");
        console2.log("  Submitter:", submitter_);
        console2.log("  Target:", target_);
        console2.log("  Value:", value_);
        console2.log("  Digest:", vm.toString(digest));
        console2.log("");

        // Output data and signature as hex strings (prefixed for easy parsing)
        console2.log("DATA_HEX:", vm.toString(data_));
        console2.log("SIGNATURE_HEX:", vm.toString(signature_));

        console2.log("");
        console2.log("=====================================");
        console2.log("User Operation Generated");
        console2.log("=====================================");
    }
}
