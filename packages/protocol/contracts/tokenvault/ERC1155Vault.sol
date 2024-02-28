// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155ReceiverUpgradeable.sol";
import "../bridge/IBridge.sol";
import "./BaseNFTVault.sol";
import "./BridgedERC1155.sol";

/// @title IERC1155NameAndSymbol
/// @notice Interface for ERC1155 contracts that provide name() and symbol()
/// functions. These functions may not be part of the official interface but are
/// used by some contracts.
interface IERC1155NameAndSymbol {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
}

/// @title ERC1155Vault
/// @dev Labeled in AddressResolver as "erc1155_vault"
/// @notice This vault holds all ERC1155 tokens that users have deposited.
/// It also manages the mapping between canonical tokens and their bridged
/// tokens.
contract ERC1155Vault is BaseNFTVault, ERC1155ReceiverUpgradeable {
    using LibAddress for address;

    uint256[50] private __gap;

    /// @notice Transfers ERC1155 tokens to this vault and sends a message to
    /// the destination chain so the user can receive the same (bridged) tokens
    /// by invoking the message call.
    /// @param op Option for sending the ERC1155 token.
    /// @return _message The constructed message.
    function sendToken(BridgeTransferOp memory op)
        external
        payable
        nonReentrant
        whenNotPaused
        withValidOperation(op)
        returns (IBridge.Message memory _message)
    {
        for (uint256 i; i < op.amounts.length; ++i) {
            if (op.amounts[i] == 0) revert VAULT_INVALID_AMOUNT();
        }
        // Check token interface support
        if (!op.token.supportsInterface(ERC1155_INTERFACE_ID)) {
            revert VAULT_INTERFACE_NOT_SUPPORTED();
        }

        (bytes memory data, CanonicalNFT memory ctoken) = _handleMessage(msg.sender, op);

        // Create a message to send to the destination chain
        IBridge.Message memory message;
        message.destChainId = op.destChainId;
        message.data = data;
        message.srcOwner = msg.sender;
        message.destOwner = op.destOwner != address(0) ? op.destOwner : msg.sender;
        message.to = resolve(message.destChainId, name(), false);
        message.gasLimit = op.gasLimit;
        message.value = msg.value - op.fee;
        message.fee = op.fee;
        message.refundTo = op.refundTo;
        message.memo = op.memo;

        // Send the message and obtain the message hash
        bytes32 msgHash;
        (msgHash, _message) =
            IBridge(resolve("bridge", false)).sendMessage{ value: msg.value }(message);

        // Emit TokenSent event
        emit TokenSent({
            msgHash: msgHash,
            from: _message.srcOwner,
            to: op.to,
            destChainId: _message.destChainId,
            ctoken: ctoken.addr,
            token: op.token,
            tokenIds: op.tokenIds,
            amounts: op.amounts
        });
    }

    /// @inheritdoc IMessageInvocable
    function onMessageInvocation(bytes calldata data) external payable nonReentrant whenNotPaused 
    // onlyFromBridge
    {
        (
            CanonicalNFT memory ctoken,
            address from,
            address to,
            uint256[] memory tokenIds,
            uint256[] memory amounts
        ) = abi.decode(data, (CanonicalNFT, address, address, uint256[], uint256[]));

        // Check context validity
        // `onlyFromBridge` checked in checkProcessMessageContext
        IBridge.Context memory ctx = checkProcessMessageContext();

        // Don't allow sending to disallowed addresses.
        // Don't send the tokens back to `from` because `from` is on the source chain.
        if (to == address(0) || to == address(this)) revert VAULT_INVALID_TO();

        // Transfer the ETH and the tokens to the `to` address
        address token = _transferTokens(ctoken, to, tokenIds, amounts);
        to.sendEther(msg.value);

        emit TokenReceived({
            msgHash: ctx.msgHash,
            from: from,
            to: to,
            srcChainId: ctx.srcChainId,
            ctoken: ctoken.addr,
            token: token,
            tokenIds: tokenIds,
            amounts: amounts
        });
    }

    /// @inheritdoc IRecallableSender
    function onMessageRecalled(
        IBridge.Message calldata message,
        bytes32 msgHash
    )
        external
        payable
        override
        nonReentrant
        whenNotPaused
    // onlyFromBridge
    {
        // `onlyFromBridge` checked in checkRecallMessageContext
        checkRecallMessageContext();

        (bytes memory _data) = abi.decode(message.data[4:], (bytes));
        (CanonicalNFT memory ctoken,,, uint256[] memory tokenIds, uint256[] memory amounts) =
            abi.decode(_data, (CanonicalNFT, address, address, uint256[], uint256[]));

        // Transfer the ETH and tokens back to the owner
        address token = _transferTokens(ctoken, message.srcOwner, tokenIds, amounts);
        message.srcOwner.sendEther(message.value);

        // Emit TokenReleased event
        emit TokenReleased({
            msgHash: msgHash,
            from: message.srcOwner,
            ctoken: ctoken.addr,
            token: token,
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
        return IERC1155ReceiverUpgradeable.onERC1155BatchReceived.selector;
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
        return IERC1155ReceiverUpgradeable.onERC1155Received.selector;
    }

    /// @dev See {BaseVault-supportsInterface}.
    /// @param interfaceId The interface identifier.
    /// @return bool True if supports, else otherwise.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(BaseVault, ERC1155ReceiverUpgradeable)
        returns (bool)
    {
        return interfaceId == type(ERC1155ReceiverUpgradeable).interfaceId
            || BaseVault.supportsInterface(interfaceId);
    }

    function name() public pure override returns (bytes32) {
        return "erc1155_vault";
    }

    function _transferTokens(
        CanonicalNFT memory ctoken,
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    )
        private
        returns (address token)
    {
        if (ctoken.chainId == block.chainid) {
            // Token lives on this chain
            token = ctoken.addr;
            IERC1155(token).safeBatchTransferFrom(address(this), to, tokenIds, amounts, "");
        } else {
            // Token does not live on this chain
            token = _getOrDeployBridgedToken(ctoken);
            BridgedERC1155(token).mintBatch(to, tokenIds, amounts);
        }
    }

    /// @dev Handles the message on the source chain and returns the encoded
    /// call on the destination call.
    /// @param user The user's address.
    /// @param op BridgeTransferOp data.
    /// @return msgData Encoded message data.
    /// @return ctoken The canonical token.
    function _handleMessage(
        address user,
        BridgeTransferOp memory op
    )
        private
        returns (bytes memory msgData, CanonicalNFT memory ctoken)
    {
        unchecked {
            // is a btoken, meaning, it does not live on this chain
            if (bridgedToCanonical[op.token].addr != address(0)) {
                ctoken = bridgedToCanonical[op.token];
                for (uint256 i; i < op.tokenIds.length; ++i) {
                    BridgedERC1155(op.token).burn(user, op.tokenIds[i], op.amounts[i]);
                }
            } else {
                // is a ctoken token, meaning, it lives on this chain
                ctoken = CanonicalNFT({
                    chainId: uint64(block.chainid),
                    addr: op.token,
                    symbol: "",
                    name: ""
                });
                IERC1155NameAndSymbol t = IERC1155NameAndSymbol(op.token);
                try t.name() returns (string memory _name) {
                    ctoken.name = _name;
                } catch { }
                try t.symbol() returns (string memory _symbol) {
                    ctoken.symbol = _symbol;
                } catch { }
                for (uint256 i; i < op.tokenIds.length; ++i) {
                    IERC1155(op.token).safeTransferFrom({
                        from: msg.sender,
                        to: address(this),
                        id: op.tokenIds[i],
                        amount: op.amounts[i],
                        data: ""
                    });
                }
            }
        }
        msgData = abi.encodeCall(
            this.onMessageInvocation, abi.encode(ctoken, user, op.to, op.tokenIds, op.amounts)
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
    function _deployBridgedToken(CanonicalNFT memory ctoken) private returns (address btoken) {
        bytes memory data = abi.encodeCall(
            BridgedERC1155.init,
            (owner(), addressManager, ctoken.addr, ctoken.chainId, ctoken.symbol, ctoken.name)
        );

        btoken = address(new ERC1967Proxy(resolve("bridged_erc1155", false), data));

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
