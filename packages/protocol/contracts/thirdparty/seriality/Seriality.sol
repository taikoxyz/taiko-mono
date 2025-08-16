// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

/**
 * @title Seriality
 * @dev The Seriality contract is the main interface for serializing data using the TypeToBytes, BytesToType and SizeOf
 * @author pouladzade@gmail.com
 */
 
import "./BytesToTypes.sol";
import "./TypesToBytes.sol";
import "./SizeOf.sol";

contract Seriality is BytesToTypes, TypesToBytes, SizeOf {

    constructor() {}
}
