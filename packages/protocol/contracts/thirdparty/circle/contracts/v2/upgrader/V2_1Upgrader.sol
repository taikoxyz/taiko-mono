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
import { FiatTokenV2_1 } from "../FiatTokenV2_1.sol";
import { FiatTokenProxy } from "../../v1/FiatTokenProxy.sol";
import { V2UpgraderHelper } from "./helpers/V2UpgraderHelper.sol";
import { AbstractV2Upgrader } from "./AbstractV2Upgrader.sol";

/**
 * @title V2.1 Upgrader
 * @notice Performs FiatToken v2.1 upgrade, and runs a basic sanity test in a single
 * atomic transaction, rolling back if any issues are found. By performing the
 * upgrade atomically, it ensures that there is no disruption of service if the
 * upgrade is not successful for some unforeseen circumstances.
 * @dev Read doc/v2.1_upgrade.md
 */
contract V2_1Upgrader is AbstractV2Upgrader {
    using SafeMath for uint256;

    address private _lostAndFound;

    /**
     * @notice Constructor
     * @param proxy             FiatTokenProxy contract
     * @param implementation    FiatTokenV2_1 implementation contract
     * @param newProxyAdmin     Grantee of proxy admin role after upgrade
     * @param lostAndFound      The address to which the locked funds are sent
     */
    constructor(
        FiatTokenProxy proxy,
        FiatTokenV2_1 implementation,
        address newProxyAdmin,
        address lostAndFound
    ) public AbstractV2Upgrader(proxy, address(implementation), newProxyAdmin) {
        _lostAndFound = lostAndFound;
        _helper = new V2UpgraderHelper(address(proxy));
    }

    /**
     * @notice The address to which the locked funds will be sent as part of the
     * initialization process
     * @return Address
     */
    function lostAndFound() external view returns (address) {
        return _lostAndFound;
    }

    /**
     * @notice Upgrade, transfer proxy admin role to a given address, run a
     * sanity test, and tear down the upgrader contract, in a single atomic
     * transaction. It rolls back if there is an error.
     */
    function upgrade() external onlyOwner {
        // The helper needs to be used to read contract state because
        // AdminUpgradeabilityProxy does not allow the proxy admin to make
        // proxy calls.
        V2UpgraderHelper v2_1Helper = V2UpgraderHelper(address(_helper));

        // Check that this contract sufficient funds to run the tests
        uint256 contractBal = v2_1Helper.balanceOf(address(this));
        require(contractBal >= 2e5, "V2_1Upgrader: 0.2 FiatToken needed");

        uint256 callerBal = v2_1Helper.balanceOf(msg.sender);

        // Keep original contract metadata
        string memory name = v2_1Helper.name();
        string memory symbol = v2_1Helper.symbol();
        uint8 decimals = v2_1Helper.decimals();
        string memory currency = v2_1Helper.currency();
        address masterMinter = v2_1Helper.masterMinter();
        address owner = v2_1Helper.fiatTokenOwner();
        address pauser = v2_1Helper.pauser();
        address blacklister = v2_1Helper.blacklister();

        // Change implementation contract address
        _proxy.upgradeTo(_implementation);

        // Transfer proxy admin role
        _proxy.changeAdmin(_newProxyAdmin);

        // Initialize V2 contract
        FiatTokenV2_1 v2_1 = FiatTokenV2_1(address(_proxy));
        v2_1.initializeV2_1(_lostAndFound);

        // Sanity test
        // Check metadata
        require(
            keccak256(bytes(name)) == keccak256(bytes(v2_1.name())) &&
                keccak256(bytes(symbol)) == keccak256(bytes(v2_1.symbol())) &&
                decimals == v2_1.decimals() &&
                keccak256(bytes(currency)) ==
                keccak256(bytes(v2_1.currency())) &&
                masterMinter == v2_1.masterMinter() &&
                owner == v2_1.owner() &&
                pauser == v2_1.pauser() &&
                blacklister == v2_1.blacklister(),
            "V2_1Upgrader: metadata test failed"
        );

        // Test balanceOf
        require(
            v2_1.balanceOf(address(this)) == contractBal,
            "V2_1Upgrader: balanceOf test failed"
        );

        // Test transfer
        require(
            v2_1.transfer(msg.sender, 1e5) &&
                v2_1.balanceOf(msg.sender) == callerBal.add(1e5) &&
                v2_1.balanceOf(address(this)) == contractBal.sub(1e5),
            "V2_1Upgrader: transfer test failed"
        );

        // Test approve/transferFrom
        require(
            v2_1.approve(address(v2_1Helper), 1e5) &&
                v2_1.allowance(address(this), address(v2_1Helper)) == 1e5 &&
                v2_1Helper.transferFrom(address(this), msg.sender, 1e5) &&
                v2_1.allowance(address(this), msg.sender) == 0 &&
                v2_1.balanceOf(msg.sender) == callerBal.add(2e5) &&
                v2_1.balanceOf(address(this)) == contractBal.sub(2e5),
            "V2_1Upgrader: approve/transferFrom test failed"
        );

        // Transfer any remaining FiatToken to the caller
        withdrawFiatToken();

        // Tear down
        tearDown();
    }
}
