//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { V3Struct } from "../lib/QuoteV3Auth/V3Struct.sol";

interface IAttestation {
    function verifyAttestation(bytes calldata data) external returns (bool);
    function verifyParsedQuote(V3Struct.ParsedV3QuoteStruct calldata v3quote)external returns (bool success, uint8 exitStep);
}
