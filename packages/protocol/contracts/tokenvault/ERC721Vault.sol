// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { BaseNFTVault } from "./BaseNFTVault.sol";
import { Create2Upgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/Create2Upgradeable.sol";
import { ERC721Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { IERC165Upgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import { IERC721Receiver } from
    "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC721Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import { IBridge, IRecallableMessageSender } from "../bridge/IBridge.sol";
import { LibAddress } from "../libs/LibAddress.sol";
import { LibVaultUtils } from "./libs/LibVaultUtils.sol";
import { Proxied } from "../common/Proxied.sol";
import { ProxiedBridgedERC721 } from "./BridgedERC721.sol";

/// @title ERC721Vault
/// @notice This vault holds all ERC721 tokens that users have deposited.
/// It also manages the mapping between canonical tokens and their bridged
/// tokens.
contract ERC721Vault is BaseNFTVault, IERC721Receiver, IERC165Upgradeable {
    using LibAddress for address;

    uint256[50] private __gap;

    /// @notice Transfers ERC721 tokens to this vault and sends a message to the
    /// destination chain so the user can receive the same (bridged) tokens
    /// by invoking the message call.
    /// @param opt Option for sending the ERC721 token.
    function sendToken(BridgeTransferOp calldata opt)
        external
        payable
        nonReentrant
    {
        LibVaultUtils.checkIfValidAmounts(opt.amounts, opt.tokenIds, true);
        LibVaultUtils.checkIfValidAddresses(
            resolve(opt.destChainId, "erc721_vault", false), opt.to, opt.token
        );

        if (!opt.token.supportsInterface(ERC721_INTERFACE_ID)) {
            revert VAULT_INTERFACE_NOT_SUPPORTED();
        }

        // We need to save them into memory - because structs containing
        // dynamic arrays will cause stack-too-deep error when passed
        uint256[] memory _amounts = opt.amounts;
        address _token = opt.token;
        uint256[] memory _tokenIds = opt.tokenIds;

        IBridge.Message memory message;
        message.destChainId = opt.destChainId;
        message.data = _encodeDestinationCall(msg.sender, opt);
        message.user = msg.sender;
        message.to = resolve(message.destChainId, "erc721_vault", false);
        message.gasLimit = opt.gasLimit;
        message.value = msg.value - opt.fee;
        message.fee = opt.fee;
        message.refundTo = opt.refundTo;
        message.memo = opt.memo;

        bytes32 msgHash = IBridge(resolve("bridge", false)).sendMessage{
            value: msg.value
        }(message);

        emit TokenSent({
            msgHash: msgHash,
            from: message.user,
            to: opt.to,
            destChainId: message.destChainId,
            token: _token,
            tokenIds: _tokenIds,
            amounts: _amounts
        });
    }

    /// @notice Receive bridged ERC721 tokens and handle them accordingly.
    /// @param ctoken Canonical NFT data for the token being received.
    /// @param from Source address.
    /// @param to Destination address.
    /// @param tokenIds Array of token IDs being received.
    function receiveToken(
        CanonicalNFT calldata ctoken,
        address from,
        address to,
        uint256[] memory tokenIds
    )
        external
        payable
        nonReentrant
        onlyFromNamed("bridge")
    {
        IBridge.Context memory ctx =
            LibVaultUtils.checkValidContext("erc721_vault", address(this));
        address token;

        unchecked {
            if (ctoken.chainId == block.chainid) {
                token = ctoken.addr;
                for (uint256 i; i < tokenIds.length; ++i) {
                    ERC721Upgradeable(token).transferFrom({
                        from: address(this),
                        to: to,
                        tokenId: tokenIds[i]
                    });
                }
            } else {
                token = _getOrDeployBridgedToken(ctoken);
                for (uint256 i; i < tokenIds.length; ++i) {
                    ProxiedBridgedERC721(token).mint(to, tokenIds[i]);
                }
            }
        }

        to.sendEther(msg.value);

        emit TokenReceived({
            msgHash: ctx.msgHash,
            from: from,
            to: to,
            srcChainId: ctx.srcChainId,
            token: token,
            tokenIds: tokenIds,
            amounts: new uint256[](0)
        });
    }

    /// @notice Release deposited ERC721 token(s) back to the user on the source
    /// chain with a proof that the message processing on the destination Bridge
    /// has failed.
    /// @param message The message that corresponds to the ERC721 deposit on the
    /// source chain.
    function onMessageRecalled(IBridge.Message calldata message)
        external
        payable
        override
        nonReentrant
        onlyFromNamed("bridge")
    {
        if (message.user == address(0)) revert VAULT_INVALID_USER();
        if (message.srcChainId != block.chainid) {
            revert VAULT_INVALID_SRC_CHAIN_ID();
        }

        (
            CanonicalNFT memory nft, //
            ,
            ,
            uint256[] memory tokenIds
        ) = abi.decode(
            message.data[4:], (CanonicalNFT, address, address, uint256[])
        );

        bytes32 msgHash = LibVaultUtils.hashAndCheckToken(
            message, resolve("bridge", false), nft.addr
        );

        unchecked {
            if (isBridgedToken[nft.addr]) {
                for (uint256 i; i < tokenIds.length; ++i) {
                    ProxiedBridgedERC721(nft.addr).mint(
                        message.user, tokenIds[i]
                    );
                }
            } else {
                for (uint256 i; i < tokenIds.length; ++i) {
                    IERC721Upgradeable(nft.addr).safeTransferFrom({
                        from: address(this),
                        to: message.user,
                        tokenId: tokenIds[i]
                    });
                }
            }
        }

        // send back Ether
        message.user.sendEther(message.value);

        emit TokenReleased({
            msgHash: msgHash,
            from: message.user,
            token: nft.addr,
            tokenIds: tokenIds,
            amounts: new uint256[](0)
        });
    }

    /// @inheritdoc IERC721Receiver
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

    /// @inheritdoc IERC165Upgradeable
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return interfaceId == type(IRecallableMessageSender).interfaceId;
    }

    /// @dev Encodes sending bridged or canonical ERC721 tokens to the user.
    /// @param user The user's address.
    /// @param opt BridgeTransferOp data.
    /// @return msgData Encoded message data.
    function _encodeDestinationCall(
        address user,
        BridgeTransferOp calldata opt
    )
        private
        returns (bytes memory msgData)
    {
        CanonicalNFT memory nft;

        unchecked {
            if (isBridgedToken[opt.token]) {
                nft = bridgedToCanonical[opt.token];
                for (uint256 i; i < opt.tokenIds.length; ++i) {
                    ProxiedBridgedERC721(opt.token).burn(user, opt.tokenIds[i]);
                }
            } else {
                ERC721Upgradeable t = ERC721Upgradeable(opt.token);

                nft = CanonicalNFT({
                    chainId: block.chainid,
                    addr: opt.token,
                    symbol: t.symbol(),
                    name: t.name()
                });

                for (uint256 i; i < opt.tokenIds.length; ++i) {
                    t.transferFrom(user, address(this), opt.tokenIds[i]);
                }
            }
        }

        msgData = abi.encodeWithSelector(
            ERC721Vault.receiveToken.selector, nft, user, opt.to, opt.tokenIds
        );
    }

    /// @dev Retrieve or deploy a bridged ERC721 token contract.
    /// @param ctoken CanonicalNFT data.
    /// @return btoken Address of the bridged token contract.
    function _getOrDeployBridgedToken(CanonicalNFT calldata ctoken)
        private
        returns (address btoken)
    {
        btoken = canonicalToBridged[ctoken.chainId][ctoken.addr];

        if (btoken == address(0)) {
            btoken = _deployBridgedToken(ctoken);
        }
    }

    /// @dev Deploy a new BridgedNFT contract and initialize it.
    /// This must be called before the first time a bridged token is sent to
    /// this chain.
    /// @param ctoken CanonicalNFT data.
    /// @return btoken Address of the deployed bridged token contract.
    function _deployBridgedToken(CanonicalNFT memory ctoken)
        private
        returns (address btoken)
    {
        address bridgedToken = Create2Upgradeable.deploy({
            amount: 0, // amount of Ether to send
            salt: keccak256(abi.encode(ctoken)),
            bytecode: type(ProxiedBridgedERC721).creationCode
        });

        btoken = LibVaultUtils.deployProxy(
            address(bridgedToken),
            owner(),
            bytes.concat(
                ProxiedBridgedERC721(bridgedToken).init.selector,
                abi.encode(
                    address(_addressManager),
                    ctoken.addr,
                    ctoken.chainId,
                    ctoken.symbol,
                    ctoken.name
                )
            )
        );

        isBridgedToken[btoken] = true;
        bridgedToCanonical[btoken] = ctoken;
        canonicalToBridged[ctoken.chainId][ctoken.addr] = btoken;

        emit BridgedTokenDeployed({
            chainId: ctoken.chainId,
            ctoken: ctoken.addr,
            btoken: btoken,
            ctokenSymbol: ctoken.symbol,
            ctokenName: ctoken.name
        });
    }
}

/// @title ProxiedERC721Vault
/// @notice Proxied version of the parent contract.
contract ProxiedERC721Vault is Proxied, ERC721Vault { }
