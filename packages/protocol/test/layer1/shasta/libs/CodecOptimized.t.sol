// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ICodec } from "src/layer1/shasta/iface/ICodec.sol";
import { CodecOptimized } from "src/layer1/shasta/impl/CodecOptimized.sol";
import { AbstractCodecTest } from "./AbstractCodec.t.sol";

/// @title CodecOptimizedTest
/// @notice Test suite for CodecOptimized (LibHashOptimized) implementation
contract CodecOptimizedTest is AbstractCodecTest {
    function _getCodec() internal override returns (ICodec) {
        return ICodec(address(new CodecOptimized()));
    }

    function _getCodecName() internal pure override returns (string memory) {
        return "CodecOptimized";
    }
}
