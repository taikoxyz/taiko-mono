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

import { FiatTokenV1 } from "../v1/FiatTokenV1.sol";
import { Rescuable } from "./Rescuable.sol";

/**
 * @title FiatTokenV1_1
 * @dev ERC20 Token backed by fiat reserves
 */
contract FiatTokenV1_1 is FiatTokenV1, Rescuable {

}
