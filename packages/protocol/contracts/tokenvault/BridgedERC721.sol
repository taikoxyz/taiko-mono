// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../common/EssentialContract.sol";
import "./LibBridgedToken.sol";

/// @title BridgedERC721
/// @notice Contract for bridging ERC721 tokens across different chains.
/// @custom:security-contact security@taiko.xyz
contract BridgedERC721 is EssentialContract, ERC721Upgradeable {
    /// @notice Address of the source token contract.
    address public srcToken;

    /// @notice Source chain ID where the token originates.
    uint256 public srcChainId;

    uint256[48] private __gap;

    error BTOKEN_CANNOT_RECEIVE();
    error BTOKEN_INVALID_BURN();

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
        // Check if provided parameters are valid
        LibBridgedToken.validateInputs(_srcToken, _srcChainId, _symbol, _name);
        __Essential_init(_owner, _addressManager);
        __ERC721_init(_name, _symbol);

        srcToken = _srcToken;
        srcChainId = _srcChainId;
    }

    /// @dev Mints tokens.
    /// @param _account Address to receive the minted token.
    /// @param _tokenId ID of the token to mint.
    function mint(
        address _account,
        uint256 _tokenId
    )
        public
        nonReentrant
        whenNotPaused
        onlyFromNamed("erc721_vault")
    {
        _safeMint(_account, _tokenId);
    }

    /// @dev Burns tokens.
    /// @param _account Address from which the token is burned.
    /// @param _tokenId ID of the token to burn.
    function burn(
        address _account,
        uint256 _tokenId
    )
        public
        nonReentrant
        whenNotPaused
        onlyFromNamed("erc721_vault")
    {
        // Check if the caller is the owner of the token.
        if (ownerOf(_tokenId) != _account) {
            revert BTOKEN_INVALID_BURN();
        }
        _burn(_tokenId);
    }

    /// @notice Gets the name of the token.
    /// @return The name.
    function name() public view override(ERC721Upgradeable) returns (string memory) {
        return LibBridgedToken.buildName(super.name(), srcChainId);
    }

    /// @notice Gets the symbol of the bridged token.
    /// @return The symbol.
    function symbol() public view override(ERC721Upgradeable) returns (string memory) {
        return LibBridgedToken.buildSymbol(super.symbol());
    }

    /// @notice Gets the source token and source chain ID being bridged.
    /// @return The source token's address.
    /// @return The source token's chain ID.
    function source() public view returns (address, uint256) {
        return (srcToken, srcChainId);
    }

    /// @notice Returns the token URI.
    /// @param _tokenId The token id.
    /// @return The token URI following EIP-681.
    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        return string(
            abi.encodePacked(
                LibBridgedToken.buildURI(srcToken, srcChainId), Strings.toString(_tokenId)
            )
        );
    }

    function _beforeTokenTransfer(
        address, /*_from*/
        address _to,
        uint256, /*_firstTokenId*/
        uint256 /*_batchSize*/
    )
        internal
        virtual
        override
    {
        if (_to == address(this)) revert BTOKEN_CANNOT_RECEIVE();
        if (paused()) revert INVALID_PAUSE_STATUS();
    }
}
