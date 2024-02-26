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

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "../bridge/IBridge.sol";
import "./BaseNFTVault.sol";
import "./BridgedERC721.sol";

/// @title ERC721Vault
/// @dev Labeled in AddressResolver as "erc721_vault"
/// @notice This vault holds all ERC721 tokens that users have deposited.
/// It also manages the mapping between canonical tokens and their bridged
/// tokens.
contract ERC721Vault is BaseNFTVault, IERC721ReceiverUpgradeable {
    using LibAddress for address;

    uint256[50] private __gap;

    /// @notice Transfers ERC721 tokens to this vault and sends a message to the
    /// destination chain so the user can receive the same (bridged) tokens
    /// by invoking the message call.
    /// @param op Option for sending the ERC721 token.
    function sendToken(BridgeTransferOp memory op)
        external
        payable
        nonReentrant
        whenNotPaused
        withValidOperation(op)
        returns (IBridge.Message memory _message)
    {
        for (uint256 i; i < op.tokenIds.length; ++i) {
            if (op.amounts[i] != 0) revert VAULT_INVALID_AMOUNT();
        }

        if (!op.token.supportsInterface(ERC721_INTERFACE_ID)) {
            revert VAULT_INTERFACE_NOT_SUPPORTED();
        }

        (bytes memory data, CanonicalNFT memory ctoken) = _handleMessage(msg.sender, op);

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

        bytes32 msgHash;
        (msgHash, _message) =
            IBridge(resolve("bridge", false)).sendMessage{ value: msg.value }(message);

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
        (CanonicalNFT memory ctoken, address from, address to, uint256[] memory tokenIds) =
            abi.decode(data, (CanonicalNFT, address, address, uint256[]));

        // `onlyFromBridge` checked in checkProcessMessageContext
        IBridge.Context memory ctx = checkProcessMessageContext();

        // Don't allow sending to disallowed addresses.
        // Don't send the tokens back to `from` because `from` is on the source chain.
        if (to == address(0) || to == address(this)) revert VAULT_INVALID_TO();

        // Transfer the ETH and the tokens to the `to` address
        address token = _transferTokens(ctoken, to, tokenIds);
        to.sendEther(msg.value);

        emit TokenReceived({
            msgHash: ctx.msgHash,
            from: from,
            to: to,
            srcChainId: ctx.srcChainId,
            ctoken: ctoken.addr,
            token: token,
            tokenIds: tokenIds,
            amounts: new uint256[](tokenIds.length)
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
        (CanonicalNFT memory ctoken,,, uint256[] memory tokenIds) =
            abi.decode(_data, (CanonicalNFT, address, address, uint256[]));

        // Transfer the ETH and tokens back to the owner
        address token = _transferTokens(ctoken, message.srcOwner, tokenIds);
        message.srcOwner.sendEther(message.value);

        emit TokenReleased({
            msgHash: msgHash,
            from: message.srcOwner,
            ctoken: ctoken.addr,
            token: token,
            tokenIds: tokenIds,
            amounts: new uint256[](tokenIds.length)
        });
    }

    /// @inheritdoc IERC721ReceiverUpgradeable
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
        return IERC721ReceiverUpgradeable.onERC721Received.selector;
    }

    function name() public pure override returns (bytes32) {
        return "erc721_vault";
    }

    function _transferTokens(
        CanonicalNFT memory ctoken,
        address to,
        uint256[] memory tokenIds
    )
        private
        returns (address token)
    {
        if (ctoken.chainId == block.chainid) {
            token = ctoken.addr;
            for (uint256 i; i < tokenIds.length; ++i) {
                ERC721Upgradeable(token).safeTransferFrom({
                    from: address(this),
                    to: to,
                    tokenId: tokenIds[i]
                });
            }
        } else {
            token = _getOrDeployBridgedToken(ctoken);
            for (uint256 i; i < tokenIds.length; ++i) {
                BridgedERC721(token).mint(to, tokenIds[i]);
            }
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
            if (bridgedToCanonical[op.token].addr != address(0)) {
                ctoken = bridgedToCanonical[op.token];
                for (uint256 i; i < op.tokenIds.length; ++i) {
                    BridgedERC721(op.token).burn(user, op.tokenIds[i]);
                }
            } else {
                ERC721Upgradeable t = ERC721Upgradeable(op.token);

                ctoken = CanonicalNFT({
                    chainId: uint64(block.chainid),
                    addr: op.token,
                    symbol: t.symbol(),
                    name: t.name()
                });

                for (uint256 i; i < op.tokenIds.length; ++i) {
                    t.safeTransferFrom(user, address(this), op.tokenIds[i]);
                }
            }
        }

        msgData =
            abi.encodeCall(this.onMessageInvocation, abi.encode(ctoken, user, op.to, op.tokenIds));
    }

    /// @dev Retrieve or deploy a bridged ERC721 token contract.
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
            BridgedERC721.init,
            (owner(), addressManager, ctoken.addr, ctoken.chainId, ctoken.symbol, ctoken.name)
        );

        btoken = LibDeploy.deployERC1967Proxy(resolve("bridged_erc721", false), owner(), data);

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
