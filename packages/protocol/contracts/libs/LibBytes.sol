// SPDX-License-Identifier: Apache-2.0

/*
 * Copyright 2020, Offchain Labs, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

pragma solidity 0.8.24;

library LibBytes {
    // Taken from:
    // https://github.com/0xPolygonHermez/zkevm-contracts/blob/main/contracts/PolygonZkEVMBridge.sol#L835-L860
    /// @notice Function to convert returned data to string
    /// returns 'NOT_VALID_ENCODING' as fallback value.
    function toString(bytes memory _data) internal pure returns (string memory) {
        if (_data.length >= 64) {
            return abi.decode(_data, (string));
        } else if (_data.length == 32) {
            // Since the strings on bytes32 are encoded left-right, check the first zero in the data
            uint256 nonZeroBytes;
            while (nonZeroBytes < 32 && _data[nonZeroBytes] != 0) {
                ++nonZeroBytes;
            }

            // If the first one is 0, we do not handle the encoding
            if (nonZeroBytes == 0) return "";

            // Create a byte array with nonZeroBytes length
            bytes memory bytesArray = new bytes(nonZeroBytes);
            for (uint256 i; i < nonZeroBytes; ++i) {
                bytesArray[i] = _data[i];
            }
            return string(bytesArray);
        } else {
            return "";
        }
    }
}
