/**
 * Copyright 2023 Circle Internet Group, Inc. All rights reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

pragma solidity 0.6.12;

contract FiatTokenUtil {
    // (address,address,uint256,uint256,uint256,bytes32) = 20*2 + 32*4 = 168
    uint256 private constant _TRANSFER_PARAM_SIZE = 168;
    // (uint8,bytes32,bytes32) = 1 + 32*2 = 65
    uint256 private constant _SIGNATURE_SIZE = 65;
    // keccak256("transferWithAuthorization(address,address,uint256,uint256,uint256,bytes32,uint8,bytes32,bytes32)")[0:4]
    bytes4 private constant _TRANSFER_WITH_AUTHORIZATION_SELECTOR = 0xe3ee160e;

    address private _fiatToken;

    event TransferFailed(address indexed authorizer, bytes32 indexed nonce);

    /**
     * @notice Constructor
     * @dev If FiatTokenProxy is used to hold state and delegate calls, the
     * proxy's address should be provided, not the implementation address
     * @param fiatToken Address of the FiatToken contract
     */
    constructor(address fiatToken) public {
        _fiatToken = fiatToken;
    }

    /**
     * @notice Execute multiple authorized ERC20 Transfers
     * @dev The length of params must be multiples of 168, each representing
     * encode-packed data containing from[20] + to[20] + value[32] +
     * validAfter[32] + validBefore[32] + nonce[32], and the length of
     * signatures must be multiples of 65, each representing encode-packed data
     * containing v[1] + r[32] + s[32].
     * @param params      Concatenated, encode-packed parameters
     * @param signatures  Concatenated, encode-packed signatures
     * @param atomic      If true, revert if any of the transfers fail
     * @return            True if every transfer was successful
     */
    function transferWithMultipleAuthorizations(
        bytes calldata params,
        bytes calldata signatures,
        bool atomic
    ) external returns (bool) {
        uint256 num = params.length / _TRANSFER_PARAM_SIZE;
        require(num > 0, "FiatTokenUtil: no transfer provided");
        require(
            num * _TRANSFER_PARAM_SIZE == params.length,
            "FiatTokenUtil: length of params is invalid"
        );
        require(
            signatures.length / _SIGNATURE_SIZE == num &&
                num * _SIGNATURE_SIZE == signatures.length,
            "FiatTokenUtil: length of signatures is invalid"
        );

        uint256 numSuccessful = 0;

        for (uint256 i = 0; i < num; i++) {
            uint256 paramsOffset = i * _TRANSFER_PARAM_SIZE;
            uint256 sigOffset = i * _SIGNATURE_SIZE;

            // extract from and to
            bytes memory fromTo = _unpackAddresses(
                abi.encodePacked(params[paramsOffset:paramsOffset + 40])
            );
            // extract value, validAfter, validBefore, and nonce
            bytes memory other4 = abi.encodePacked(
                params[paramsOffset + 40:paramsOffset + _TRANSFER_PARAM_SIZE]
            );
            // extract v
            uint8 v = uint8(signatures[sigOffset]);
            // extract r and s
            bytes memory rs = abi.encodePacked(
                signatures[sigOffset + 1:sigOffset + _SIGNATURE_SIZE]
            );

            // Call transferWithAuthorization with the extracted parameters
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, bytes memory returnData) = _fiatToken.call(
                abi.encodePacked(
                    _TRANSFER_WITH_AUTHORIZATION_SELECTOR,
                    fromTo,
                    other4,
                    abi.encode(v),
                    rs
                )
            );

            // Revert if atomic is true, and the call was not successful
            if (atomic && !success) {
                _revertWithReasonFromReturnData(returnData);
            }

            // Increment the number of successful transfers
            if (success) {
                numSuccessful++;
            } else {
                // extract from
                (address from, ) = abi.decode(fromTo, (address, address));
                // extract nonce
                (, , , bytes32 nonce) = abi.decode(
                    other4,
                    (uint256, uint256, uint256, bytes32)
                );
                emit TransferFailed(from, nonce);
            }
        }

        // Return true if all transfers were successful
        return numSuccessful == num;
    }

    /**
     * @dev Converts encodePacked pair of addresses (20bytes + 20 bytes) to
     * regular ABI-encoded pair of addresses (32bytes + 32bytes)
     * @param packed Packed data (40 bytes)
     * @return Unpacked data (64 bytes)
     */
    function _unpackAddresses(bytes memory packed)
        private
        pure
        returns (bytes memory)
    {
        address addr1;
        address addr2;
        assembly {
            addr1 := mload(add(packed, 20))
            addr2 := mload(add(packed, 40))
        }
        return abi.encode(addr1, addr2);
    }

    /**
     * @dev Revert with reason string extracted from the return data
     * @param returnData    Return data from a call
     */
    function _revertWithReasonFromReturnData(bytes memory returnData)
        private
        pure
    {
        // Return data will be at least 100 bytes if it contains the reason
        // string: Error(string) selector[4] + string offset[32] + string
        // length[32] + string data[32] = 100
        if (returnData.length < 100) {
            revert("FiatTokenUtil: call failed");
        }

        // If the reason string exists, extract it, and bubble it up
        string memory reason;
        assembly {
            // Skip over the bytes length[32] + Error(string) selector[4] +
            // string offset[32] = 68 (0x44)
            reason := add(returnData, 0x44)
        }

        revert(reason);
    }
}
