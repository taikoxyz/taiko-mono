// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import {LibRLPWriter} from "../../thirdparty/LibRLPWriter.sol";

/**
 * @title TestLibRLPWriter
 */
contract TestLibRLPWriter {
    function writeBytes(
        bytes memory _in
    ) public pure returns (bytes memory _out) {
        return LibRLPWriter.writeBytes(_in);
    }

    function writeList(
        bytes[] memory _in
    ) public pure returns (bytes memory _out) {
        return LibRLPWriter.writeList(_in);
    }

    function writeString(
        string memory _in
    ) public pure returns (bytes memory _out) {
        return LibRLPWriter.writeString(_in);
    }

    function writeAddress(address _in) public pure returns (bytes memory _out) {
        return LibRLPWriter.writeAddress(_in);
    }

    function writeUint(uint256 _in) public pure returns (bytes memory _out) {
        return LibRLPWriter.writeUint(_in);
    }

    function writeBool(bool _in) public pure returns (bytes memory _out) {
        return LibRLPWriter.writeBool(_in);
    }
}
