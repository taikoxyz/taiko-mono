// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import {LibRLPReader} from "../../thirdparty/LibRLPReader.sol";

/**
 * @title TestLibRLPReader
 */
contract TestLibRLPReader {
    function readList(bytes memory _in) public pure returns (bytes[] memory) {
        LibRLPReader.RLPItem[] memory decoded = LibRLPReader.readList(_in);
        bytes[] memory out = new bytes[](decoded.length);
        for (uint256 i = 0; i < out.length; ++i) {
            out[i] = LibRLPReader.readRawBytes(decoded[i]);
        }
        return out;
    }

    function readString(bytes memory _in) public pure returns (string memory) {
        return LibRLPReader.readString(_in);
    }

    function readBytes(bytes memory _in) public pure returns (bytes memory) {
        return LibRLPReader.readBytes(_in);
    }

    function readBytes32(bytes memory _in) public pure returns (bytes32) {
        return LibRLPReader.readBytes32(_in);
    }

    function readUint256(bytes memory _in) public pure returns (uint256) {
        return LibRLPReader.readUint256(_in);
    }

    function readBool(bytes memory _in) public pure returns (bool) {
        return LibRLPReader.readBool(_in);
    }

    function readAddress(bytes memory _in) public pure returns (address) {
        return LibRLPReader.readAddress(_in);
    }
}
