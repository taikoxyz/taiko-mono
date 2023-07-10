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
    IERC1155Receiver
} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {
    IERC165
} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {AddressResolver} from "../common/AddressResolver.sol";
import {EssentialContract} from "../common/EssentialContract.sol";
import {IBridge} from "./IBridge.sol";
import {LibERC721} from "./erc721/libs/LibERC721.sol";

/**
 * This vault holds all ERC721 and ERC1155 tokens that users have deposited.
 * It also manages the mapping between canonical ERC721/1155 tokens and their bridged
 * tokens.
 */
contract NFTVault is 
    EssentialContract,
    IERC721Receiver,
    IERC1155Receiver
{
    /* ***************
     * Constants     *
     *************** */
    bytes4 constant ERC721_INTERFACE_ID = 0x80ac58cd;
    bytes4 constant ERC721_METADATA_INTERFACE_ID = 0x5b5e139f;
    bytes4 constant ERC721_ENUMERABLE_INTERFACE_ID = 0x780e9d63;

    bytes4 constant ERC1155_INTERFACE_ID = 0xd9b67a26;
    bytes4 constant ERC1155_METADATA_INTERFACE_ID = 0x0e89341c;

    enum NFTType{ ERC721, ERC1155}

    /*********************
     * Structs           *
     *********************/

     struct CanonicalNFT {
        uint256 srcChainId;
        address tokenAddr;
        string symbol;
        string name;
        string uri;
        NFTType nftType;
     }

    struct SendNFTOpts {
        uint256 destChainId;
        address to;
        address token;
        string tokenUri;
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
    error NFTVAULT_INVALID_VALUE();
    error NFTVAULT_INVALID_TOKEN();
    error NFTVAULT_INVALID_AMOUNT();
    error NFTVAULT_CANONICAL_TOKEN_NOT_FOUND();
    error NFTVAULT_INVALID_OWNER();
    error NFTVAULT_INVALID_SRC_CHAIN_ID();
    error NFTVAULT_MESSAGE_NOT_FAILED();
    error NFTVAULT_INVALID_SENDER();
    error NFTVAULT_INVALID_NFT_TYPE();

    /*********************
     * External Functions*
     *********************/

    function init(address addressManager) external initializer {
        EssentialContract._init(addressManager);
    }

    /**
     * Transfers ERC721 tokens to this vault and sends a message to the
     * destination chain so the user can receive the same amount of tokens
     * by invoking the message call.
     *
     * @param opts Options for sending the ERC721 token.
     */
    function sendNFT(SendNFTOpts calldata opts) external payable nonReentrant {
        if (
            opts.to == address(0) ||
            opts.to == resolve(opts.destChainId, "nft_vault", false)
        ) revert NFTVAULT_INVALID_TO();

        if (opts.token == address(0)) revert NFTVAULT_INVALID_TOKEN();

        if (opts.tokenId == 0) revert NFTVAULT_INVALID_AMOUNT();

        NFTType nftType = _getNftType(opts.token);

        bytes memory data;
        if (nftType == NFTType.ERC721) {
            data = LibERC721.sendErc721(
                msg.sender,
                opts.to,
                opts.tokenId,
                opts.token,
                opts.tokenUri,
                isBridgedToken[opts.token],
                bridgedToCanonical[opts.token],
                NFTVault.receiveERC721.selector
            );
        } else {
            // data = LibERC1155.sendErc1155()
        }

        IBridge.Message memory message;
        message.destChainId = opts.destChainId;
        message.owner = msg.sender;
        message.to = resolve(opts.destChainId, "nft_vault", false);
        message.data = data;
        message.gasLimit = opts.gasLimit;
        message.processingFee = opts.processingFee;
        message.depositValue = msg.value - opts.processingFee;
        message.refundAddress = opts.refundAddress;
        message.memo = opts.memo;

        bytes32 msgHash = IBridge(resolve("bridge", false)).sendMessage{
            value: msg.value
        }(message);

        if (nftType == NFTType.ERC721) {
            emit LibERC721.ERC721Sent({
                msgHash: msgHash,
                from: message.owner,
                to: opts.to,
                destChainId: opts.destChainId,
                token: opts.token,
                tokenId: opts.tokenId
            });
        } else {
            // Emit ERC1155
        }
    }

    /**
     * @dev This function can only be called by the bridge contract while
     * invoking a message call. See sendNFT, which sets the data to invoke
     * this function.
     * @param canonicalToken The canonical ERC721 token which may or may not
     * live on this chain. If not, a BridgedERC721 contract will be
     * deployed.
     * @param from The source address.
     * @param to The destination address.
     * @param tokenId The tokenId to be sent.
     */
    function receiveERC721(
        CanonicalNFT calldata canonicalToken,
        address from,
        address to,
        uint256 tokenId
    ) external nonReentrant onlyFromNamed("bridge") {
        address bridgedAddress = canonicalToBridged[canonicalToken.srcChainId][canonicalToken.tokenAddr];
        (
            bool bridged,
            /*CanonicalNFT memory canonical,-> Not needed, input canonicalToken is readonly in lib and to avoid still stack too deep*/
            address bridgedToken
        ) = LibERC721.receiveERC721(
                AddressResolver(this),
                address(_addressManager),
                canonicalToken,
                from,
                to,
                tokenId,
                bridgedAddress
            );
        
        if (bridged) {
            _setBridgedToken(bridgedToken, canonicalToken);
        }
    }

    /*********************
     * Private Functions *
     *********************/

    function _getNftType(address token) internal view returns (NFTType) {
        if (IERC165(token).supportsInterface(ERC721_INTERFACE_ID)
            || IERC165(token).supportsInterface(ERC721_METADATA_INTERFACE_ID)
            || IERC165(token).supportsInterface(ERC721_ENUMERABLE_INTERFACE_ID)) {
            return NFTType.ERC721;
        } else if (IERC165(token).supportsInterface(ERC1155_INTERFACE_ID)) {
            return NFTType.ERC1155;
        } else {
            revert NFTVAULT_INVALID_NFT_TYPE();
        }
    }

    function _setBridgedToken(address bridgedToken, CanonicalNFT memory canonical) internal {
            isBridgedToken[bridgedToken] = true;
            bridgedToCanonical[bridgedToken] = canonical;
            canonicalToBridged[canonical.srcChainId][
                canonical.tokenAddr
            ] = bridgedToken;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4){
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165) returns (bool) {
        return
            interfaceId == ERC721_INTERFACE_ID ||
            interfaceId == ERC721_METADATA_INTERFACE_ID ||
            interfaceId == ERC721_ENUMERABLE_INTERFACE_ID ||
            interfaceId == ERC1155_INTERFACE_ID ||
            interfaceId == ERC1155_METADATA_INTERFACE_ID;
    }
}
