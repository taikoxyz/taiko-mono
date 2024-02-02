// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";
import "./common/AttestationBase.t.sol";

contract AutomataDcapV3AttestationTest is Test, AttestationBase {
    using BytesUtils for bytes;
    using stdJson for string;

    function setUp() public {
        // Call the AttestationBase init setup
        super.intialSetup();
    }

    function testAttestation() public {
        vm.prank(user);
        bool verified = attestation.verifyAttestation(sampleQuote);
        assertTrue(verified);
    }

    function testParsedQuoteAttestation() public {
        vm.prank(user);
        string memory v3QuoteJsonStr = vm.readFile(string.concat(vm.projectRoot(), v3QuotePath));
        console.log("[LOG] v3QuoteJsonStr: %s", v3QuoteJsonStr);
        bytes memory v3QuotePacked = vm.parseJson(v3QuoteJsonStr);
        console.logBytes(v3QuotePacked);

        (, V3Struct.ParsedV3QuoteStruct memory v3quote) = parseV3QuoteJson(v3QuotePacked);
        console.log("v3quote.header.userData = %s", address(v3quote.header.userData));
        console.logBytes(v3quote.localEnclaveReport.reportData);
        (bool verified,) = attestation.verifyParsedQuote(v3quote);

        assertTrue(verified);
    }

    function testParsedQuoteAbiEncoding() public {
        vm.prank(user);
        string memory v3QuoteJsonStr = vm.readFile(string.concat(vm.projectRoot(), v3QuotePath));
        bytes memory v3QuotePacked = vm.parseJson(v3QuoteJsonStr);

        (, V3Struct.ParsedV3QuoteStruct memory v3quote) = parseV3QuoteJson(v3QuotePacked);
        bytes32 hash = keccak256(abi.encode(v3quote));
        //console.logBytes32(hash);
        assertEq(hash, 0xa27c4167ab139dffb020230b2ec856080d0e1af437b3a2c2beea1c9af17469bc);
    }
}
