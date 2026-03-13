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

/**
 * @title EIP712
 * @notice A library that provides EIP712 helper functions
 */
library EIP712 {
    /**
     * @notice Make EIP712 domain separator
     * @param name      Contract name
     * @param version   Contract version
     * @param chainId   Blockchain ID
     * @return Domain separator
     */
    function makeDomainSeparator(
        string memory name,
        string memory version,
        uint256 chainId
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
                    0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                    keccak256(bytes(name)),
                    keccak256(bytes(version)),
                    chainId,
                    address(this)
                )
            );
    }

    /**
     * @notice Make EIP712 domain separator
     * @param name      Contract name
     * @param version   Contract version
     * @return Domain separator
     */
    function makeDomainSeparator(string memory name, string memory version)
        internal
        view
        returns (bytes32)
    {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return makeDomainSeparator(name, version, chainId);
    }
}
