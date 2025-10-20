// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractCodecTest } from "./AbstractCodec.t.sol";
import { ICodec } from "src/layer1/core/iface/ICodec.sol";
import { CodecSimple } from "src/layer1/core/impl/CodecSimple.sol";

/// @title CodecSimpleTest
/// @notice Test suite for CodecSimple (LibHashSimple) implementation
contract CodecSimpleTest is AbstractCodecTest {
    function _getCodec() internal override returns (ICodec) {
        return ICodec(address(new CodecSimple()));
    }

    function _getCodecName() internal pure override returns (string memory) {
        return "CodecSimple";
    }
}
