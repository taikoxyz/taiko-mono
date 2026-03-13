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

import { FiatTokenV2_1 } from "../../../v2/FiatTokenV2_1.sol";
import { V2UpgraderHelper } from "./V2UpgraderHelper.sol";

/**
 * @title V2.2 Upgrader Helper
 * @dev Enables V2_2Upgrader to read some contract state before it renounces the
 * proxy admin role. (Proxy admins cannot call delegated methods). It is also
 * used to test approve/transferFrom.
 */
contract V2_2UpgraderHelper is V2UpgraderHelper {
    /**
     * @notice Constructor
     * @param fiatTokenProxy    Address of the FiatTokenProxy contract
     */
    constructor(address fiatTokenProxy)
        public
        V2UpgraderHelper(fiatTokenProxy)
    {}

    /**
     * @notice Call version()
     * @return version
     */
    function version() external view returns (string memory) {
        return FiatTokenV2_1(_proxy).version();
    }

    /**
     * @notice Call DOMAIN_SEPARATOR()
     * @return domainSeparator
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return FiatTokenV2_1(_proxy).DOMAIN_SEPARATOR();
    }

    /**
     * @notice Call rescuer()
     * @return rescuer
     */
    function rescuer() external view returns (address) {
        return FiatTokenV2_1(_proxy).rescuer();
    }

    /**
     * @notice Call paused()
     * @return paused
     */
    function paused() external view returns (bool) {
        return FiatTokenV2_1(_proxy).paused();
    }

    /**
     * @notice Call totalSupply()
     * @return totalSupply
     */
    function totalSupply() external view returns (uint256) {
        return FiatTokenV2_1(_proxy).totalSupply();
    }
}
