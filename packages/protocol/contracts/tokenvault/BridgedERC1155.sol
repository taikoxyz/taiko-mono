// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import
    "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/IERC1155MetadataURIUpgradeable.sol";
import "../common/EssentialContract.sol";
import "./LibBridgedToken.sol";

/// @title BridgedERC1155
/// @notice Contract for bridging ERC1155 tokens across different chains.
/// @custom:security-contact security@taiko.xyz
contract BridgedERC1155 is EssentialContract, IERC1155MetadataURIUpgradeable, ERC1155Upgradeable {
    address public srcToken; // Address of the source token contract.
    uint256 public srcChainId; // Source chain ID where the token originates.
    string private symbol_; // Symbol of the bridged token.
    string private name_; // Name of the bridged token.

    uint256[46] private __gap;

    error BTOKEN_CANNOT_RECEIVE();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    /// @param _srcToken Address of the source token.
    /// @param _srcChainId Source chain ID.
    /// @param _symbol Symbol of the bridged token.
    /// @param _name Name of the bridged token.
    function init(
        address _owner,
        address _addressManager,
        address _srcToken,
        uint256 _srcChainId,
        string memory _symbol,
        string memory _name
    )
        external
        initializer
    {
        // Check if provided parameters are valid.
        // The symbol and the name can be empty for ERC1155 tokens so we use some placeholder data
        // for them instead.
        LibBridgedToken.validateInputs(_srcToken, _srcChainId, "foo", "foo");
        __Essential_init(_owner, _addressManager);
        __ERC1155_init(LibBridgedToken.buildURI(_srcToken, _srcChainId));

        srcToken = _srcToken;
        srcChainId = _srcChainId;
        symbol_ = _symbol;
        name_ = _name;
    }

    /// @dev Mints tokens.
    /// @param to Address to receive the minted tokens.
    /// @param tokenId ID of the token to mint.
    /// @param amount Amount of tokens to mint.
    function mint(
        address to,
        uint256 tokenId,
        uint256 amount
    )
        public
        nonReentrant
        whenNotPaused
        onlyFromNamed("erc1155_vault")
    {
        _mint(to, tokenId, amount, "");
    }

    /// @dev Mints tokens.
    /// @param to Address to receive the minted tokens.
    /// @param tokenIds ID of the token to mint.
    /// @param amounts Amount of tokens to mint.
    function mintBatch(
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    )
        public
        nonReentrant
        whenNotPaused
        onlyFromNamed("erc1155_vault")
    {
        _mintBatch(to, tokenIds, amounts, "");
    }

    /// @dev Burns tokens.
    /// @param account Address from which tokens are burned.
    /// @param tokenId ID of the token to burn.
    /// @param amount Amount of tokens to burn.
    function burn(
        address account,
        uint256 tokenId,
        uint256 amount
    )
        public
        nonReentrant
        whenNotPaused
        onlyFromNamed("erc1155_vault")
    {
        _burn(account, tokenId, amount);
    }

    /// @notice Gets the name of the bridged token.
    /// @return The name.
    function name() public view returns (string memory) {
        return LibBridgedToken.buildName(name_, srcChainId);
    }

    /// @notice Gets the symbol of the bridged token.
    /// @return The symbol.
    function symbol() public view returns (string memory) {
        return LibBridgedToken.buildSymbol(symbol_);
    }

    function _beforeTokenTransfer(
        address, /*operator*/
        address, /*from*/
        address to,
        uint256[] memory, /*ids*/
        uint256[] memory, /*amounts*/
        bytes memory /*data*/
    )
        internal
        virtual
        override
    {
        if (to == address(this)) revert BTOKEN_CANNOT_RECEIVE();
        if (paused()) revert INVALID_PAUSE_STATUS();
    }
}
