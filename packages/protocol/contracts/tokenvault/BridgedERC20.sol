// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import
    "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "../common/EssentialContract.sol";
import "./LibBridgedToken.sol";
import "./IBridgedERC20.sol";

/// @title BridgedERC20
/// @notice An upgradeable ERC20 contract that represents tokens bridged from
/// another chain.
contract BridgedERC20 is
    EssentialContract,
    IBridgedERC20,
    IERC20MetadataUpgradeable,
    ERC20Upgradeable
{
    address public srcToken; // slot 1
    uint8 private srcDecimals;
    uint256 public srcChainId; // slot 2

    address public migratingFrom; // slot 3
    address public migratingTo; // slot 4

    uint256[46] private __gap;

    event Migration(address from, address to);

    event MigratedTo(address indexed token, address indexed account, uint256 amount);
    event MigratedFrom(address indexed token, address indexed account, uint256 amount);

    error BRIDGED_TOKEN_CANNOT_RECEIVE();
    error BRIDGED_TOKEN_INVALID_PARAMS();
    error BRIDGED_TOKEN_PERMISSION_DENIED();

    /// @notice Initializes the contract.
    /// @dev Different BridgedERC20 Contract is deployed per unique _srcToken
    /// (e.g., one for USDC, one for USDT, etc.).
    /// @param _addressManager The address manager.
    /// @param _srcToken The source token address.
    /// @param _srcChainId The source chain ID.
    /// @param _decimals The number of decimal places of the source token.
    /// @param _symbol The symbol of the token.
    /// @param _name The name of the token.
    function init(
        address _addressManager,
        address _srcToken,
        uint256 _srcChainId,
        uint8 _decimals,
        string memory _symbol,
        string memory _name
    )
        external
        initializer
    {
        // Check if provided parameters are valid
        if (
            _srcToken == address(0) || _srcChainId == 0 || _srcChainId == block.chainid
                || bytes(_symbol).length == 0 || bytes(_name).length == 0
        ) {
            revert BRIDGED_TOKEN_INVALID_PARAMS();
        }

        // Initialize OwnerUUPSUpgradable and ERC20Upgradeable
        _Essential_init(_addressManager);
        __ERC20_init({ name_: _name, symbol_: _symbol });

        // Set contract properties
        srcToken = _srcToken;
        srcChainId = _srcChainId;
        srcDecimals = _decimals;
    }

    function startOutboundMigration(address to)
        external
        nonReentrant
        whenNotPaused
        onlyFromNamed("erc20_vault")
    {
        if (migratingTo != address(0)) revert BRIDGED_TOKEN_PERMISSION_DENIED();
        if (to == address(0)) revert BRIDGED_TOKEN_INVALID_PARAMS();

        migratingTo = to;
        emit Migration(migratingFrom, migratingTo);
    }

    function startInboundMigration(address from)
        external
        nonReentrant
        whenNotPaused
        onlyFromNamed("erc20_vault")
    {
        if (migratingFrom != address(0)) revert BRIDGED_TOKEN_PERMISSION_DENIED();
        if (from == address(0)) revert BRIDGED_TOKEN_INVALID_PARAMS();

        migratingFrom = from;
        emit Migration(migratingFrom, migratingTo);
    }

    function stopInboundMigration() external nonReentrant whenNotPaused onlyOwner {
        if (migratingFrom == address(0)) revert BRIDGED_TOKEN_PERMISSION_DENIED();
        migratingFrom = address(0);
        emit Migration(migratingFrom, migratingTo);
    }

    /// @notice Mints tokens to an account.
    /// @param account The account to mint tokens to.
    /// @param amount The amount of tokens to mint.
    function mint(address account, uint256 amount) public nonReentrant whenNotPaused {
        if (migratingFrom == address(0)) {
            if (msg.sender != resolve("erc20_vault", true)) revert RESOLVER_DENIED();
            emit Transfer(address(0), account, amount);
        } else {
            if (msg.sender != migratingFrom) revert BRIDGED_TOKEN_PERMISSION_DENIED();
            emit MigratedTo(migratingFrom, account, amount);
        }

        _mint(account, amount);
    }

    /// @notice Burns tokens from an account.
    /// @param account The account to burn tokens from.
    /// @param amount The amount of tokens to burn.
    function burn(address account, uint256 amount) public nonReentrant whenNotPaused {
        if (migratingTo == address(0)) {
            if (msg.sender != resolve("erc20_vault", true)) revert RESOLVER_DENIED();
            emit Transfer(account, address(0), amount);
        } else {
            IBridgedERC20(migratingTo).mint(account, amount);
            emit MigratedTo(migratingTo, account, amount);
        }

        _burn(account, amount);
    }

    /// @notice Transfers tokens from the caller to another account.
    /// @dev Any address can call this. Caller must have at least 'amount' to
    /// call this.
    /// @param to The account to transfer tokens to.
    /// @param amount The amount of tokens to transfer.
    function transfer(
        address to,
        uint256 amount
    )
        public
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (bool)
    {
        if (to == address(this)) {
            revert BRIDGED_TOKEN_CANNOT_RECEIVE();
        }
        return ERC20Upgradeable.transfer(to, amount);
    }

    /// @notice Transfers tokens from one account to another account.
    /// @dev Any address can call this. Caller must have allowance of at least
    /// 'amount' for 'from's tokens.
    /// @param from The account to transfer tokens from.
    /// @param to The account to transfer tokens to.
    /// @param amount The amount of tokens to transfer.
    function transferFrom(
        address from,
        address to,
        uint256 amount
    )
        public
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (bool)
    {
        if (to == address(this)) {
            revert BRIDGED_TOKEN_CANNOT_RECEIVE();
        }
        return ERC20Upgradeable.transferFrom(from, to, amount);
    }

    /// @notice Gets the name of the token.
    /// @return The name.
    function name()
        public
        view
        override(ERC20Upgradeable, IERC20MetadataUpgradeable)
        returns (string memory)
    {
        return LibBridgedToken.buildName(super.name(), srcChainId);
    }

    /// @notice Gets the symbol of the bridged token.
    /// @return The symbol.
    function symbol()
        public
        view
        override(ERC20Upgradeable, IERC20MetadataUpgradeable)
        returns (string memory)
    {
        return LibBridgedToken.buildSymbol(super.symbol());
    }

    /// @notice Gets the number of decimal places of the token.
    /// @return The number of decimal places of the token.
    function decimals()
        public
        view
        override(ERC20Upgradeable, IERC20MetadataUpgradeable)
        returns (uint8)
    {
        return srcDecimals;
    }

    /// @notice Gets the canonical token's address and chain ID.
    /// @return The canonical token's address and chain ID.
    function canonical() public view returns (address, uint256) {
        return (srcToken, srcChainId);
    }
}
