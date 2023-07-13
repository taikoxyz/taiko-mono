// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { IERC721Receiver } from
    "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC721Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import { Create2Upgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/Create2Upgradeable.sol";
import { ERC721Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { IERC165 } from
    "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { AddressResolver } from "../common/AddressResolver.sol";
import { IBridge } from "../bridge/IBridge.sol";
import { BaseNFTVault } from "./BaseNFTVault.sol";
import { BridgedERC721 } from "./BridgedERC721.sol";
import { Proxied } from "../common/Proxied.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * This vault holds all ERC721 tokens that users have deposited.
 * It also manages the mapping between canonical ERC721 tokens and their bridged
 * tokens.
 */
contract ERC721Vault is BaseNFTVault, IERC721Receiver {
    bytes4 public constant ERC721_INTERFACE_ID = 0x80ac58cd;
    bytes4 public constant ERC721_METADATA_INTERFACE_ID = 0x5b5e139f;
    bytes4 public constant ERC721_ENUMERABLE_INTERFACE_ID = 0x780e9d63;

    event BridgedERC721Deployed(
        uint256 indexed srcChainId,
        address indexed canonicalToken,
        address indexed bridgedToken,
        string canonicalTokenSymbol,
        string canonicalTokenName
    );

    event ERC721Sent(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint256 destChainId,
        address token,
        uint256 tokenId
    );

    event ERC721Released(
        bytes32 indexed msgHash,
        address indexed from,
        address token,
        uint256 tokenId
    );

    event ERC721Received(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint256 srcChainId,
        address token,
        uint256 tokenId
    );

    /**
     * Transfers ERC721 tokens to this vault and sends a message to the
     * destination chain so the user can receive the same (bridged) tokens
     * by invoking the message call.
     *
     * @param opt Option for sending the ERC721 token.
     */
    function sendToken(BridgeTransferOp calldata opt)
        external
        payable
        nonReentrant
        onlyValidAddresses(opt.destChainId, "erc721_vault", opt.to, opt.token)
    {
        if (opt.amount != 1) revert VAULT_INVALID_AMOUNT();

        // TODO: we need to figure this out: && or ||?
        if (
            ERC721Upgradeable(opt.token).supportsInterface(ERC721_INTERFACE_ID)
                == false
                && ERC721Upgradeable(opt.token).supportsInterface(
                    ERC721_METADATA_INTERFACE_ID
                ) == false
                && ERC721Upgradeable(opt.token).supportsInterface(
                    ERC721_ENUMERABLE_INTERFACE_ID
                ) == false
        ) {
            revert VAULT_INTERFACE_NOT_SUPPORTED();
        }

        bytes memory data = _sendToken(
            msg.sender,
            opt.to,
            opt.tokenId,
            opt.token,
            opt.baseTokenUri,
            isBridgedToken[opt.token],
            bridgedToCanonical[opt.token],
            ERC721Vault.receiveToken.selector
        );

        IBridge.Message memory message;
        message.destChainId = opt.destChainId;
        message.owner = msg.sender;
        message.to = resolve(opt.destChainId, "erc721_vault", false);
        message.data = data;
        message.gasLimit = opt.gasLimit;
        message.processingFee = opt.processingFee;
        message.depositValue = 0;
        message.refundAddress = opt.refundAddress;
        message.memo = opt.memo;

        bytes32 msgHash = IBridge(resolve("bridge", false)).sendMessage{
            value: msg.value
        }(message);

        emit ERC721Sent({
            msgHash: msgHash,
            from: message.owner,
            to: opt.to,
            destChainId: opt.destChainId,
            token: opt.token,
            tokenId: opt.tokenId
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
        (nft, owner,, tokenId) = decodeTokenData(message.data);

        bytes32 msgHash = msgHashIfValidRequest(message, proof, nft.tokenAddr);

        address releasedToken = nft.tokenAddr;

        if (isBridgedToken[nft.tokenAddr]) {
            releasedToken = canonicalToBridged[nft.srcChainId][nft.tokenAddr];
        }

        IERC721Upgradeable(releasedToken).safeTransferFrom(
            address(this), message.owner, tokenId
        );

        emit ERC721Released({
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
    )
        external
        pure
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * @dev Decodes the data which was abi.encodeWithSelector() encoded. We need
     * this to get to know
     * to whom / which token and tokenId we shall release.
     */
    function decodeTokenData(bytes memory dataWithSelector)
        public
        pure
        returns (BaseNFTVault.CanonicalNFT memory, address, address, uint256)
    {
        bytes memory calldataWithoutSelector = extractCalldata(dataWithSelector);
        return abi.decode(
            calldataWithoutSelector,
            (BaseNFTVault.CanonicalNFT, address, address, uint256)
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
            if (BridgedERC721(token).ownerOf(tokenId) != msg.sender) {
                revert VAULT_INVALID_OWNER();
            }

            BridgedERC721(token).burn(msg.sender, tokenId);
            canonicalToken = bridgedToCanonical;
            if (canonicalToken.tokenAddr == address(0)) {
                revert VAULT_CANONICAL_TOKEN_NOT_FOUND();
            }
        } else {
            // is a canonical token, meaning, it lives on this chain
            ERC721Upgradeable t = ERC721Upgradeable(token);
            if (t.ownerOf(tokenId) != msg.sender) {
                revert VAULT_INVALID_OWNER();
            }

            canonicalToken = BaseNFTVault.CanonicalNFT({
                srcChainId: block.chainid,
                tokenAddr: token,
                symbol: t.symbol(),
                name: t.name(),
                uri: tokenUri
            });
            t.transferFrom(msg.sender, address(this), tokenId);
        }

        return
            abi.encodeWithSelector(selector, canonicalToken, owner, to, tokenId);
    }

    function _receiveToken(
        address addressManager,
        BaseNFTVault.CanonicalNFT memory canonicalToken,
        address from,
        address to,
        uint256 tokenId,
        address canonicalToBridged
    )
        private
        returns (bool bridged, address token)
    {
        IBridge.Context memory ctx = _checkValidContext("erc721_vault");

        if (canonicalToken.srcChainId == block.chainid) {
            token = canonicalToken.tokenAddr;
            bridged = false;
            ERC721Upgradeable(token).transferFrom(address(this), to, tokenId);
        } else {
            (bridged, token) = _getOrDeployBridgedToken(
                canonicalToken, canonicalToBridged, addressManager
            );
            BridgedERC721(token).mint(to, tokenId);
        }

        emit ERC721Received({
            msgHash: ctx.msgHash,
            from: from,
            to: to,
            srcChainId: ctx.srcChainId,
            token: token,
            tokenId: tokenId
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
            : _deployBridgedErc721(canonicalToken, addressManager);
    }

    /**
     * @dev Deploys a new BridgedNFT contract and initializes it. This must be
     * called before the first time a bridged token is sent to this chain.
     */
    function _deployBridgedErc721(
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
            type(BridgedERC721).creationCode
        );

        BridgedERC721(payable(bridgedToken)).init({
            _addressManager: addressManager,
            _srcToken: canonicalToken.tokenAddr,
            _srcChainId: canonicalToken.srcChainId,
            _symbol: ERC721Upgradeable(canonicalToken.tokenAddr).symbol(),
            _name: string.concat(
                ERC721Upgradeable(canonicalToken.tokenAddr).name(),
                unicode"(bridged🌈",
                Strings.toString(canonicalToken.srcChainId),
                ")"
                ),
            _uri: canonicalToken.uri
        });

        emit BridgedERC721Deployed({
            srcChainId: canonicalToken.srcChainId,
            canonicalToken: canonicalToken.tokenAddr,
            bridgedToken: bridgedToken,
            canonicalTokenSymbol: canonicalToken.symbol,
            canonicalTokenName: canonicalToken.name
        });

        return (true, bridgedToken);
    }
}

contract ProxiedERC721Vault is Proxied, ERC721Vault { }
