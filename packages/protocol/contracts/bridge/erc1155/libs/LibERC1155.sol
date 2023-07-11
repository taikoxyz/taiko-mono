// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {AddressResolver} from "../../../common/AddressResolver.sol";
import {
    Create2Upgradeable
} from "@openzeppelin/contracts-upgradeable/utils/Create2Upgradeable.sol";
import {
    ERC1155Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {NFTVaultParent} from "../../NFTVaultParent.sol";
import {BridgedERC1155} from "../BridgedERC1155.sol";
import {IBridge} from "../../IBridge.sol";
import {LibExtractCalldata} from "../../libs/LibExtractCalldata.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library LibERC1155 {
    /*********************
     * Events            *
     *********************/

    event BridgedERC1155Deployed(
        uint256 indexed srcChainId,
        address indexed canonicalToken,
        address indexed bridgedToken
    );

    event ERC1155Sent(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint256 destChainId,
        address token,
        uint256 tokenId,
        uint256 amount
    );

    event ERC1155Released(
        bytes32 indexed msgHash,
        address indexed from,
        address token,
        uint256 tokenId,
        uint256 amount
    );

    event ERC1155Received(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint256 srcChainId,
        address token,
        uint256 tokenId,
        uint256 amount
    );

    error NFTVAULT_CANONICAL_TOKEN_NOT_FOUND();
    error NFTVAULT_INVALID_OWNER();
    error NFTVAULT_INVALID_SENDER();

    function sendToken(
        address owner,
        address to,
        uint256 tokenId,
        address token,
        string memory tokenUri,
        uint256 amount,
        bool isBridgedToken,
        NFTVaultParent.CanonicalNFT memory bridgedToCanonical,
        bytes4 selector
    ) public returns (bytes memory) {
        NFTVaultParent.CanonicalNFT memory canonicalToken;

        // is a bridged token, meaning, it does not live on this chain
        if (isBridgedToken) {
            if (BridgedERC1155(token).balanceOf(owner, tokenId) < amount)
                revert NFTVAULT_INVALID_OWNER();

            BridgedERC1155(token).bridgeBurnFrom(owner, tokenId, amount);
            canonicalToken = bridgedToCanonical;
            if (canonicalToken.tokenAddr == address(0))
                revert NFTVAULT_CANONICAL_TOKEN_NOT_FOUND();
        } else {
            // is a canonical token, meaning, it lives on this chain
            ERC1155Upgradeable t = ERC1155Upgradeable(token);
            if (BridgedERC1155(token).balanceOf(owner, tokenId) < amount)
                revert NFTVAULT_INVALID_OWNER();

            canonicalToken = NFTVaultParent.CanonicalNFT({
                srcChainId: block.chainid,
                tokenAddr: token,
                symbol: "",
                name: "",
                uri: tokenUri
            });

            t.safeTransferFrom(msg.sender, address(this), tokenId, amount, "");
        }

        return
            abi.encodeWithSelector(
                selector,
                canonicalToken,
                owner,
                to,
                tokenId,
                amount
            );
    }

    function receiveToken(
        AddressResolver resolver,
        address addressManager,
        NFTVaultParent.CanonicalNFT memory canonicalToken,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        address canonicalToBridged
    ) public returns (bool bridged, address token) {
        IBridge.Context memory ctx = IBridge(msg.sender).context();
        if (ctx.sender != resolver.resolve(ctx.srcChainId, "erc1155_vault", false))
            revert NFTVAULT_INVALID_SENDER();

        if (canonicalToken.srcChainId == block.chainid) {
            token = canonicalToken.tokenAddr;
            bridged = false;
            ERC1155Upgradeable(token).safeTransferFrom(
                address(this),
                to,
                tokenId,
                amount,
                ""
            );
        } else {
            (bridged, token) = _getOrDeployBridgedToken(
                canonicalToken,
                canonicalToBridged,
                addressManager
            );
            BridgedERC1155(token).bridgeMintTo(to, tokenId, amount, "");
        }

        emit ERC1155Received({
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
                : _deployBridgedErc1155(canonicalToken, addressManager);
    }

    /**
     * @dev Decodes the data which was abi.encodeWithSelector() encoded. We need this to get to know
     * to whom / which token and tokenId we shall release.
     */
    function decodeTokenData(
        bytes memory dataWithSelector
    )
        public pure
        returns (NFTVaultParent.CanonicalNFT memory, address, address, uint256, uint256)
    {
        bytes memory calldataWithoutSelector = LibExtractCalldata.extractCalldata(dataWithSelector);
        return abi.decode(calldataWithoutSelector, (NFTVaultParent.CanonicalNFT, address, address, uint256, uint256));
    }

    /**
     * @dev Deploys a new BridgedNFT contract and initializes it. This must be
     * called before the first time a bridged token is sent to this chain.
     */
    function _deployBridgedErc1155(
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
            type(BridgedERC1155).creationCode
        );

        BridgedERC1155(payable(bridgedToken)).init({
            _addressManager: addressManager,
            _srcToken: canonicalToken.tokenAddr,
            _srcChainId: canonicalToken.srcChainId,
            _uri: canonicalToken.uri
        });

        emit BridgedERC1155Deployed({
            srcChainId: canonicalToken.srcChainId,
            canonicalToken: canonicalToken.tokenAddr,
            bridgedToken: bridgedToken
        });

        return (true, bridgedToken);
    }
}
