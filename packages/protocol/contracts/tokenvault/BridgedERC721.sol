// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../common/EssentialContract.sol";
import { ERC721Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { Proxied } from "../common/Proxied.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/// @title BridgedERC721
/// @notice Contract for bridging ERC721 tokens across different chains.
contract BridgedERC721 is EssentialContract, ERC721Upgradeable {
    address public srcToken; // Address of the source token contract.
    uint256 public srcChainId; // Source chain ID where the token originates.

    uint256[48] private __gap;

    error BRIDGED_TOKEN_CANNOT_RECEIVE();
    error BRIDGED_TOKEN_INVALID_PARAMS();
    error BRIDGED_TOKEN_INVALID_BURN();

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
        if (
            _srcToken == address(0) || _srcChainId == 0
                || _srcChainId == block.chainid || bytes(_symbol).length == 0
                || bytes(_name).length == 0
        ) {
            revert BRIDGED_TOKEN_INVALID_PARAMS();
        }
        EssentialContract._init(_addressManager);
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
        onlyFromNamed("erc721_vault")
    {
        _mint(account, tokenId);
        emit Transfer(address(0), account, tokenId);
    }

    /// @dev Burns tokens.
    /// @param account Address from which the token is burned.
    /// @param tokenId ID of the token to burn.
    function burn(
        address account,
        uint256 tokenId
    )
        public
        onlyFromNamed("erc721_vault")
    {
        // Check if the caller is the owner of the token.
        if (ownerOf(tokenId) != account) {
            revert BRIDGED_TOKEN_INVALID_BURN();
        }

        _burn(tokenId);
        emit Transfer(account, address(0), tokenId);
    }

    /// @dev Safely transfers tokens from one address to another.
    /// @param from Address from which the token is transferred.
    /// @param to Address to which the token is transferred.
    /// @param tokenId ID of the token to transfer.
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    )
        public
        override(ERC721Upgradeable)
    {
        if (to == address(this)) {
            revert BRIDGED_TOKEN_CANNOT_RECEIVE();
        }
        return ERC721Upgradeable.transferFrom(from, to, tokenId);
    }

    /// @notice Gets the concatenated name of the bridged token.
    /// @return The concatenated name.
    function name()
        public
        view
        override(ERC721Upgradeable)
        returns (string memory)
    {
        return string.concat(
            super.name(), unicode" ⭀", Strings.toString(srcChainId)
        );
    }

    /// @notice Gets the source token and source chain ID being bridged.
    /// @return Source token address and source chain ID.
    function source() public view returns (address, uint256) {
        return (srcToken, srcChainId);
    }

    /// @notice Returns an empty token URI.
    /// @param tokenId ID of the token.
    /// @return An empty string.
    function tokenURI(uint256 tokenId)
        public
        pure
        virtual
        override
        returns (string memory)
    {
        return "";
    }
}

/// @title ProxiedBridgedERC721
/// @notice Proxied version of the parent contract.
contract ProxiedBridgedERC721 is Proxied, BridgedERC721 { }
