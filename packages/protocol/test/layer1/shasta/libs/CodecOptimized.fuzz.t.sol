// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ICodec } from "src/layer1/iface/ICodec.sol";
import { CodecOptimized } from "src/layer1/impl/CodecOptimized.sol";
import { AbstractCodecFuzzTest } from "./AbstractCodec.fuzz.t.sol";

/// @title CodecOptimizedFuzzTest
/// @notice Fuzz test suite for CodecOptimized (LibHashOptimized) implementation
contract CodecOptimizedFuzzTest is AbstractCodecFuzzTest {
    function _getCodec() internal override returns (ICodec) {
        return ICodec(address(new CodecOptimized()));
    }
}
