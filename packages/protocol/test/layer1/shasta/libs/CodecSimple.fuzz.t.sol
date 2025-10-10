// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ICodec } from "src/layer1/iface/ICodec.sol";
import { CodecSimple } from "src/layer1/impl/CodecSimple.sol";
import { AbstractCodecFuzzTest } from "./AbstractCodec.fuzz.t.sol";

/// @title CodecSimpleFuzzTest
/// @notice Fuzz test suite for CodecSimple (LibHashSimple) implementation
contract CodecSimpleFuzzTest is AbstractCodecFuzzTest {
    function _getCodec() internal override returns (ICodec) {
        return ICodec(address(new CodecSimple()));
    }
}
