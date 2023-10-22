// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressUpgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/utils/AddressUpgradeable.sol";
import { OwnableUpgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

import { ReentrancyGuardUpgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

import { ERC20Upgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { LibAddress } from "../libs/LibAddress.sol";
import { Proxied } from "../common/Proxied.sol";

/// @title GrantPool
contract GrantPool is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for ERC20Upgradeable;

    address public token;

    function init(address _token) external initializer {
        OwnableUpgradeable.__Ownable_init_unchained();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init_unchained();
        token = _token;
    }
}
