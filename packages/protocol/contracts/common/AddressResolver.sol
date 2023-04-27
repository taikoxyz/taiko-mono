// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {IAddressManager} from "./AddressManager.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * This abstract contract provides a name-to-address lookup. Under the hood,
 * it uses an AddressManager to manage the name-to-address mapping.
 *
 * @title AddressResolver
 */
abstract contract AddressResolver is OwnableUpgradeable {
    address internal _addressManager;

    uint256[49] private __gap;

    event AddressSet(address oldAddressManager, address newAddressManager);

    error RESOLVER_DENIED();
    error RESOLVER_INVALID_ADDR();

    modifier onlyFromNamed(string memory name) {
        if (msg.sender != resolve(name, false)) revert RESOLVER_DENIED();
        _;
    }

    function setAddressManager(address newAddressManager) external onlyOwner {
        _setAddressManager(newAddressManager);
    }

    /**
     * Resolves a name to an address on the current chain.
     *
     * @dev This function will throw if the resolved address is `address(0)`.
     * @param name The name to resolve.
     * @param allowZeroAddress True to allow zero address to be returned.
     * @return The name's corresponding address.
     */
    function resolve(
        string memory name,
        bool allowZeroAddress
    ) public view virtual returns (address payable) {
        return _resolve(block.chainid, name, allowZeroAddress);
    }

    /**
     * Resolves a name to an address on the specified chain.
     *
     * @dev This function will throw if the resolved address is `address(0)`.
     * @param chainId The chainId.
     * @param name The name to resolve.
     * @param allowZeroAddress True to allow zero address to be returned.
     * @return The name's corresponding address.
     */
    function resolve(
        uint256 chainId,
        string memory name,
        bool allowZeroAddress
    ) public view virtual returns (address payable) {
        return _resolve(chainId, name, allowZeroAddress);
    }

    /**
     * Returns the AddressManager's address.
     *
     * @return The AddressManager's address.
     */
    function addressManager() public view returns (address) {
        return address(_addressManager);
    }

    function _init(address addressManager_) internal virtual {
        OwnableUpgradeable.__Ownable_init();
        _setAddressManager(addressManager_);
    }

    function _setAddressManager(address newAddressManager) private {
        if (newAddressManager == address(0)) revert RESOLVER_INVALID_ADDR();
        emit AddressSet(_addressManager, newAddressManager);
        _addressManager = newAddressManager;
    }

    function _resolve(
        uint256 chainId,
        string memory name,
        bool allowZeroAddress
    ) private view returns (address payable addr) {
        addr = payable(
            IAddressManager(_addressManager).getAddress(chainId, name)
        );

        if (!allowZeroAddress) {
            // We do not use custom error so this string-based
            // error message is more helpful for diagnosis.
            require(
                addr != address(0),
                string(abi.encode("AR:zeroAddr:", chainId, ".", name))
            );
        }
    }
}
