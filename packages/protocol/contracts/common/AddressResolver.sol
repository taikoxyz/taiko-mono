// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./IAddressManager.sol";
import "./IAddressResolver.sol";

/// @title AddressResolver
/// @notice See the documentation in {IAddressResolver}.
/// @custom:security-contact security@taiko.xyz
abstract contract AddressResolver is IAddressResolver, Initializable {
    /// @notice Address of the AddressManager.
    address public addressManager;
    uint256[49] private __gap;

    error RESOLVER_DENIED();
    error RESOLVER_INVALID_MANAGER();
    error RESOLVER_UNEXPECTED_CHAINID();
    error RESOLVER_ZERO_ADDR(uint64 chainId, bytes32 name);

    /// @dev Modifier that ensures the caller is the resolved address of a given
    /// name.
    /// @param name The name to check against.
    modifier onlyFromNamed(bytes32 name) {
        if (msg.sender != resolve(name, true)) revert RESOLVER_DENIED();
        _;
    }

    /// @inheritdoc IAddressResolver
    function resolve(
        bytes32 name,
        bool allowZeroAddress
    )
        public
        view
        virtual
        returns (address payable addr)
    {
        return _resolve(uint64(block.chainid), name, allowZeroAddress);
    }

    /// @inheritdoc IAddressResolver
    function resolve(
        uint64 chainId,
        bytes32 name,
        bool allowZeroAddress
    )
        public
        view
        virtual
        returns (address payable addr)
    {
        return _resolve(chainId, name, allowZeroAddress);
    }

    /// @dev Initialization method for setting up AddressManager reference.
    /// @param _addressManager Address of the AddressManager.
    // solhint-disable-next-line func-name-mixedcase
    function __AddressResolver_init(address _addressManager) internal virtual onlyInitializing {
        if (block.chainid > type(uint64).max) {
            revert RESOLVER_UNEXPECTED_CHAINID();
        }
        addressManager = _addressManager;
    }

    /// @dev Helper method to resolve name-to-address.
    /// @param chainId The chainId of interest.
    /// @param name Name whose address is to be resolved.
    /// @param allowZeroAddress If set to true, does not throw if the resolved
    /// address is `address(0)`.
    /// @return addr Address associated with the given name on the specified
    /// chain.
    function _resolve(
        uint64 chainId,
        bytes32 name,
        bool allowZeroAddress
    )
        private
        view
        returns (address payable addr)
    {
        if (addressManager == address(0)) revert RESOLVER_INVALID_MANAGER();

        addr = payable(IAddressManager(addressManager).getAddress(chainId, name));

        if (!allowZeroAddress && addr == address(0)) {
            revert RESOLVER_ZERO_ADDR(chainId, name);
        }
    }
}
