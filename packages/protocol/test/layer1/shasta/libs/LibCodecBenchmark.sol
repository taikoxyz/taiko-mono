// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "forge-std/src/console2.sol";

/// @title LibCodecBenchmark
/// @notice Shared benchmark utility for codec performance testing
/// @custom:security-contact security@taiko.xyz
library LibCodecBenchmark {
    struct BenchmarkResult {
        uint256 baselineEncode;
        uint256 optimizedEncode;
        uint256 baselineDecode;
        uint256 optimizedDecode;
        uint256 baselineSize;
        uint256 optimizedSize;
    }

    struct BenchmarkConfig {
        string reportTitle;
        string summary;
        string[] testLabels;
        string keyFeatures;
        string optimizations;
        string outputFile;
    }

    /// @notice Generate a comprehensive benchmark report
    /// @param results Array of benchmark results
    /// @param config Configuration for the report
    function generateReport(
        BenchmarkResult[] memory results,
        BenchmarkConfig memory config
    )
        internal
    {
        // Only output the Gas Usage Comparison table for version control
        string memory report = "# Gas Usage Comparison\n\n";
        report = string.concat(report, "| Test Case | Baseline Encode | Optimized Encode | Encode Savings | Baseline Decode | Optimized Decode | Decode Savings | Data Size (bytes) | Size Reduction |\n");
        report = string.concat(report, "|-----------|----------------|------------------|----------------|-----------------|------------------|----------------|-------------------|----------------|\n");
        
        for (uint256 i = 0; i < results.length; i++) {
            BenchmarkResult memory r = results[i];
            
            // Calculate savings
            int256 encodeSavings = int256(r.baselineEncode) - int256(r.optimizedEncode);
            int256 decodeSavings = int256(r.baselineDecode) - int256(r.optimizedDecode);
            int256 sizeSavings = int256(r.baselineSize) - int256(r.optimizedSize);
            
            string memory encodeSavingsStr = formatSavings(encodeSavings, r.baselineEncode);
            string memory decodeSavingsStr = formatSavings(decodeSavings, r.baselineDecode);
            
            report = string.concat(report, "| ", config.testLabels[i], " | ");
            report = string.concat(report, Vm(address(uint160(uint256(keccak256("hevm cheat code"))))).toString(r.baselineEncode), " | ");
            report = string.concat(report, Vm(address(uint160(uint256(keccak256("hevm cheat code"))))).toString(r.optimizedEncode), " | ");
            report = string.concat(report, encodeSavingsStr, " | ");
            report = string.concat(report, Vm(address(uint160(uint256(keccak256("hevm cheat code"))))).toString(r.baselineDecode), " | ");
            report = string.concat(report, Vm(address(uint160(uint256(keccak256("hevm cheat code"))))).toString(r.optimizedDecode), " | ");
            report = string.concat(report, decodeSavingsStr, " | ");
            report = string.concat(report, Vm(address(uint160(uint256(keccak256("hevm cheat code"))))).toString(r.optimizedSize), " | ");
            report = string.concat(report, Vm(address(uint160(uint256(keccak256("hevm cheat code"))))).toString(uint256(sizeSavings)), " bytes |\n");
        }
        
        // Write to file
        Vm(address(uint160(uint256(keccak256("hevm cheat code"))))).writeFile(config.outputFile, report);
        console2.log(string.concat("Benchmark report written to ", config.outputFile));
    }

    /// @notice Measure gas usage for encode/decode operations
    /// @param encodeFunc Function to encode data
    /// @param decodeFunc Function to decode data
    /// @return result The benchmark result
    function measure(
        function() returns (bytes memory) encodeFunc,
        function(bytes memory) decodeFunc
    )
        internal
        returns (BenchmarkResult memory result)
    {
        // Measure encode
        uint256 gas = gasleft();
        bytes memory encoded = encodeFunc();
        result.optimizedEncode = gas - gasleft();
        result.optimizedSize = encoded.length;
        
        // Measure decode
        gas = gasleft();
        decodeFunc(encoded);
        result.optimizedDecode = gas - gasleft();
    }

    /// @notice Format savings as a readable string
    function formatSavings(int256 savings, uint256 baseline) private pure returns (string memory) {
        if (savings >= 0) {
            uint256 percentage = baseline > 0 ? uint256(savings) * 100 / baseline : 0;
            return string.concat(
                "-", 
                Vm(address(uint160(uint256(keccak256("hevm cheat code"))))).toString(uint256(savings)), 
                " (", 
                Vm(address(uint160(uint256(keccak256("hevm cheat code"))))).toString(percentage), 
                "%)"
            );
        } else {
            uint256 overhead = uint256(-savings);
            uint256 percentage = baseline > 0 ? overhead * 100 / baseline : 0;
            return string.concat(
                "+", 
                Vm(address(uint160(uint256(keccak256("hevm cheat code"))))).toString(overhead), 
                " (+", 
                Vm(address(uint160(uint256(keccak256("hevm cheat code"))))).toString(percentage), 
                "%)"
            );
        }
    }
}