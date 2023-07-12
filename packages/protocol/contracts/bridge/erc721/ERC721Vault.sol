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
    IERC165
} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {AddressResolver} from "../../common/AddressResolver.sol";
import {EssentialContract} from "../../common/EssentialContract.sol";
import {IBridge} from "../IBridge.sol";
import {NFTVaultParent} from "../NFTVaultParent.sol";
import {Proxied} from "../../common/Proxied.sol";
import {LibERC721} from "./libs/LibERC721.sol";

/**
 * This vault holds all ERC721 tokens that users have deposited.
 * It also manages the mapping between canonical ERC721 tokens and their bridged
 * tokens.
 */
contract ERC721Vault is 
    EssentialContract,
    NFTVaultParent,
    IERC721Receiver
{
    function init(address addressManager) external initializer {
        EssentialContract._init(addressManager);
    }

    /**
     * Transfers ERC721 tokens to this vault and sends a message to the
     * destination chain so the user can receive the same (bridged) tokens
     * by invoking the message call.
     *
     * @param opts Options for sending the ERC721/ERC1155 token.
     */
    function sendToken(BridgeTransferOp calldata opts) external payable nonReentrant {
        if (
            opts.to == address(0) ||
            opts.to == resolve(opts.destChainId, "erc721_vault", false)
        ) revert NFTVAULT_INVALID_TO();

        if (opts.token == address(0)) revert NFTVAULT_INVALID_TOKEN();

        if (opts.amount != 1) revert NFTVAULT_INVALID_AMOUNT();

        bytes memory data = LibERC721.sendToken(
            msg.sender,
            opts.to,
            opts.tokenId,
            opts.token,
            opts.baseTokenUri,
            isBridgedToken[opts.token],
            bridgedToCanonical[opts.token],
            ERC721Vault.receiveToken.selector
        );
    
        IBridge.Message memory message;
        message.destChainId = opts.destChainId;
        message.owner = msg.sender;
        message.to = resolve(opts.destChainId, "erc721_vault", false);
        message.data = data;
        message.gasLimit = opts.gasLimit;
        message.processingFee = opts.processingFee;
        message.depositValue = 0;
        message.refundAddress = opts.refundAddress;
        message.memo = opts.memo;

        bytes32 msgHash = IBridge(resolve("bridge", false)).sendMessage{
            value: msg.value
        }(message);

        emit LibERC721.ERC721Sent({
            msgHash: msgHash,
            from: message.owner,
            to: opts.to,
            destChainId: opts.destChainId,
            token: opts.token,
            tokenId: opts.tokenId
        });
    }

    /**
     * @dev This function can only be called by the bridge contract while
     * invoking a message call. See sendToken, which sets the data to invoke
     * this function.
     * @param canonicalToken The canonical ERC721 token which may or may not
     * live on this chain. If not, a BridgedERC721 contract will be
     * deployed.
     * @param from The source address.
     * @param to The destination address.
     * @param tokenId The tokenId to be sent.
     */
    function receiveToken(
        CanonicalNFT calldata canonicalToken,
        address from,
        address to,
        uint256 tokenId
    ) external nonReentrant onlyFromNamed("bridge") {
        address bridgedAddress = canonicalToBridged[canonicalToken.srcChainId][canonicalToken.tokenAddr];
        (
            bool bridged,
            address bridgedToken
        ) = LibERC721.receiveToken(
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

    function releaseToken(
        IBridge.Message calldata message,
        bytes calldata proof
    )
        external nonReentrant
    {
        if (message.owner == address(0)) revert NFTVAULT_INVALID_OWNER();
        if (message.srcChainId != block.chainid) {
            revert NFTVAULT_INVALID_SRC_CHAIN_ID();
        }

        CanonicalNFT memory nft;
        address owner;
        uint256 tokenId;
        (nft, owner,,tokenId) = 
            LibERC721.decodeTokenData(message.data);

        IBridge bridge = IBridge(resolve("bridge", false));
        bytes32 msgHash = bridge.hashMessage(message);

        if (nft.tokenAddr == address(0)) revert NFTVAULT_INVALID_TOKEN();

        if (!bridge.isMessageFailed(msgHash, message.destChainId, proof)) {
            revert NFTVAULT_MESSAGE_NOT_FAILED();
        }

        address releasedToken = nft.tokenAddr;

        if (isBridgedToken[nft.tokenAddr])
        {
            releasedToken = canonicalToBridged[nft.srcChainId][nft.tokenAddr];
        }

        IERC721Upgradeable(releasedToken).safeTransferFrom(address(this), message.owner, tokenId);

        emit LibERC721.ERC721Released({
            msgHash: msgHash,
            from: message.owner,
            token: releasedToken,
            tokenId: tokenId
        });
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract ProxiedERC721Vault is Proxied, ERC721Vault { }