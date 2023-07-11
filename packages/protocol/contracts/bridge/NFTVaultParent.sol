// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {
    IERC721Receiver
} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {
    IERC721Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {
    IERC1155Receiver
} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {
    IERC165
} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {AddressResolver} from "../common/AddressResolver.sol";
import {EssentialContract} from "../common/EssentialContract.sol";
import {IBridge} from "./IBridge.sol";
import {Proxied} from "../common/Proxied.sol";
import {LibERC721} from "./erc721/libs/LibERC721.sol";
import {LibERC1155} from "./erc1155/libs/LibERC1155.sol";

/**
 * This vault is a parent contract for ERC721 and ERC1155 vaults.
 */
contract NFTVaultParent is 
    EssentialContract
{
    /* ***************
     * Constants     *
     *************** */
    bytes4 constant ERC721_INTERFACE_ID = 0x80ac58cd;
    bytes4 constant ERC721_METADATA_INTERFACE_ID = 0x5b5e139f;
    bytes4 constant ERC721_ENUMERABLE_INTERFACE_ID = 0x780e9d63;

    bytes4 constant ERC1155_INTERFACE_ID = 0xd9b67a26;
    bytes4 constant ERC1155_METADATA_INTERFACE_ID = 0x0e89341c;

    /*********************
     * Structs           *
     *********************/

     struct CanonicalNFT {
        uint256 srcChainId;
        address tokenAddr;
        string symbol;
        string name;
        string uri;
     }

    struct BridgeTransferOp {
        uint256 destChainId;
        address to;
        address token;
        string baseTokenUri;
        uint256 tokenId;
        uint256 amount;
        uint256 gasLimit;
        uint256 processingFee;
        address refundAddress;
        string memo;
    }
    /*********************
     * State Variables   *
     *********************/

    // Tracks if a token on the current chain is a canonical or bridged token.
    mapping(address tokenAddress => bool isBridged) public isBridgedToken;

    // Mappings from bridged tokens to their canonical tokens.
    mapping(address bridgedAddress => CanonicalNFT canonicalNft)
        public bridgedToCanonical;

    // Mappings from canonical tokens to their bridged tokens.
    // Also storing chainId for tokens across other chains aside from Ethereum.
    mapping(uint256 chainId => mapping(address canonicalAddress => address bridgedAddress))
        public canonicalToBridged;

    uint256[46] private __gap;

    /*********************
     * Custom Errors*
     *********************/

    error NFTVAULT_INVALID_TO();
    error NFTVAULT_INVALID_TOKEN();
    error NFTVAULT_INVALID_AMOUNT();
    error NFT_VAULT_INVALID_CONTRACT();
    error NFTVAULT_INVALID_OWNER();
    error NFTVAULT_INVALID_SRC_CHAIN_ID();
    error NFTVAULT_INVALID_NFT_TYPE();
    error NFTVAULT_MESSAGE_NOT_FAILED();

    /*********************
     * Private Functions *
     *********************/
    /**
     * @dev Map canonical token with a bridged address
     */
    function _setBridgedToken(address bridgedToken, CanonicalNFT memory canonical) internal {
            isBridgedToken[bridgedToken] = true;
            bridgedToCanonical[bridgedToken] = canonical;
            canonicalToBridged[canonical.srcChainId][
                canonical.tokenAddr
            ] = bridgedToken;
    }
}