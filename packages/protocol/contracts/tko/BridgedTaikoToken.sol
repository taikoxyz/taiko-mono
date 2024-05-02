// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "../tokenvault/IBridgedERC20.sol";
import "./TaikoTokenBase.sol";

/// @title BridgedTaikoToken
/// @notice The TaikoToken on L2 to support checkpoints and voting. For testnets, we do not need to
/// use this contract.
/// @custom:security-contact security@taiko.xyz
contract BridgedTaikoToken is TaikoTokenBase, IBridgedERC20, ERC165Upgradeable {
    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address manager address.
    function init(address _owner, address _addressManager) external initializer {
        __Essential_init(_owner, _addressManager);
        __ERC20_init("Taiko Token", "TKO");
        __ERC20Votes_init();
        __ERC20Permit_init("Taiko Token");
        __ERC165_init();
    }

    function mint(
        address _account,
        uint256 _amount
    )
        external
        override
        whenNotPaused
        onlyFromOwnerOrNamed(LibStrings.B_ERC20_VAULT)
        nonReentrant
    {
        _mint(_account, _amount);
    }

    function burn(uint256 _amount)
        external
        override
        whenNotPaused
        onlyFromOwnerOrNamed(LibStrings.B_ERC20_VAULT)
        nonReentrant
    {
        _burn(msg.sender, _amount);
    }

    function owner() public view override(IBridgedERC20, OwnableUpgradeable) returns (address) {
        return super.owner();
    }

    /// @notice Checks if the contract supports the given interface.
    /// @param _interfaceId The interface identifier.
    /// @return true if the contract supports the interface, false otherwise.
    function supportsInterface(bytes4 _interfaceId) public view override returns (bool) {
        return
            _interfaceId == type(IBridgedERC20).interfaceId || super.supportsInterface(_interfaceId);
    }

    /// @notice Gets the canonical token's address and chain ID.
    /// @return The canonical token's address.
    /// @return The canonical token's chain ID.
    function canonical() public pure returns (address, uint256) {
        // 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800 is the TKO's mainnet address,
        // 1 is the Ethereum's network id.
        return (0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800, 1);
    }

    function changeMigrationStatus(address, bool) public pure notImplemented { }
}
