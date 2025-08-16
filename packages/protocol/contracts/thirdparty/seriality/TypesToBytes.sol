// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

/**
 * @title TypesToBytes
 * @dev The TypesToBytes contract converts the standard solidity types to the byte array
 * @author pouladzade@gmail.com
 */
contract TypesToBytes {
    constructor() { }

    function addressToBytes(uint256 _offst, address _input, bytes memory _output) internal pure {
        assembly {
            mstore(add(_output, _offst), _input)
        }
    }

    function bytes32ToBytes(uint256 _offst, bytes32 _input, bytes memory _output) internal pure {
        assembly {
            mstore(add(_output, _offst), _input)
            mstore(add(add(_output, _offst), 32), add(_input, 32))
        }
    }

    function boolToBytes(uint256 _offst, bool _input, bytes memory _output) internal pure {
        uint8 x = _input == false ? 0 : 1;
        assembly {
            mstore(add(_output, _offst), x)
        }
    }

    function stringToBytes(
        uint256 _offst,
        bytes memory _input,
        bytes memory _output
    )
        internal
        pure
    {
        uint256 stack_size = _input.length / 32;
        if (_input.length % 32 > 0) stack_size++;

        assembly {
            stack_size := add(stack_size, 1) //adding because of 32 first bytes memory as the length
            for { let index := 0 } lt(index, stack_size) { index := add(index, 1) } {
                mstore(add(_output, _offst), mload(add(_input, mul(index, 32))))
                _offst := sub(_offst, 32)
            }
        }
    }

    function intToBytes(uint256 _offst, int256 _input, bytes memory _output) internal pure {
        assembly {
            mstore(add(_output, _offst), _input)
        }
    }

    function uintToBytes(uint256 _offst, uint256 _input, bytes memory _output) internal pure {
        assembly {
            mstore(add(_output, _offst), _input)
        }
    }
}
