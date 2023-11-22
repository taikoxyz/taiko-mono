// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "lib/openzeppelin-contracts/contracts/utils/Address.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/utils/cryptography/ECDSAUpgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/utils/introspection/IERC165Upgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/interfaces/IERC1271Upgradeable.sol";

/// @title LibAddress
/// @dev Provides utilities for address-related operations.
library LibAddress {
    bytes4 private constant EIP1271_MAGICVALUE = 0x1626ba7e;

    error ETH_TRANSFER_FAILED();
    error INVALID_PARAM();

    /// @dev Sends Ether to the specified address.
    /// @param to The recipient address.
    /// @param amount The amount of Ether to send in wei.
    /// @param gasLimit The max amount gas to pay for this transaction.
    function sendEther(address to, uint256 amount, uint256 gasLimit) internal {
        // Check for zero-value or zero-address transactions
        if (to == address(0)) revert ETH_TRANSFER_FAILED();

        // Attempt to send Ether to the recipient address
        // WARNING: call() functions do not have an upper gas cost limit, so
        // it's important to note that it may not reliably execute as expected
        // when invoked with untrusted addresses.
        (bool success,) = payable(to).call{ value: amount, gas: gasLimit }("");

        // Ensure the transfer was successful
        if (!success) revert ETH_TRANSFER_FAILED();
    }

    /// @dev Sends Ether to the specified address.
    /// @param to The recipient address.
    /// @param amount The amount of Ether to send in wei.
    function sendEther(address to, uint256 amount) internal {
        sendEther(to, amount, gasleft());
    }

    function deployTransparentUpgradeableProxyForOwnable(
        address impl,
        address owner,
        bytes memory data
    )
        internal
        returns (address proxy)
    {
        if (impl == address(0) || owner == address(0)) revert INVALID_PARAM();
        // The owner will become the `admin` of the proxy
        proxy = address(new TransparentUpgradeableProxy(impl, owner, data ));

        // Transfer ownership from this contract to the owner.
        OwnableUpgradeable(proxy).transferOwnership(owner);
    }

    function supportsInterface(
        address addr,
        bytes4 interfaceId
    )
        internal
        view
        returns (bool result)
    {
        if (!Address.isContract(addr)) return false;

        try IERC165Upgradeable(addr).supportsInterface(interfaceId) returns (bool _result) {
            result = _result;
        } catch { }
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
        if (Address.isContract(addr)) {
            return IERC1271Upgradeable(addr).isValidSignature(hash, sig) == EIP1271_MAGICVALUE;
        } else {
            return ECDSAUpgradeable.recover(hash, sig) == addr;
        }
    }

    function isSenderEOA() internal view returns (bool) {
        return msg.sender == tx.origin;
    }
}
