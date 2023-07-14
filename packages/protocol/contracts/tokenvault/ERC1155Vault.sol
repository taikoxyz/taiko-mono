// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { IERC1155Receiver } from
    "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC1155Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import { IERC165 } from
    "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { Create2Upgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/Create2Upgradeable.sol";
import { ERC1155Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { AddressResolver } from "../common/AddressResolver.sol";
import { IBridge } from "../bridge/IBridge.sol";
import { BridgedERC1155 } from "./BridgedERC1155.sol";
import { BaseNFTVault } from "./BaseNFTVault.sol";
import { Proxied } from "../common/Proxied.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * This vault holds all ERC721 and ERC1155 tokens that users have deposited.
 * It also manages the mapping between canonical ERC721/1155 tokens and their
 * bridged
 * tokens.
 */
contract ERC1155Vault is BaseNFTVault, IERC1155Receiver {
    bytes4 public constant ERC1155_INTERFACE_ID = 0xd9b67a26;
    bytes4 public constant ERC1155_METADATA_INTERFACE_ID = 0x0e89341c;

    event BridgedTokenDeployed(
        uint256 indexed srcChainId,
        address indexed canonicalToken,
        address indexed bridgedToken
    );

    event TokenSent(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint256 destChainId,
        address token,
        uint256 tokenId,
        uint256 amount
    );

    event TokenReleased(
        bytes32 indexed msgHash,
        address indexed from,
        address token,
        uint256 tokenId,
        uint256 amount
    );

    event TokenReceived(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint256 srcChainId,
        address token,
        uint256 tokenId,
        uint256 amount
    );

    /**
     * Transfers ERC1155 tokens to this vault and sends a message to the
     * destination chain so the user can receive the same (bridged) tokens
     * by invoking the message call.
     *
     * @param opt Option for sending the ERC1155 token.
     */
    function sendToken(BridgeTransferOp calldata opt)
        external
        payable
        nonReentrant
        onlyValidAddresses(opt.destChainId, "erc1155_vault", opt.to, opt.token)
    {
        if (opt.amount == 0) revert VAULT_INVALID_AMOUNT();

        if (!IERC165(opt.token).supportsInterface(ERC1155_INTERFACE_ID)) {
            revert VAULT_INTERFACE_NOT_SUPPORTED();
        }

        IBridge.Message memory message;
        message.destChainId = opt.destChainId;
        message.owner = msg.sender;
        message.to = resolve(opt.destChainId, "erc1155_vault", false);
        message.data = _sendToken(
            msg.sender,
            opt.to,
            opt.tokenId,
            opt.token,
            opt.baseTokenUri,
            opt.amount,
            isBridgedToken[opt.token],
            bridgedToCanonical[opt.token],
            ERC1155Vault.receiveToken.selector
        );
        message.gasLimit = opt.gasLimit;
        message.processingFee = opt.processingFee;
        message.depositValue = 0;
        message.refundAddress = opt.refundAddress;
        message.memo = opt.memo;

        bytes32 msgHash = IBridge(resolve("bridge", false)).sendMessage{
            value: msg.value
        }(message);

        emit TokenSent({
            msgHash: msgHash,
            from: message.owner,
            to: opt.to,
            destChainId: opt.destChainId,
            token: opt.token,
            tokenId: opt.tokenId,
            amount: opt.amount
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
        BaseNFTVault.CanonicalNFT calldata canonicalToken,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    )
        external
        nonReentrant
        onlyFromNamed("bridge")
    {
        address bridgedAddress = canonicalToBridged[canonicalToken.srcChainId][canonicalToken
            .tokenAddr];
        (bool bridged, address bridgedToken) = _receiveToken(
            address(_addressManager),
            canonicalToken,
            from,
            to,
            tokenId,
            amount,
            bridgedAddress
        );

        if (bridged) {
            setBridgedToken(bridgedToken, canonicalToken);
        }
    }

    function releaseToken(
        IBridge.Message calldata message,
        bytes calldata proof
    )
        external
        nonReentrant
    {
        if (message.owner == address(0)) revert VAULT_INVALID_OWNER();
        if (message.srcChainId != block.chainid) {
            revert VAULT_INVALID_SRC_CHAIN_ID();
        }

        CanonicalNFT memory nft;
        address owner;
        uint256 tokenId;
        uint256 amount;
        (nft, owner,, tokenId, amount) = decodeTokenData(message.data);

        bytes32 msgHash = msgHashIfValidRequest(message, proof, nft.tokenAddr);

        address releasedToken = nft.tokenAddr;

        if (isBridgedToken[nft.tokenAddr]) {
            releasedToken = canonicalToBridged[nft.srcChainId][nft.tokenAddr];
        }

        IERC1155Upgradeable(releasedToken).safeTransferFrom(
            address(this), message.owner, tokenId, amount, ""
        );

        emit TokenReleased({
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
    )
        external
        pure
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    )
        external
        pure
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165)
        returns (bool)
    {
        return interfaceId == ERC1155_INTERFACE_ID
            || interfaceId == ERC1155_METADATA_INTERFACE_ID;
    }

    /**
     * @dev Decodes the data which was abi.encodeWithSelector() encoded. We need
     * this to get to know
     * to whom / which token and tokenId we shall release.
     */
    function decodeTokenData(bytes memory dataWithSelector)
        public
        pure
        returns (
            BaseNFTVault.CanonicalNFT memory,
            address,
            address,
            uint256,
            uint256
        )
    {
        bytes memory calldataWithoutSelector = extractCalldata(dataWithSelector);
        return abi.decode(
            calldataWithoutSelector,
            (BaseNFTVault.CanonicalNFT, address, address, uint256, uint256)
        );
    }

    /**
     *
     * Private functions *
     *
     */

    function _sendToken(
        address owner,
        address to,
        uint256 tokenId,
        address token,
        string memory tokenUri,
        uint256 amount,
        bool isBridgedToken,
        BaseNFTVault.CanonicalNFT memory bridgedToCanonical,
        bytes4 selector
    )
        private
        returns (bytes memory)
    {
        BaseNFTVault.CanonicalNFT memory canonicalToken;

        // is a bridged token, meaning, it does not live on this chain
        if (isBridgedToken) {
            if (BridgedERC1155(token).balanceOf(owner, tokenId) < amount) {
                revert VAULT_INVALID_OWNER();
            }

            BridgedERC1155(token).burn(owner, tokenId, amount);
            canonicalToken = bridgedToCanonical;
            if (canonicalToken.tokenAddr == address(0)) {
                revert VAULT_CANONICAL_TOKEN_NOT_FOUND();
            }
        } else {
            // is a canonical token, meaning, it lives on this chain
            ERC1155Upgradeable t = ERC1155Upgradeable(token);
            if (BridgedERC1155(token).balanceOf(owner, tokenId) < amount) {
                revert VAULT_INVALID_OWNER();
            }

            canonicalToken = BaseNFTVault.CanonicalNFT({
                srcChainId: block.chainid,
                tokenAddr: token,
                symbol: "",
                name: "",
                uri: tokenUri
            });

            t.safeTransferFrom(msg.sender, address(this), tokenId, amount, "");
        }

        return abi.encodeWithSelector(
            selector, canonicalToken, owner, to, tokenId, amount
        );
    }

    function _receiveToken(
        address addressManager,
        BaseNFTVault.CanonicalNFT memory canonicalToken,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        address canonicalToBridged
    )
        private
        returns (bool bridged, address token)
    {
        IBridge.Context memory ctx = _checkValidContext("erc1155_vault");

        if (canonicalToken.srcChainId == block.chainid) {
            token = canonicalToken.tokenAddr;
            bridged = false;
            ERC1155Upgradeable(token).safeTransferFrom(
                address(this), to, tokenId, amount, ""
            );
        } else {
            (bridged, token) = _getOrDeployBridgedToken(
                canonicalToken, canonicalToBridged, addressManager
            );
            BridgedERC1155(token).mint(to, tokenId, amount, "");
        }

        emit TokenReceived({
            msgHash: ctx.msgHash,
            from: from,
            to: to,
            srcChainId: ctx.srcChainId,
            token: token,
            tokenId: tokenId,
            amount: amount
        });
    }

    function _getOrDeployBridgedToken(
        BaseNFTVault.CanonicalNFT memory canonicalToken,
        address token,
        address addressManager
    )
        private
        returns (bool, address)
    {
        return token != address(0)
            ? (false, token)
            : _deployBridgedErc1155(canonicalToken, addressManager);
    }

    /**
     * @dev Deploys a new BridgedNFT contract and initializes it. This must be
     * called before the first time a bridged token is sent to this chain.
     */
    function _deployBridgedErc1155(
        BaseNFTVault.CanonicalNFT memory canonicalToken,
        address addressManager
    )
        private
        returns (bool, address bridgedToken)
    {
        bridgedToken = Create2Upgradeable.deploy(
            0, // amount of Ether to send
            keccak256(
                bytes.concat(
                    bytes32(canonicalToken.srcChainId),
                    bytes32(uint256(uint160(canonicalToken.tokenAddr)))
                )
            ),
            type(BridgedERC1155).creationCode
        );

        BridgedERC1155(payable(bridgedToken)).init({
            _addressManager: addressManager,
            _srcToken: canonicalToken.tokenAddr,
            _srcChainId: canonicalToken.srcChainId,
            _uri: canonicalToken.uri
        });

        emit BridgedTokenDeployed({
            srcChainId: canonicalToken.srcChainId,
            canonicalToken: canonicalToken.tokenAddr,
            bridgedToken: bridgedToken
        });

        return (true, bridgedToken);
    }
}

contract ProxiedERC1155Vault is Proxied, ERC1155Vault { }
