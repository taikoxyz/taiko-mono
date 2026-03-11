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

import { Ownable } from "../../../v1/Ownable.sol";

/**
 * @dev An abstract contract to encapsulate any common logic for any V2+ Upgrader Helper contracts.
 * The helper enables the upgrader to read some contract state before it renounces the
 * proxy admin role (Proxy admins cannot call delegated methods).
 */
abstract contract AbstractUpgraderHelper is Ownable {
    address internal _proxy;

    /**
     * @notice Constructor
     * @param fiatTokenProxy    Address of the FiatTokenProxy contract
     */
    constructor(address fiatTokenProxy) public Ownable() {
        _proxy = fiatTokenProxy;
    }

    /**
     * @notice The address of the FiatTokenProxy contract
     * @return Contract address
     */
    function proxy() external view returns (address) {
        return _proxy;
    }

    /**
     * @notice Tear down the contract (self-destruct)
     */
    function tearDown() external onlyOwner {
        selfdestruct(msg.sender);
    }
}
