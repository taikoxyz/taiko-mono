// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseFeeContract.sol";
import "forge-std/src/console2.sol";
import "forge-std/src/Script.sol";


contract BaseFeeSimulation is Script {
    BaseFeeContract baseFeeContract;

    function setUp() public {
        // Initialize the BaseFeeContract with some default values
        uint initialBaseFee = 1 gwei;
        uint8 adjustmentQuotient = 8; // from MainnetInbox.sol
        uint32 gasIssuancePerSecond = 5_000_000; // from MainnetInbox.sol
        baseFeeContract = new BaseFeeContract(initialBaseFee, adjustmentQuotient, gasIssuancePerSecond);
    }

    function run() public {
        // Use paths relative to the script's location
        string memory inputFile = "script/layer2/eip1559/taiko_block_data.csv";
        string memory outputFile = "script/layer2/eip1559/taiko_block_data_basefee.csv";

        // Copy the CSV file to the script directory if it doesn't exist there
        if (!vm.exists(inputFile)) {
            console2.log("Input file does not exist:", inputFile);
            return;
        }

        // Read the CSV file
        string memory fileContent = vm.readFile(inputFile);
        string[] memory allLines = vm.split(fileContent, "\n");
        uint256 lineCount = allLines.length > 100 ? 100 : allLines.length;
        string[] memory lines = new string[](lineCount);
        for (uint256 i = 0; i < lineCount; i++) {
            lines[i] = allLines[i];
        }

        // Free memory for allLines and fileContent
       fileContent = "";
       allLines = new string[](0);

        string[] memory outputLines = new string[](lines.length);

        // Process each line
        for (uint256 i = 1; i < 10 && i < lines.length; i++) {
            string[] memory columns = vm.split(lines[i], ",");
            uint64 parentGasUsed = uint64(vm.parseUint(columns[1]));
            uint256 blockTime = vm.parseUint(columns[2]);

            // Call calculateAndUpdateBaseFee
            uint256 baseFee = baseFeeContract.calculateAndUpdateBaseFee(parentGasUsed, blockTime);

            // Prepare the output line
            outputLines[i] = string(abi.encodePacked(
                columns[0], ",", // Block ID
                columns[2], ",", // Block Time
                columns[1], ",", // Parent Gas Used
                vm.toString(baseFee) // Calculated Base Fee
            ));
        }

        // Write the output CSV file
        string memory outputContent = "";
        for (uint256 i = 0; i < outputLines.length; i++) {
            if (i > 0) {
                outputContent = string(abi.encodePacked(outputContent, "\n"));
            }
            outputContent = string(abi.encodePacked(outputContent, outputLines[i]));
        }
        vm.writeFile(outputFile, outputContent);
    }
}
