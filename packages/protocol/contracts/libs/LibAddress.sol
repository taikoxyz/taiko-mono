// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressUpgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/utils/AddressUpgradeable.sol";
import { ECDSAUpgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/utils/cryptography/ECDSAUpgradeable.sol";
import { IERC165Upgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/utils/introspection/IERC165Upgradeable.sol";
import { IERC1271Upgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/interfaces/IERC1271Upgradeable.sol";

/// @title LibAddress
/// @dev Provides utilities for address-related operations.
library LibAddress {
    bytes4 private constant EIP1271_MAGICVALUE = 0x1626ba7e;

    /// @dev Sends Ether to the specified address. It is recommended to avoid
    /// using `.transfer()` due to potential reentrancy issues.
    /// Reference:
    /// https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now
    /// @param to The recipient address.
    /// @param amount The amount of Ether to send in wei.
    function sendEther(address to, uint256 amount) internal {
        // Check for zero-value or zero-address transactions
        if (amount == 0 || to == address(0)) return;

        // Attempt to send Ether to the recipient address
        (bool success,) = payable(to).call{ value: amount }("");

        // Ensure the transfer was successful
        require(success, "ETH transfer failed");
    }

    function supportsInterface(
        address addr,
        bytes4 interfaceId
    )
        internal
        view
        returns (bool result)
    {
        if (AddressUpgradeable.isContract(addr)) {
            try IERC165Upgradeable(addr).supportsInterface(interfaceId)
            returns (bool _result) {
                result = _result;
            } catch { }
        }
    }

    function isValidSignature(
        address addr,
        bytes32 hash,
        bytes memory sig
    )
        internal
        view
        returns (bool valid)
    {
        if (
            AddressUpgradeable.isContract(addr)
                && IERC1271Upgradeable(addr).isValidSignature(hash, sig)
                    == EIP1271_MAGICVALUE
        ) {
            valid = true;
        } else if (ECDSAUpgradeable.recover(hash, sig) == addr) {
            valid = true;
        }
    }
}
