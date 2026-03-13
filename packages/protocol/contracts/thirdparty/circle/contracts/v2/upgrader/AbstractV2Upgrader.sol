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

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "../../v1/Ownable.sol";
import { FiatTokenProxy } from "../../v1/FiatTokenProxy.sol";
import { AbstractUpgraderHelper } from "./helpers/AbstractUpgraderHelper.sol";

/**
 * @dev An abstract contract to encapsulate any common logic
 * for any V2+ Upgrader contracts.
 */
abstract contract AbstractV2Upgrader is Ownable {
    using SafeMath for uint256;

    FiatTokenProxy internal _proxy;
    address internal _implementation;
    address internal _newProxyAdmin;
    AbstractUpgraderHelper internal _helper;

    /**
     * @notice Constructor
     * @param proxy             FiatTokenProxy contract
     * @param implementation    Address of the implementation contract
     * @param newProxyAdmin     Grantee of proxy admin role after upgrade
     */
    constructor(
        FiatTokenProxy proxy,
        address implementation,
        address newProxyAdmin
    ) public Ownable() {
        _proxy = proxy;
        _implementation = implementation;
        _newProxyAdmin = newProxyAdmin;
    }

    /**
     * @notice The address of the FiatTokenProxy contract
     * @return Contract address
     */
    function proxy() external view returns (address) {
        return address(_proxy);
    }

    /**
     * @notice The address of the FiatTokenV2 implementation contract
     * @return Contract address
     */
    function implementation() external view returns (address) {
        return _implementation;
    }

    /**
     * @notice The address of the V2UpgraderHelper contract
     * @return Contract address
     */
    function helper() external view returns (address) {
        return address(_helper);
    }

    /**
     * @notice The address to which the proxy admin role will be transferred
     * after the upgrade is completed
     * @return Address
     */
    function newProxyAdmin() external view returns (address) {
        return _newProxyAdmin;
    }

    /**
     * @notice Withdraw any FiatToken in the contract
     */
    function withdrawFiatToken() public onlyOwner {
        IERC20 fiatToken = IERC20(address(_proxy));
        uint256 balance = fiatToken.balanceOf(address(this));
        if (balance > 0) {
            require(
                fiatToken.transfer(msg.sender, balance),
                "Failed to withdraw FiatToken"
            );
        }
    }

    /**
     * @notice Transfer proxy admin role to newProxyAdmin, and self-destruct
     */
    function abortUpgrade() external onlyOwner {
        // Transfer proxy admin role
        _proxy.changeAdmin(_newProxyAdmin);

        // Tear down
        tearDown();
    }

    /**
     * @dev Tears down the helper contract followed by this contract.
     */
    function tearDown() internal {
        _helper.tearDown();
        selfdestruct(msg.sender);
    }
}
