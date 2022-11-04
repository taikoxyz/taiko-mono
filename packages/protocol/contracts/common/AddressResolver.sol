// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "./IAddressManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

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
        require(msg.sender == resolve(name), "AR:denied");
        _;
    }

    modifier onlyFromNamedEither(string memory name1, string memory name2) {
        require(
            msg.sender == resolve(name1) || msg.sender == resolve(name2),
            "AR:denied"
        );
        _;
    }

    /**
     * Resolves a name to an address on the current chain.
     *
     * @dev This function will throw if the resolved address is `address(0)`.
     * @param name The name to resolve.
     * @return The name's corresponding address.
     */
    function resolve(string memory name)
        public
        view
        virtual
        returns (address payable)
    {
        return _resolve(block.chainid, name);
    }

    /**
     * Resolves a name to an address on the specified chain.
     *
     * @dev This function will throw if the resolved address is `address(0)`.
     * @param chainId The chainId.
     * @param name The name to resolve.
     * @return The name's corresponding address.
     */
    function resolve(uint256 chainId, string memory name)
        public
        view
        virtual
        returns (address payable)
    {
        return _resolve(chainId, name);
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

    function _resolve(uint256 chainId, string memory name)
        private
        view
        returns (address payable)
    {
        bytes memory key = abi.encodePacked(
            Strings.toString(chainId),
            ".",
            name
        );
        return payable(_addressManager.getAddress(string(key)));
    }
}
