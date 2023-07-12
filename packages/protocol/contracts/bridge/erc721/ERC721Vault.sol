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
    Create2Upgradeable
} from "@openzeppelin/contracts-upgradeable/utils/Create2Upgradeable.sol";
import {
    ERC721Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {
    IERC165
} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {AddressResolver} from "../../common/AddressResolver.sol";
import {EssentialContract} from "../../common/EssentialContract.sol";
import {IBridge} from "../IBridge.sol";
import {LibExtractCalldata} from "../libs/LibExtractCalldata.sol";
import {NFTVaultParent} from "../NFTVaultParent.sol";
import {BridgedERC721} from "./BridgedERC721.sol";
import {Proxied} from "../../common/Proxied.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

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
    /*********************
     * Events            *
     *********************/

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

    function init(address addressManager) external initializer {
        EssentialContract._init(addressManager);
    }

    /**
     * Transfers ERC721 tokens to this vault and sends a message to the
     * destination chain so the user can receive the same (bridged) tokens
     * by invoking the message call.
     *
     * @param opt Option for sending the ERC721/ERC1155 token.
     */
    function sendToken(BridgeTransferOp calldata opt) external payable nonReentrant {
        if (
            opt.to == address(0) ||
            opt.to == resolve(opt.destChainId, "erc721_vault", false)
        ) revert NFTVAULT_INVALID_TO();

        if (opt.token == address(0)) revert NFTVAULT_INVALID_TOKEN();

        if (opt.amount != 1) revert NFTVAULT_INVALID_AMOUNT();

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
    ) external nonReentrant onlyFromNamed("bridge") {
        address bridgedAddress = canonicalToBridged[canonicalToken.srcChainId][canonicalToken.tokenAddr];
        (
            bool bridged,
            address bridgedToken
        ) = _receiveToken(
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
            decodeTokenData(message.data);

        bytes32 msgHash = msgHashIfValidRequest(message, proof, nft.tokenAddr);

        address releasedToken = nft.tokenAddr;

        if (isBridgedToken[nft.tokenAddr])
        {
            releasedToken = canonicalToBridged[nft.srcChainId][nft.tokenAddr];
        }

        IERC721Upgradeable(releasedToken).safeTransferFrom(address(this), message.owner, tokenId);

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
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * @dev Decodes the data which was abi.encodeWithSelector() encoded. We need this to get to know
     * to whom / which token and tokenId we shall release.
     */
    function decodeTokenData(
        bytes memory dataWithSelector
    )
        public pure
        returns (NFTVaultParent.CanonicalNFT memory, address, address, uint256)
    {
        bytes memory calldataWithoutSelector = LibExtractCalldata.extractCalldata(dataWithSelector);
        return abi.decode(calldataWithoutSelector, (NFTVaultParent.CanonicalNFT, address, address, uint256));
    }

    /*********************
     * Private functions *
     *********************/

    function _sendToken(
        address owner,
        address to,
        uint256 tokenId,
        address token,
        string memory tokenUri,
        bool isBridgedToken,
        NFTVaultParent.CanonicalNFT memory bridgedToCanonical,
        bytes4 selector
    ) private returns (bytes memory) {
        NFTVaultParent.CanonicalNFT memory canonicalToken;

        // is a bridged token, meaning, it does not live on this chain
        if (isBridgedToken) {
            if (BridgedERC721(token).ownerOf(tokenId) != msg.sender)
                revert NFTVAULT_INVALID_OWNER();

            BridgedERC721(token).bridgeBurnFrom(msg.sender, tokenId);
            canonicalToken = bridgedToCanonical;
            if (canonicalToken.tokenAddr == address(0))
                revert NFTVAULT_CANONICAL_TOKEN_NOT_FOUND();
        } else {
            // is a canonical token, meaning, it lives on this chain
            ERC721Upgradeable t = ERC721Upgradeable(token);
            if (t.ownerOf(tokenId) != msg.sender)
                revert NFTVAULT_INVALID_OWNER();

            canonicalToken = NFTVaultParent.CanonicalNFT({
                srcChainId: block.chainid,
                tokenAddr: token,
                symbol: t.symbol(),
                name: t.name(),
                uri: tokenUri
            });
            t.transferFrom(msg.sender, address(this), tokenId);
        }

        return
            abi.encodeWithSelector(
                selector,
                canonicalToken,
                owner,
                to,
                tokenId
            );
    }

    function _receiveToken(
        address addressManager,
        NFTVaultParent.CanonicalNFT memory canonicalToken,
        address from,
        address to,
        uint256 tokenId,
        address canonicalToBridged
    ) private returns (bool bridged, address token) {
        IBridge.Context memory ctx = checkValidContext("erc721_vault");

        if (canonicalToken.srcChainId == block.chainid) {
            token = canonicalToken.tokenAddr;
            bridged = false;
            ERC721Upgradeable(token).transferFrom(address(this), to, tokenId);
        } else {
            (bridged, token) = _getOrDeployBridgedToken(
                canonicalToken,
                canonicalToBridged,
                addressManager
            );
            BridgedERC721(token).bridgeMintTo(to, tokenId);
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
        NFTVaultParent.CanonicalNFT memory canonicalToken,
        address token,
        address addressManager
    )
        private
        returns (bool, address)
    {
        return
            token != address(0)
                ? (false, token)
                : _deployBridgedErc721(canonicalToken, addressManager);
    }


    /**
     * @dev Deploys a new BridgedNFT contract and initializes it. This must be
     * called before the first time a bridged token is sent to this chain.
     */
    function _deployBridgedErc721(
        NFTVaultParent.CanonicalNFT memory canonicalToken,
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