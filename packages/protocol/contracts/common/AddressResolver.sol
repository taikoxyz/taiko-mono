// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {IAddressManager} from "./IAddressManager.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * This abstract contract provides a name-to-address lookup. Under the hood,
 * it uses an AddressManager to manage the name-to-address mapping.
 *
 * @title AddressResolver
 */
abstract contract AddressResolver {
    IAddressManager internal _addressManager;

    uint256[49] private __gap;

    error RESOLVER_DENIED();
    error RESOLVER_INVALID_ADDR();

    modifier onlyFromNamed(string memory name) {
        if (msg.sender != resolve(name, false)) revert RESOLVER_DENIED();
        _;
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

    function keyForName(
        uint256 chainId,
        string memory name
    ) public pure returns (string memory key) {
        // key = string.concat(Strings.toString(chainId), ".", name);
        // TODO: the next line is cheaper in gas but will break
        //       many Hardhat tests.
        key = string(bytes.concat(bytes32(chainId), bytes(name)));
    }

    function _init(address addressManager_) internal virtual {
        if (addressManager_ == address(0)) revert RESOLVER_INVALID_ADDR();
        _addressManager = IAddressManager(addressManager_);
    }

    function _resolve(
        uint256 chainId,
        string memory name,
        bool allowZeroAddress
    ) private view returns (address payable addr) {
        string memory key = keyForName(chainId, name);

        addr = payable(_addressManager.getAddress(key));
        if (!allowZeroAddress) {
            // We do not use custom error so this string-based
            // error message is more helpful for diagnosis.
            require(addr != address(0), string.concat("AR:zeroAddr:", key));
        }
    }
}
