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
    uint256 public constant INITIAL_BASE_FEE = 1 gwei;
    uint8 public constant ADJUSTMENT_QUOTIENT = 8; // from MainnetInbox.sol

    function setUp() public {
        // Initialize the BaseFeeContract with some default values

        baseFeeContract = new BaseFeeContract(INITIAL_BASE_FEE, ADJUSTMENT_QUOTIENT);
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

        string[] memory firstBlockColumns = vm.split(lines[1], ",");
        uint256 parentTimestamp = vm.parseUint(firstBlockColumns[1]);

        for (uint256 i = 1; i < lines.length; i++) {
            string[] memory columns = vm.split(lines[i], ",");

            // block_number,timestamp,gas_limit,gas_used,base_fee_per_gas
            uint64 parentGasUsed = uint64(vm.parseUint(columns[3]));
            uint256 blockTimetamp = vm.parseUint(columns[1]);
            uint256 blockTime = blockTimetamp - parentTimestamp;

            // Call calculateAndUpdateBaseFee
            (uint256 baseFee, uint32 gasIssuancePerSecond) =
                baseFeeContract.calculateAndUpdateBaseFee(parentGasUsed, blockTime);

            // Calculate the percentage change
            uint256 percentageChange = (baseFee * 10_000) / INITIAL_BASE_FEE;
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
                    ":\t timestamp= ",
                    columns[1],
                    ",\t block_time= ",
                    vm.toString(blockTime),
                    "s,\t gas_used= ",
                    columns[3],
                    ",\t gipc= ",
                    vm.toString(gasIssuancePerSecond),
                    ",\t basefee= ",
                    vm.toString(baseFee),
                    ",\t pctg= ",
                    percentageChangeStr
                )
            );

            console2.log(outputLines[i]);
            parentTimestamp = blockTimetamp;
        }
    }
}
