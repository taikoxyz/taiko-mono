// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

import "./IAddressManager.sol";

/**
 * @author dantaik <dan@taiko.xyz>
 * @notice This abstract contract provides a name-to-address lookup.
 *         Under the hood, it uses an AddressManager to manage the
 *         name-to-address mapping.
 */
abstract contract AddressResolver is ContextUpgradeable {
    IAddressManager internal _addressManager;

    uint256[49] private __gap;

    modifier onlyFromNamed(string memory name) {
        require(_msgSender() == resolve(name), "AR:denied");
        _;
    }

    modifier onlyFromNamedEither(string memory name1, string memory name2) {
        address sender = _msgSender();
        require(
            sender == resolve(name1) || sender == resolve(name2),
            "AR:denied"
        );
        _;
    }

    /**
     * @notice Resolves a name to an address.
     * @dev This funcition will throw if the resolved address is `address(0)`.
     * @param name The name to resolve
     * @return addr The name's corresponding address
     */
    function resolve(string memory name)
        public
        view
        virtual
        returns (address payable addr)
    {
        addr = payable(_addressManager.getAddress(name));
    }

    /**
     * @notice Returns the AddressManager's address.
     * @return The AddressManager's address.
     */
    function addressManager() public view returns (address) {
        return address(_addressManager);
    }

    function _init(address addressManager_) internal virtual {
        ContextUpgradeable.__Context_init_unchained();
        _addressManager = IAddressManager(addressManager_);
    }
}
