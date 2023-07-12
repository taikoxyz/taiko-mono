// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {
    IERC1155Receiver
} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {
    IERC1155Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import {
    IERC165
} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {AddressResolver} from "../../common/AddressResolver.sol";
import {EssentialContract} from "../../common/EssentialContract.sol";
import {IBridge} from "../IBridge.sol";
import {NFTVaultParent} from "../NFTVaultParent.sol";
import {Proxied} from "../../common/Proxied.sol";
import {LibERC1155} from "./libs/LibERC1155.sol";

/**
 * This vault holds all ERC721 and ERC1155 tokens that users have deposited.
 * It also manages the mapping between canonical ERC721/1155 tokens and their bridged
 * tokens.
 */
contract ERC1155Vault is 
    EssentialContract,
    NFTVaultParent,
    IERC1155Receiver
{
    function init(address addressManager) external initializer {
        EssentialContract._init(addressManager);
    }

    /**
     * Transfers ERC1155 tokens to this vault and sends a message to the
     * destination chain so the user can receive the same (bridged) tokens
     * by invoking the message call.
     *
     * @param opts Options for sending the ERC1155 token.
     */
    function sendToken(BridgeTransferOp calldata opts) external payable nonReentrant {
        if (
            opts.to == address(0) ||
            opts.to == resolve(opts.destChainId, "erc1155_vault", false)
        ) revert NFTVAULT_INVALID_TO();

        if (opts.token == address(0)) revert NFTVAULT_INVALID_TOKEN();

        if (opts.amount == 0) revert NFTVAULT_INVALID_AMOUNT();

        bytes memory data = LibERC1155.sendToken(
            msg.sender,
            opts.to,
            opts.tokenId,
            opts.token,
            opts.baseTokenUri,
            opts.amount,
            isBridgedToken[opts.token],
            bridgedToCanonical[opts.token],
            ERC1155Vault.receiveToken.selector
        );

        IBridge.Message memory message;
        message.destChainId = opts.destChainId;
        message.owner = msg.sender;
        message.to = resolve(opts.destChainId, "erc1155_vault", false);
        message.data = data;
        message.gasLimit = opts.gasLimit;
        message.processingFee = opts.processingFee;
        message.depositValue = 0;
        message.refundAddress = opts.refundAddress;
        message.memo = opts.memo;

        bytes32 msgHash = IBridge(resolve("bridge", false)).sendMessage{
            value: msg.value
        }(message);

        emit LibERC1155.ERC1155Sent({
            msgHash: msgHash,
            from: message.owner,
            to: opts.to,
            destChainId: opts.destChainId,
            token: opts.token,
            tokenId: opts.tokenId,
            amount: opts.amount
        });
    }

    /**
     * @dev This function can only be called by the bridge contract while
     * invoking a message call. See sendToken, which sets the data to invoke
     * this function.
     * @param canonicalToken The canonical ERC1155 token which may or may not
     * live on this chain. If not, a BridgedERC1155 contract will be
     * deployed.
     * @param from The source address.
     * @param to The destination address.
     * @param tokenId The tokenId to be sent.
     * @param amount The amount to be sent.
     */
    function receiveToken(
        NFTVaultParent.CanonicalNFT calldata canonicalToken,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) external nonReentrant onlyFromNamed("bridge") {
        address bridgedAddress = canonicalToBridged[canonicalToken.srcChainId][canonicalToken.tokenAddr];
        (
            bool bridged,
            address bridgedToken
        ) = LibERC1155.receiveToken(
                AddressResolver(this),
                address(_addressManager),
                canonicalToken,
                from,
                to,
                tokenId,
                amount,
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
        uint256 amount;
        (nft, owner,,tokenId, amount) = 
            LibERC1155.decodeTokenData(message.data);

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

        IERC1155Upgradeable(releasedToken).safeTransferFrom(address(this), message.owner, tokenId, amount, "");

        emit LibERC1155.ERC1155Released({
            msgHash: msgHash,
            from: message.owner,
            token: releasedToken,
            tokenId: tokenId,
            amount: amount
        });
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
            interfaceId == ERC1155_INTERFACE_ID ||
            interfaceId == ERC1155_METADATA_INTERFACE_ID;
    }
}

contract ProxiedERC1155Vault is Proxied, ERC1155Vault { }