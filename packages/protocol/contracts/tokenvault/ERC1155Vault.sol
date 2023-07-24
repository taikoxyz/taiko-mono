// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { IERC165 } from
    "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ERC1155ReceiverUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155ReceiverUpgradeable.sol";
import { IERC1155Receiver } from
    "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC1155Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import { ERC1155Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { Create2Upgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/Create2Upgradeable.sol";
import { IBridge } from "../bridge/IBridge.sol";
import { BaseNFTVault } from "./BaseNFTVault.sol";
import { ProxiedBridgedERC1155 } from "./BridgedERC1155.sol";
import { Proxied } from "../common/Proxied.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { LibVaultUtils } from "./libs/LibVaultUtils.sol";

/**
 * Some ERC1155 contracts implementing the name() and symbol()
 * functions, although they are not part of the interface
 */
interface ERC1155NameAndSymbol {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
}

/**
 * This vault holds all ERC1155 tokens that users have deposited.
 * It also manages the mapping between canonical tokens and their bridged
 * tokens.
 */
contract ERC1155Vault is BaseNFTVault, ERC1155ReceiverUpgradeable {
    uint256[50] private __gap;

    /**
     * Transfers ERC1155 tokens to this vault and sends a message to the
     * destination chain so the user can receive the same (bridged) tokens
     * by invoking the message call.
     *
     * @param opt Option for sending the ERC1155 token.
     */

    function sendToken(BridgeTransferOp memory opt)
        external
        payable
        nonReentrant
        onlyValidAddresses(opt.destChainId, "erc1155_vault", opt.to, opt.token)
        onlyValidAmounts(opt.amounts, opt.tokenIds, false)
    {
        if (
            !IERC165(opt.token).supportsInterface(ERC1155_INTERFACE_ID)
                || IERC165(opt.token).supportsInterface(ERC721_INTERFACE_ID)
        ) {
            revert VAULT_INTERFACE_NOT_SUPPORTED();
        }

        // We need to save them into memory - because structs containing
        // dynamic arrays will cause stack-too-deep error when passed to the
        // emited event
        uint256[] memory _amounts = opt.amounts;
        address _token = opt.token;
        uint256[] memory _tokenIds = opt.tokenIds;

        IBridge.Message memory message;
        message.destChainId = opt.destChainId;

        message.data = _sendToken(msg.sender, opt);
        message.owner = msg.sender;
        message.to = resolve(message.destChainId, "erc1155_vault", false);
        message.gasLimit = opt.gasLimit;
        message.processingFee = opt.processingFee;
        message.refundAddress = opt.refundAddress;
        message.memo = opt.memo;

        bytes32 msgHash = IBridge(resolve("bridge", false)).sendMessage{
            value: msg.value
        }(message);

        emit TokenSent({
            msgHash: msgHash,
            from: message.owner,
            to: opt.to,
            destChainId: message.destChainId,
            token: _token,
            tokenIds: _tokenIds,
            amounts: _amounts
        });
    }

    /**
     * @dev This function can only be called by the bridge contract while
     * invoking a message call. See sendToken, which sets the data to invoke
     * this function.
     * @param ctoken The canonical ERC1155 token which may or may not
     * live on this chain. If not, a BridgedERC1155 contract will be
     * deployed.
     * @param from The source address.
     * @param to The destination address.
     * @param tokenIds The tokenIds to be sent.
     * @param amounts The amounts to be sent.
     */
    function receiveToken(
        CanonicalNFT calldata ctoken,
        address from,
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    )
        external
        nonReentrant
        onlyFromNamed("bridge")
    {
        IBridge.Context memory ctx =
            LibVaultUtils.checkValidContext("erc1155_vault", address(this));
        address token;

        unchecked {
            if (ctoken.chainId == block.chainid) {
                token = ctoken.addr;
                for (uint256 i; i < tokenIds.length; ++i) {
                    ERC1155Upgradeable(token).safeTransferFrom({
                        from: address(this),
                        to: to,
                        id: tokenIds[i],
                        amount: amounts[i],
                        data: ""
                    });
                }
            } else {
                token = _getOrDeployBridgedToken(ctoken);
                for (uint256 i; i < tokenIds.length; ++i) {
                    ProxiedBridgedERC1155(token).mint(
                        to, tokenIds[i], amounts[i]
                    );
                }
            }
        }

        emit TokenReceived({
            msgHash: ctx.msgHash,
            from: from,
            to: to,
            srcChainId: ctx.srcChainId,
            token: token,
            tokenIds: tokenIds,
            amounts: amounts
        });
    }

    /**
     * Release deposited ERC1155 token(s) back to the owner on the source chain
     * with
     * a proof that the message processing on the destination Bridge has failed.
     *
     * @param message The message that corresponds to the ERC1155 deposit on the
     * source chain.
     * @param proof The proof from the destination chain to show the message has
     * failed.
     */
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

        (
            CanonicalNFT memory nft,
            ,
            ,
            uint256[] memory tokenIds,
            uint256[] memory amounts
        ) = abi.decode(
            message.data[4:],
            (CanonicalNFT, address, address, uint256[], uint256[])
        );

        bytes32 msgHash = hashAndMarkMsgReleased(message, proof, nft.addr);
        unchecked {
            if (isBridgedToken[nft.addr]) {
                for (uint256 i; i < tokenIds.length; ++i) {
                    ProxiedBridgedERC1155(nft.addr).mint(
                        message.owner, tokenIds[i], amounts[i]
                    );
                }
            } else {
                for (uint256 i; i < tokenIds.length; ++i) {
                    IERC1155Upgradeable(nft.addr).safeTransferFrom({
                        from: address(this),
                        to: message.owner,
                        id: tokenIds[i],
                        amount: amounts[i],
                        data: ""
                    });
                }
            }
        }

        emit TokenReleased({
            msgHash: msgHash,
            from: message.owner,
            token: nft.addr,
            tokenIds: tokenIds,
            amounts: amounts
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

    function _sendToken(
        address owner,
        BridgeTransferOp memory opt
    )
        private
        returns (bytes memory msgData)
    {
        CanonicalNFT memory nft;
        unchecked {
            // is a btoken, meaning, it does not live on this chain
            if (isBridgedToken[opt.token]) {
                nft = bridgedToCanonical[opt.token];
                for (uint256 i; i < opt.tokenIds.length; ++i) {
                    ProxiedBridgedERC1155(opt.token).burn(
                        owner, opt.tokenIds[i], opt.amounts[i]
                    );
                }
            } else {
                // is a ctoken token, meaning, it lives on this chain
                nft = CanonicalNFT({
                    chainId: block.chainid,
                    addr: opt.token,
                    symbol: "",
                    name: ""
                });

                ERC1155NameAndSymbol t = ERC1155NameAndSymbol(opt.token);
                try t.name() returns (string memory _name) {
                    nft.name = _name;
                } catch { }

                try t.symbol() returns (string memory _symbol) {
                    nft.symbol = _symbol;
                } catch { }

                for (uint256 i; i < opt.tokenIds.length; ++i) {
                    ERC1155Upgradeable(opt.token).safeTransferFrom({
                        from: msg.sender,
                        to: address(this),
                        id: opt.tokenIds[i],
                        amount: opt.amounts[i],
                        data: ""
                    });
                }
            }
        }

        msgData = abi.encodeWithSelector(
            ERC1155Vault.receiveToken.selector,
            nft,
            owner,
            opt.to,
            opt.tokenIds,
            opt.amounts
        );
    }

    /**
     * @dev Returns the contract address per given canonical token.
     */
    function _getOrDeployBridgedToken(CanonicalNFT memory ctoken)
        private
        returns (address btoken)
    {
        btoken = canonicalToBridged[ctoken.chainId][ctoken.addr];

        if (btoken == address(0)) {
            btoken = _deployBridgedToken(ctoken);
        }
    }

    /**
     * @dev Deploys a new BridgedNFT contract and initializes it. This must be
     * called before the first time a btoken is sent to this chain.
     */
    function _deployBridgedToken(CanonicalNFT memory ctoken)
        private
        returns (address btoken)
    {
        ProxiedBridgedERC1155 bridgedToken = new ProxiedBridgedERC1155();

        btoken = LibVaultUtils.deployProxy(
            address(bridgedToken),
            owner(),
            bytes.concat(
                bridgedToken.init.selector,
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

contract ProxiedERC1155Vault is Proxied, ERC1155Vault { }
