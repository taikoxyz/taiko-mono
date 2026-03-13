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

import { FiatTokenV1 } from "../../../v1/FiatTokenV1.sol";
import { AbstractUpgraderHelper } from "./AbstractUpgraderHelper.sol";

/**
 * @title V2 Upgrader Helper
 * @dev Enables V2Upgrader to read some contract state before it renounces the
 * proxy admin role. (Proxy admins cannot call delegated methods). It is also
 * used to test approve/transferFrom.
 */
contract V2UpgraderHelper is AbstractUpgraderHelper {
    /**
     * @notice Constructor
     * @param fiatTokenProxy    Address of the FiatTokenProxy contract
     */
    constructor(address fiatTokenProxy)
        public
        AbstractUpgraderHelper(fiatTokenProxy)
    {}

    /**
     * @notice Call name()
     * @return name
     */
    function name() external view returns (string memory) {
        return FiatTokenV1(_proxy).name();
    }

    /**
     * @notice Call symbol()
     * @return symbol
     */
    function symbol() external view returns (string memory) {
        return FiatTokenV1(_proxy).symbol();
    }

    /**
     * @notice Call decimals()
     * @return decimals
     */
    function decimals() external view returns (uint8) {
        return FiatTokenV1(_proxy).decimals();
    }

    /**
     * @notice Call currency()
     * @return currency
     */
    function currency() external view returns (string memory) {
        return FiatTokenV1(_proxy).currency();
    }

    /**
     * @notice Call masterMinter()
     * @return masterMinter
     */
    function masterMinter() external view returns (address) {
        return FiatTokenV1(_proxy).masterMinter();
    }

    /**
     * @notice Call owner()
     * @dev Renamed to fiatTokenOwner due to the existence of Ownable.owner()
     * @return owner
     */
    function fiatTokenOwner() external view returns (address) {
        return FiatTokenV1(_proxy).owner();
    }

    /**
     * @notice Call pauser()
     * @return pauser
     */
    function pauser() external view returns (address) {
        return FiatTokenV1(_proxy).pauser();
    }

    /**
     * @notice Call blacklister()
     * @return blacklister
     */
    function blacklister() external view returns (address) {
        return FiatTokenV1(_proxy).blacklister();
    }

    /**
     * @notice Call balanceOf(address)
     * @param account   Account
     * @return balance
     */
    function balanceOf(address account) external view returns (uint256) {
        return FiatTokenV1(_proxy).balanceOf(account);
    }

    /**
     * @notice Call transferFrom(address,address,uint256)
     * @param from     Sender
     * @param to       Recipient
     * @param value    Amount
     * @return result
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {
        return FiatTokenV1(_proxy).transferFrom(from, to, value);
    }
}
