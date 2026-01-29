// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";
import { UserOpsSubmitter } from "../../../contracts/shared/userops/UserOpsSubmitter.sol";
import { IBridge } from "../../../contracts/shared/bridge/IBridge.sol";

/// @title GenerateUserOp
/// @notice Script to generate a signed user operation for sending ETH via Bridge.sendMessage.
/// @dev This script generates a UserOp that calls Bridge.sendMessage to send ETH to a target
/// address.
///      The output includes the submitter address, target (Bridge), value, data, and signature.
///      Data and signature are output as JSON arrays for compatibility with Rust's Vec<u8>.
contract GenerateUserOp is Script {
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");
    address internal submitter = vm.envAddress("SUBMITTER_ADDRESS");
    address internal bridge = vm.envAddress("BRIDGE_ADDRESS");
    address internal ethRecipient = vm.envAddress("ETH_RECIPIENT");
    uint256 internal ethAmount = vm.envUint("ETH_AMOUNT");
    uint64 internal destChainId = uint64(vm.envUint("DEST_CHAIN_ID"));

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
        require(bridge != address(0), "BRIDGE_ADDRESS not set");
        require(ethRecipient != address(0), "ETH_RECIPIENT not set");
        require(ethAmount > 0, "ETH_AMOUNT must be greater than 0");
        require(destChainId > 0, "DEST_CHAIN_ID must be greater than 0");

        console2.log("=====================================");
        console2.log("Generating User Operation");
        console2.log("=====================================");
        console2.log("Submitter:", submitter);
        console2.log("Bridge:", bridge);
        console2.log("ETH Recipient:", ethRecipient);
        console2.log("ETH Amount (wei):", ethAmount);
        console2.log("Destination Chain ID:", destChainId);
        console2.log("");

        // Create Bridge.Message struct
        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: address(0),
            srcChainId: 0,
            destChainId: destChainId,
            srcOwner: submitter,
            destOwner: ethRecipient,
            to: ethRecipient,
            value: ethAmount,
            fee: 0,
            gasLimit: 0,
            data: ""
        });

        // Encode the sendMessage call
        bytes memory bridgeCallData = abi.encodeCall(IBridge.sendMessage, (message));

        // Create UserOp
        UserOpsSubmitter.UserOp[] memory ops = new UserOpsSubmitter.UserOp[](1);
        ops[0] = UserOpsSubmitter.UserOp({ target: bridge, value: ethAmount, data: bridgeCallData });

        // Generate digest
        bytes32 digest = keccak256(abi.encode(ops));

        // Sign the digest
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Set return values
        submitter_ = submitter;
        target_ = bridge;
        value_ = ethAmount;
        data_ = bridgeCallData;
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
