// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { Create2Upgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/Create2Upgradeable.sol";
import { ERC1155ReceiverUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155ReceiverUpgradeable.sol";
import { ERC1155Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { IERC1155Receiver } from
    "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC1155Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import { IERC165Upgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import { IRecallableMessageSender, IBridge } from "../bridge/IBridge.sol";
import { BaseNFTVault } from "./BaseNFTVault.sol";
import { LibAddress } from "../libs/LibAddress.sol";
import { LibVaultUtils } from "./libs/LibVaultUtils.sol";
import { Proxied } from "../common/Proxied.sol";
import { ProxiedBridgedERC1155 } from "./BridgedERC1155.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/// @title ERC1155NameAndSymbol
/// @notice Interface for ERC1155 contracts that provide name() and symbol()
/// functions. These functions may not be part of the official interface but are
/// used by
/// some contracts.
interface ERC1155NameAndSymbol {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
}

/// @title ERC1155Vault
/// @notice This vault holds all ERC1155 tokens that users have deposited.
/// It also manages the mapping between canonical tokens and their bridged
/// tokens.
contract ERC1155Vault is BaseNFTVault, ERC1155ReceiverUpgradeable {
    using LibAddress for address;

    uint256[50] private __gap;

    /// @notice Transfers ERC1155 tokens to this vault and sends a message to
    /// the destination chain so the user can receive the same (bridged) tokens
    /// by invoking the message call.
    /// @param opt Option for sending the ERC1155 token.
    function sendToken(BridgeTransferOp memory opt)
        external
        payable
        nonReentrant
    {
        // Validate amounts and addresses
        LibVaultUtils.checkIfValidAmounts(opt.amounts, opt.tokenIds, false);
        LibVaultUtils.checkIfValidAddresses(
            resolve(opt.destChainId, "erc1155_vault", false), opt.to, opt.token
        );

        // Check token interface support
        if (!opt.token.supportsInterface(ERC1155_INTERFACE_ID)) {
            revert VAULT_INTERFACE_NOT_SUPPORTED();
        }

        // Store variables in memory to avoid stack-too-deep error
        uint256[] memory _amounts = opt.amounts;
        address _token = opt.token;
        uint256[] memory _tokenIds = opt.tokenIds;

        // Create a message to send to the destination chain
        IBridge.Message memory message;
        message.destChainId = opt.destChainId;
        message.data = _encodeDestinationCall(msg.sender, opt);
        message.user = msg.sender;
        message.to = resolve(message.destChainId, "erc1155_vault", false);
        message.gasLimit = opt.gasLimit;
        message.value = msg.value - opt.fee;
        message.fee = opt.fee;
        message.refundTo = opt.refundTo;
        message.memo = opt.memo;

        // Send the message and obtain the message hash
        bytes32 msgHash = IBridge(resolve("bridge", false)).sendMessage{
            value: msg.value
        }(message);

        // Emit TokenSent event
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

    /// @notice This function can only be called by the bridge contract while
    /// invoking a message call. See sendToken, which sets the data to invoke
    /// this function.
    /// @param ctoken The canonical ERC1155 token which may or may not live on
    /// this chain. If not, a BridgedERC1155 contract will be deployed.
    /// @param from The source address.
    /// @param to The destination address.
    /// @param tokenIds The tokenIds to be sent.
    /// @param amounts The amounts to be sent.
    function receiveToken(
        CanonicalNFT calldata ctoken,
        address from,
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    )
        external
        payable
        nonReentrant
        onlyFromNamed("bridge")
    {
        // Check context validity
        IBridge.Context memory ctx =
            LibVaultUtils.checkValidContext("erc1155_vault", address(this));
        address token;

        unchecked {
            if (ctoken.chainId == block.chainid) {
                // Token lives on this chain
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
                // Token does not live on this chain
                token = _getOrDeployBridgedToken(ctoken);
                for (uint256 i; i < tokenIds.length; ++i) {
                    ProxiedBridgedERC1155(token).mint(
                        to, tokenIds[i], amounts[i]
                    );
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
            amounts: amounts
        });
    }

    /// @notice Releases deposited ERC1155 token(s) back to the user on the
    /// source chain with a proof that the message processing on the destination
    /// Bridge has failed.
    /// @param message The message that corresponds to the ERC1155 deposit on
    /// the source chain.
    function onMessageRecalled(IBridge.Message calldata message)
        external
        payable
        override
        nonReentrant
        onlyFromNamed("bridge")
    {
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

        bytes32 msgHash = LibVaultUtils.hashAndCheckToken(
            message, resolve("bridge", false), nft.addr
        );

        unchecked {
            if (isBridgedToken[nft.addr]) {
                for (uint256 i; i < tokenIds.length; ++i) {
                    ProxiedBridgedERC1155(nft.addr).mint(
                        message.user, tokenIds[i], amounts[i]
                    );
                }
            } else {
                for (uint256 i; i < tokenIds.length; ++i) {
                    IERC1155Upgradeable(nft.addr).safeTransferFrom({
                        from: address(this),
                        to: message.user,
                        id: tokenIds[i],
                        amount: amounts[i],
                        data: ""
                    });
                }
            }
        }
        // Send back Ether
        message.user.sendEther(message.value);
        // Emit TokenReleased event
        emit TokenReleased({
            msgHash: msgHash,
            from: message.user,
            token: nft.addr,
            tokenIds: tokenIds,
            amounts: amounts
        });
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

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155ReceiverUpgradeable)
        returns (bool)
    {
        return interfaceId == type(ERC1155ReceiverUpgradeable).interfaceId
            || interfaceId == type(IRecallableMessageSender).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// @dev Encodes sending bridged or canonical ERC1155 tokens to the user.
    /// @param user The user's address.
    /// @param opt BridgeTransferOp data.
    /// @return msgData Encoded message data.
    function _encodeDestinationCall(
        address user,
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
                        user, opt.tokenIds[i], opt.amounts[i]
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
            user,
            opt.to,
            opt.tokenIds,
            opt.amounts
        );
    }

    /// @dev Retrieve or deploy a bridged ERC1155 token contract.
    /// @param ctoken CanonicalNFT data.
    /// @return btoken Address of the bridged token contract.
    function _getOrDeployBridgedToken(CanonicalNFT memory ctoken)
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
            bytecode: type(ProxiedBridgedERC1155).creationCode
        });

        btoken = LibVaultUtils.deployProxy(
            address(bridgedToken),
            owner(),
            bytes.concat(
                ProxiedBridgedERC1155(bridgedToken).init.selector,
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

/// @title ProxiedERC1155Vault
/// @notice Proxied version of the parent contract.
contract ProxiedERC1155Vault is Proxied, ERC1155Vault { }
