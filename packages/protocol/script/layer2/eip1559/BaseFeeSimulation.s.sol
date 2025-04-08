// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseFeeContract.sol";
import "forge-std/src/console2.sol";
import "forge-std/src/Script.sol";

// To run this simulation:
// forge script script/layer2/eip1559/BaseFeeSimulation.s.sol:BaseFeeSimulation
contract BaseFeeSimulation is Script {
    BaseFeeContract baseFeeContract;
    uint256 public constant MAX_BLOCKS_TO_PROCESS = 1000;
    uint256 public constant initialBaseFee = 1 gwei;
    
    // We must use a dynamic gas issuance per second otherwise the base fee will either reach the
    // uppper limit or the lower limit.
    uint32 gasIssuancePerSecond = 1_900_000; // from MainnetInbox.sol

    function setUp() public {
        // Initialize the BaseFeeContract with some default values
        uint8 adjustmentQuotient = 8; // from MainnetInbox.sol

        baseFeeContract =
            new BaseFeeContract(initialBaseFee, adjustmentQuotient, gasIssuancePerSecond);
    }

    function run() public {
        // Use paths relative to the script's location
        string memory inputFile = "script/layer2/eip1559/taiko_block_data.csv";

        // Copy the CSV file to the script directory if it doesn't exist there
        if (!vm.exists(inputFile)) {
            console2.log("Input file does not exist:", inputFile);
            return;
        }

        // Read the CSV file
        string memory fileContent = vm.readFile(inputFile);
        string[] memory allLines = vm.split(fileContent, "\n");
        uint256 lineCount =
            allLines.length > MAX_BLOCKS_TO_PROCESS ? MAX_BLOCKS_TO_PROCESS : allLines.length;
        string[] memory lines = new string[](lineCount);
        for (uint256 i = 0; i < lineCount; i++) {
            lines[i] = allLines[i];
        }

        // Free memory for allLines and fileContent
        fileContent = "";
        allLines = new string[](0);

        string[] memory outputLines = new string[](lines.length);

        // Process each line
        // Print the header row
        console2.log("index,timestamp,gas_used,base_fee_per_gas,percentage");
        for (uint256 i = 1; i < lines.length; i++) {
            string[] memory columns = vm.split(lines[i], ",");

            // block_number,timestamp,gas_limit,gas_used,base_fee_per_gas
            uint64 parentGasUsed = uint64(vm.parseUint(columns[3]));
            uint256 blockTime = vm.parseUint(columns[1]);

            // Call calculateAndUpdateBaseFee
            uint256 baseFee = baseFeeContract.calculateAndUpdateBaseFee(parentGasUsed, blockTime);

            // Calculate the percentage change
            uint256 percentageChange = (baseFee * 10_000) / initialBaseFee;
            uint256 integerPart = percentageChange / 100;
            uint256 fractionalPart = percentageChange % 100;

            // Format the percentage change as a string
            string memory percentageChangeStr = string(
                abi.encodePacked(
                    vm.toString(integerPart),
                    ".",
                    fractionalPart < 10 ? "0" : "",
                    vm.toString(fractionalPart),
                    "%%"
                )
            );

            // Prepare the output line
            outputLines[i] = string(
                abi.encodePacked(
                    vm.toString(i),
                    ",",
                    columns[1],
                    ",", // timestamp
                    columns[3],
                    ",", // gas_used
                    vm.toString(baseFee),
                    ",", // Calculated Base Fee
                    percentageChangeStr
                )
            );

            console2.log(outputLines[i]);
        }
    }
}
