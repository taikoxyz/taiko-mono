// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./IAddressManager.sol";

/**
 * This abstract contract provides a name-to-address lookup. Under the hood,
 * it uses an AddressManager to manage the name-to-address mapping.
 *
 * @title AddressResolver
 * @author dantaik <dan@taiko.xyz>
 */
abstract contract AddressResolver {
    IAddressManager internal _addressManager;

    uint256[49] private __gap;

    modifier onlyFromNamed(string memory name) {
        require(msg.sender == resolve(name, false), "AR:denied");
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

    function _init(address addressManager_) internal virtual {
        require(addressManager_ != address(0), "AR:zeroAddress");
        _addressManager = IAddressManager(addressManager_);
    }

    function _resolve(
        uint256 chainId,
        string memory name,
        bool allowZeroAddress
    ) private view returns (address payable addr) {
        bytes memory key = abi.encodePacked(
            Strings.toString(chainId),
            ".",
            name
        );
        addr = payable(_addressManager.getAddress(string(key)));
        if (!allowZeroAddress) {
            require(
                addr != address(0),
                string(abi.encodePacked("AR:zeroAddr:", key))
            );
        }
    }
}
