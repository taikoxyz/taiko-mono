// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.24;

import "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "../common/EssentialContract.sol";
import "./LibBridgedToken.sol";

/// @title BridgedERC721
/// @notice Contract for bridging ERC721 tokens across different chains.
contract BridgedERC721 is EssentialContract, ERC721Upgradeable {
    address public srcToken; // Address of the source token contract.
    uint256 public srcChainId; // Source chain ID where the token originates.

    uint256[48] private __gap;

    error BTOKEN_CANNOT_RECEIVE();
    error BTOKEN_INVALID_BURN();

    /// @dev Initializer function to be called after deployment.
    /// @param _addressManager The address of the address manager.
    /// @param _srcToken Address of the source token.
    /// @param _srcChainId Source chain ID.
    /// @param _symbol Symbol of the bridged token.
    /// @param _name Name of the bridged token.
    function init(
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

        __Essential_init(_addressManager);
        __ERC721_init(_name, _symbol);

        srcToken = _srcToken;
        srcChainId = _srcChainId;
    }

    /// @dev Mints tokens.
    /// @param account Address to receive the minted token.
    /// @param tokenId ID of the token to mint.
    function mint(
        address account,
        uint256 tokenId
    )
        public
        nonReentrant
        whenNotPaused
        onlyFromNamed("erc721_vault")
    {
        _safeMint(account, tokenId);
    }

    /// @dev Burns tokens.
    /// @param account Address from which the token is burned.
    /// @param tokenId ID of the token to burn.
    function burn(
        address account,
        uint256 tokenId
    )
        public
        nonReentrant
        whenNotPaused
        onlyFromNamed("erc721_vault")
    {
        // Check if the caller is the owner of the token.
        if (ownerOf(tokenId) != account) {
            revert BTOKEN_INVALID_BURN();
        }
        _burn(tokenId);
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
    /// @return Source token address and source chain ID.
    function source() public view returns (address, uint256) {
        return (srcToken, srcChainId);
    }

    /// @notice Returns the token URI.
    function tokenURI(uint256) public view virtual override returns (string memory) {
        return LibBridgedToken.buildURI(srcToken, srcChainId);
    }

    function _beforeTokenTransfer(
        address, /*from*/
        address to,
        uint256, /*firstTokenId*/
        uint256 /*batchSize*/
    )
        internal
        virtual
        override
    {
        if (to == address(this)) revert BTOKEN_CANNOT_RECEIVE();
        if (paused()) revert INVALID_PAUSE_STATUS();
    }
}
