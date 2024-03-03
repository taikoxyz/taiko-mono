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
    /// @notice Address of the source token contract.
    address public srcToken;

    /// @notice Source chain ID where the token originates.
    uint256 public srcChainId;

    /// @dev Symbol of the bridged token.
    string private __symbol;

    /// @dev Name of the bridged token.
    string private __name;

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
        __symbol = _symbol;
        __name = _name;
    }

    /// @dev Mints tokens.
    /// @param _to Address to receive the minted tokens.
    /// @param _tokenId ID of the token to mint.
    /// @param _amount Amount of tokens to mint.
    function mint(
        address _to,
        uint256 _tokenId,
        uint256 _amount
    )
        public
        nonReentrant
        whenNotPaused
        onlyFromNamed("erc1155_vault")
    {
        _mint(_to, _tokenId, _amount, "");
    }

    /// @dev Mints tokens.
    /// @param _to Address to receive the minted tokens.
    /// @param _tokenIds ID of the token to mint.
    /// @param _amounts Amount of tokens to mint.
    function mintBatch(
        address _to,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts
    )
        public
        nonReentrant
        whenNotPaused
        onlyFromNamed("erc1155_vault")
    {
        _mintBatch(_to, _tokenIds, _amounts, "");
    }

    /// @dev Burns tokens.
    /// @param _account Address from which tokens are burned.
    /// @param _tokenId ID of the token to burn.
    /// @param _amount Amount of tokens to burn.
    function burn(
        address _account,
        uint256 _tokenId,
        uint256 _amount
    )
        public
        nonReentrant
        whenNotPaused
        onlyFromNamed("erc1155_vault")
    {
        _burn(_account, _tokenId, _amount);
    }

    /// @notice Gets the name of the bridged token.
    /// @return The name.
    function name() public view returns (string memory) {
        return LibBridgedToken.buildName(__name, srcChainId);
    }

    /// @notice Gets the symbol of the bridged token.
    /// @return The symbol.
    function symbol() public view returns (string memory) {
        return LibBridgedToken.buildSymbol(__symbol);
    }

    function _beforeTokenTransfer(
        address, /*_operator*/
        address, /*_from*/
        address _to,
        uint256[] memory, /*_ids*/
        uint256[] memory, /*_amounts*/
        bytes memory /*_data*/
    )
        internal
        virtual
        override
    {
        if (_to == address(this)) revert BTOKEN_CANNOT_RECEIVE();
        if (paused()) revert INVALID_PAUSE_STATUS();
    }
}
