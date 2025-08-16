// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

/**
 * @title BytesToTypes
 * @dev The BytesToTypes contract converts the memory byte arrays to the standard solidity types
 * @author pouladzade@gmail.com
 */
contract BytesToTypes {
    function bytesToAddress(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (address _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToBool(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (bool _output)
    {
        uint8 x;
        assembly {
            x := mload(add(_input, _offst))
        }
        x == 0 ? _output = false : _output = true;
    }

    function getStringSize(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint256 size)
    {
        assembly {
            size := mload(add(_input, _offst))
            let chunk_count := add(div(size, 32), 1) // chunk_count = size/32 + 1

            if gt(mod(size, 32), 0) {
                // if size%32 > 0
                chunk_count := add(chunk_count, 1)
            }

            size := mul(chunk_count, 32) // first 32 bytes reseves for size in strings
        }
    }

    function bytesToString(
        uint256 _offst,
        bytes memory _input,
        bytes memory _output
    )
        internal
        pure
    {
        uint256 size = 32;
        assembly {
            let chunk_count

            size := mload(add(_input, _offst))
            chunk_count := add(div(size, 32), 1) // chunk_count = size/32 + 1

            if gt(mod(size, 32), 0) { chunk_count := add(chunk_count, 1) } // chunk_count++

            for { let index := 0 } lt(index, chunk_count) { index := add(index, 1) } {
                mstore(add(_output, mul(index, 32)), mload(add(_input, _offst)))
                _offst := sub(_offst, 32) // _offst -= 32
            }
        }
    }

    function bytesToBytes32(uint256 _offst, bytes memory _input, bytes32 _output) internal pure {
        assembly {
            mstore(_output, add(_input, _offst))
            mstore(add(_output, 32), add(add(_input, _offst), 32))
        }
    }

    function bytesToInt8(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int8 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt16(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int16 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt24(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int24 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt32(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int32 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt40(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int40 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt48(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int48 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt56(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int56 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt64(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int64 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt72(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int72 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt80(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int80 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt88(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int88 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt96(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int96 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt104(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int104 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt112(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int112 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt120(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int120 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt128(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int128 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt136(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int136 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt144(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int144 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt152(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int152 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt160(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int160 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt168(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int168 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt176(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int176 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt184(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int184 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt192(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int192 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt200(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int200 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt208(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int208 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt216(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int216 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt224(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int224 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt232(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int232 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt240(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int240 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt248(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int248 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToInt256(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (int256 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint8(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint8 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint16(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint16 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint24(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint24 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint32(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint32 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint40(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint40 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint48(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint48 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint56(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint56 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint64(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint64 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint72(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint72 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint80(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint80 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint88(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint88 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint96(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint96 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint104(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint104 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint112(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint112 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint120(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint120 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint128(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint128 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint136(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint136 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint144(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint144 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint152(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint152 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint160(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint160 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint168(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint168 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint176(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint176 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint184(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint184 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint192(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint192 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint200(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint200 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint208(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint208 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint216(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint216 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint224(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint224 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint232(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint232 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint240(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint240 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint248(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint248 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function bytesToUint256(
        uint256 _offst,
        bytes memory _input
    )
        internal
        pure
        returns (uint256 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }
}
