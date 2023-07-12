// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";
import {AddressResolver} from "../../../common/AddressResolver.sol";
import {
    Create2Upgradeable
} from "@openzeppelin/contracts-upgradeable/utils/Create2Upgradeable.sol";
import {
    ERC721Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {NFTVaultParent} from "../../NFTVaultParent.sol";
import {BridgedERC721} from "../BridgedERC721.sol";
import {IBridge} from "../../IBridge.sol";
import {LibExtractCalldata} from "../../libs/LibExtractCalldata.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library LibERC721 {
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

    error NFTVAULT_CANONICAL_TOKEN_NOT_FOUND();
    error NFTVAULT_INVALID_OWNER();
    error NFTVAULT_INVALID_SENDER();
    error NFTVAULT_INVALID_SRC_CHAIN_ID();
    error NFTVAULT_INVALID_TOKEN();
    error NFTVAULT_MESSAGE_NOT_FAILED();

    function sendToken(
        address owner,
        address to,
        uint256 tokenId,
        address token,
        string memory tokenUri,
        bool isBridgedToken,
        NFTVaultParent.CanonicalNFT memory bridgedToCanonical,
        bytes4 selector
    ) public returns (bytes memory) {
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

    function receiveToken(
        AddressResolver resolver,
        address addressManager,
        NFTVaultParent.CanonicalNFT memory canonicalToken,
        address from,
        address to,
        uint256 tokenId,
        address canonicalToBridged
    ) public returns (bool bridged, address token) {
        IBridge.Context memory ctx = IBridge(msg.sender).context();
        if (ctx.sender != resolver.resolve(ctx.srcChainId, "erc721_vault", false))
            revert NFTVAULT_INVALID_SENDER();

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
