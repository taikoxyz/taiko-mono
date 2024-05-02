// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";
import "./IBridgedERC20.sol";
import "./LibBridgedToken.sol";

/// @title BridgedERC20
/// @notice An upgradeable ERC20 contract that represents tokens bridged from
/// another chain.
/// Note this contract offers timestamp-based checkpoints and voting functions.
/// @custom:security-contact security@taiko.xyz
contract BridgedERC20 is EssentialContract, IBridgedERC20, ERC20Upgradeable, ERC165Upgradeable {
    /// @dev Slot 1.
    address public srcToken;

    uint8 public __srcDecimals;

    /// @dev Slot 2.
    uint256 public srcChainId;

    /// @dev Slot 3.
    /// @notice The address of the contract to migrate tokens to or from.
    address public migratingAddress;

    /// @notice If true, signals migrating 'to', false if migrating 'from'.
    bool public migratingInbound;

    uint256[47] private __gap;

    /// @notice Emitted when the migration status is changed.
    /// @param addr The address migrating 'to' or 'from'.
    /// @param inbound If false then signals migrating 'from', true if migrating 'into'.
    event MigrationStatusChanged(address addr, bool inbound);

    /// @notice Emitted when tokens are migrated from an old bridged token.
    /// @param fromToken The address of the bridged token.
    /// @param account The address of the account.
    /// @param amount The amount of tokens migrated.
    event MigratedFrom(address indexed fromToken, address indexed account, uint256 amount);

    /// @notice Emitted when tokens are migrated to a new bridged token.
    /// @param toToken The address of the bridged token.
    /// @param account The address of the account.
    /// @param amount The amount of tokens migrated.
    event MigratedTo(address indexed toToken, address indexed account, uint256 amount);

    error BTOKEN_INVALID_TO_ADDR();
    error BTOKEN_INVALID_PARAMS();
    error BTOKEN_MINT_DISALLOWED();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    /// @param _srcToken The source token address.
    /// @param _srcChainId The source chain ID.
    /// @param _decimals The number of decimal places of the source token.
    /// @param _symbol The symbol of the token.
    /// @param _name The name of the token.
    function init(
        address _owner,
        address _addressManager,
        address _srcToken,
        uint256 _srcChainId,
        uint8 _decimals,
        string calldata _symbol,
        string calldata _name
    )
        external
        initializer
    {
        // Check if provided parameters are valid
        LibBridgedToken.validateInputs(_srcToken, _srcChainId, _symbol, _name);
        __Essential_init(_owner, _addressManager);
        __ERC20_init(_name, _symbol);
        __ERC165_init();

        // Set contract properties
        srcToken = _srcToken;
        srcChainId = _srcChainId;
        __srcDecimals = _decimals;
    }

    /// @notice Start or stop migration to/from a specified contract.
    /// @param _migratingAddress The address migrating 'to' or 'from'.
    /// @param _migratingInbound If false then signals migrating 'from', true if migrating 'into'.
    function changeMigrationStatus(
        address _migratingAddress,
        bool _migratingInbound
    )
        external
        whenNotPaused
        onlyFromNamed(LibStrings.B_ERC20_VAULT)
        nonReentrant
    {
        if (_migratingAddress == migratingAddress && _migratingInbound == migratingInbound) {
            revert BTOKEN_INVALID_PARAMS();
        }

        migratingAddress = _migratingAddress;
        migratingInbound = _migratingInbound;
        emit MigrationStatusChanged(_migratingAddress, _migratingInbound);
    }

    /// @notice Mints tokens to the specified account.
    /// @param _account The address of the account to receive the tokens.
    /// @param _amount The amount of tokens to mint.
    function mint(address _account, uint256 _amount) external whenNotPaused nonReentrant {
        // mint is disabled while migrating outbound.
        if (isMigratingOut()) revert BTOKEN_MINT_DISALLOWED();

        address _migratingAddress = migratingAddress;
        if (msg.sender == _migratingAddress) {
            // Inbound migration
            emit MigratedFrom(_migratingAddress, _account, _amount);
        } else {
            // Bridging from vault
            _authorizedMintBurn(msg.sender);
        }

        _mint(_account, _amount);
    }

    /// @notice Burns tokens in case of 'migrating out' from msg.sender (EOA) or from the ERC20Vault
    /// if bridging back to canonical token.
    /// @param _amount The amount of tokens to burn.
    function burn(uint256 _amount) external whenNotPaused nonReentrant {
        if (isMigratingOut()) {
            // Outbound migration
            address _migratingAddress = migratingAddress;
            emit MigratedTo(_migratingAddress, msg.sender, _amount);
            // Ask the new bridged token to mint token for the user.
            IBridgedERC20(_migratingAddress).mint(msg.sender, _amount);
        } else {
            // When user wants to burn tokens only during 'migrating out' phase is possible. If
            // ERC20Vault burns the tokens, that will go through the burn(amount) function.
            _authorizedMintBurn(msg.sender);
        }

        _burn(msg.sender, _amount);
    }

    /// @notice Gets the number of decimal places of the token.
    /// @return The number of decimal places of the token.
    function decimals() public view override returns (uint8) {
        return __srcDecimals;
    }

    /// @notice Gets the canonical token's address and chain ID.
    /// @return The canonical token's address.
    /// @return The canonical token's chain ID.
    function canonical() external view returns (address, uint256) {
        return (srcToken, srcChainId);
    }

    /// @notice Returns the owner.
    /// @return The address of the owner.
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

    function isMigratingOut() public view returns (bool) {
        return migratingAddress != address(0) && !migratingInbound;
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    )
        internal
        override
        whenNotPaused
    {
        LibBridgedToken.checkToAddress(_to);
        return super._beforeTokenTransfer(_from, _to, _amount);
    }

    function _authorizedMintBurn(address addr)
        private
        onlyFromOwnerOrNamed(LibStrings.B_ERC20_VAULT)
    { }
}
