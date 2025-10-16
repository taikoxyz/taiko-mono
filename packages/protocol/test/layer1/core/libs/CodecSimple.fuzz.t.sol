// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractCodecFuzzTest } from "./AbstractCodec.fuzz.t.sol";
import { ICodec } from "src/layer1/core/iface/ICodec.sol";
import { CodecSimple } from "src/layer1/core/impl/CodecSimple.sol";

/// @title CodecSimpleFuzzTest
/// @notice Fuzz test suite for CodecSimple (LibHashSimple) implementation
contract CodecSimpleFuzzTest is AbstractCodecFuzzTest {
    function _getCodec() internal override returns (ICodec) {
        return ICodec(address(new CodecSimple()));
    }
}
