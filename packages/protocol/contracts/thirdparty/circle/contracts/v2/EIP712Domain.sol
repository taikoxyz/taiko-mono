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

// solhint-disable func-name-mixedcase

/**
 * @title EIP712 Domain
 */
contract EIP712Domain {
    // was originally DOMAIN_SEPARATOR
    // but that has been moved to a method so we can override it in V2_2+
    bytes32 internal _DEPRECATED_CACHED_DOMAIN_SEPARATOR;

    /**
     * @notice Get the EIP712 Domain Separator.
     * @return The bytes32 EIP712 domain separator.
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparator();
    }

    /**
     * @dev Internal method to get the EIP712 Domain Separator.
     * @return The bytes32 EIP712 domain separator.
     */
    function _domainSeparator() internal virtual view returns (bytes32) {
        return _DEPRECATED_CACHED_DOMAIN_SEPARATOR;
    }
}
