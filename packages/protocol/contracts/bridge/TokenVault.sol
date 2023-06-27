// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {
    IERC20Upgradeable,
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { Create2Upgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/Create2Upgradeable.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { Proxied } from "../common/Proxied.sol";
import { TaikoToken } from "../L1/TaikoToken.sol";
import { BridgedERC20 } from "./BridgedERC20.sol";
import { IBridge } from "./IBridge.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * This vault holds all ERC20 tokens (but not Ether) that users have deposited.
 * It also manages the mapping between canonical ERC20 tokens and their bridged
 * tokens.
 * @dev Ether is held by Bridges on L1 and by the EtherVault on L2, not
 * TokenVaults.
 * @custom:security-contact hello@taiko.xyz
 */
contract TokenVault is EssentialContract {
    using SafeERC20Upgradeable for ERC20Upgradeable;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct CanonicalERC20 {
        uint256 chainId;
        address addr;
        uint8 decimals;
        string symbol;
        string name;
    }

    struct MessageDeposit {
        address token;
        uint256 amount;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // Tracks if a token on the current chain is a canonical or bridged token.
    mapping(address tokenAddress => bool isBridged) public isBridgedToken;

    // Mappings from bridged tokens to their canonical tokens.
    mapping(address bridgedAddress => CanonicalERC20 canonicalErc20) public
        bridgedToCanonical;

    // Mappings from canonical tokens to their bridged tokens.
    // Also storing chainId for tokens across other chains aside from Ethereum.
    mapping(
        uint256 chainId
            => mapping(address canonicalAddress => address bridgedAddress)
    ) public canonicalToBridged;

    // Tracks the token and amount associated with a message hash.
    mapping(bytes32 msgHash => MessageDeposit messageDeposit) public
        messageDeposits;

    uint256[47] private __gap;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event BridgedERC20Deployed(
        uint256 indexed srcChainId,
        address indexed canonicalToken,
        address indexed bridgedToken,
        string canonicalTokenSymbol,
        string canonicalTokenName,
        uint8 canonicalTokenDecimal
    );

    event EtherSent(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint256 destChainId,
        uint256 amount
    );

    event ERC20Sent(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint256 destChainId,
        address token,
        uint256 amount
    );

    event ERC20Released(
        bytes32 indexed msgHash,
        address indexed from,
        address token,
        uint256 amount
    );

    event ERC20Received(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint256 srcChainId,
        address token,
        uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                             CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * Thrown when the `to` address in an operation is invalid.
     * This can happen if it's zero address or the address of the token vault.
     */
    error TOKENVAULT_INVALID_TO();

    /**
     * Thrown when the value in a transaction is invalid.
     * The value can be an Ether amount or the amount of a token being
     * transferred.
     */
    error TOKENVAULT_INVALID_VALUE();

    /**
     * Thrown when the token address in a transaction is invalid.
     * This could happen if the token address is zero or doesn't conform to the
     * ERC20 standard.
     */
    error TOKENVAULT_INVALID_TOKEN();

    /**
     * Thrown when the amount in a transaction is invalid.
     * This could happen if the amount is zero or exceeds the sender's balance.
     */
    error TOKENVAULT_INVALID_AMOUNT();

    /**
     * Thrown when a canonical token address could not be found for a bridged
     * token.
     * This could happen when trying to send a bridged token back to its
     * original chain.
     */
    error TOKENVAULT_CANONICAL_TOKEN_NOT_FOUND();

    /**
     * Thrown when the owner address in a message is invalid.
     * This could happen if the owner address is zero or doesn't match the
     * expected owner.
     */
    error TOKENVAULT_INVALID_OWNER();

    /**
     * Thrown when the source chain ID in a message is invalid.
     * This could happen if the source chain ID doesn't match the current
     * chain's ID.
     */
    error TOKENVAULT_INVALID_SRC_CHAIN_ID();

    /**
     * Thrown when a message has not failed.
     * This could happen if trying to release a message deposit without proof of
     * failure.
     */
    error TOKENVAULT_MESSAGE_NOT_FAILED();

    /**
     * Thrown when the sender in a message context is invalid.
     * This could happen if the sender isn't the expected token vault on the
     * source chain.
     */
    error TOKENVAULT_INVALID_SENDER();

    /*//////////////////////////////////////////////////////////////
                         USER-FACING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function init(address addressManager) external initializer {
        EssentialContract._init(addressManager);
    }

    /**
     * Transfers ERC20 tokens to this vault and sends a message to the
     * destination chain so the user can receive the same amount of tokens
     * by invoking the message call.
     *
     * @param destChainId Chain ID of the destination chain
     * @param to Address of the receiver
     * @param token The address of the token to be sent.
     * @param amount The amount of token to be transferred.
     * @param gasLimit Gas limit for the transaction
     * @param processingFee Processing fee for the transaction
     * @param refundAddress Address for refunds
     * @param memo Any additional data or notes
     */
    function sendERC20(
        uint256 destChainId,
        address to,
        address token,
        uint256 amount,
        uint256 gasLimit,
        uint256 processingFee,
        address refundAddress,
        string memory memo
    )
        external
        payable
        nonReentrant
    {
        if (
            to == address(0) || to == resolve(destChainId, "token_vault", false)
        ) {
            revert TOKENVAULT_INVALID_TO();
        }

        if (token == address(0)) revert TOKENVAULT_INVALID_TOKEN();

        if (amount == 0) revert TOKENVAULT_INVALID_AMOUNT();

        CanonicalERC20 memory canonicalToken;
        uint256 _amount;

        // is a bridged token, meaning, it does not live on this chain
        if (isBridgedToken[token]) {
            BridgedERC20(token).bridgeBurnFrom(msg.sender, amount);
            canonicalToken = bridgedToCanonical[token];
            if (canonicalToken.addr == address(0)) {
                revert TOKENVAULT_CANONICAL_TOKEN_NOT_FOUND();
            }
            _amount = amount;
        } else {
            // is a canonical token, meaning, it lives on this chain
            ERC20Upgradeable t = ERC20Upgradeable(token);
            canonicalToken = CanonicalERC20({
                chainId: block.chainid,
                addr: token,
                decimals: t.decimals(),
                symbol: t.symbol(),
                name: t.name()
            });

            uint256 _balance = t.balanceOf(address(this));
            t.safeTransferFrom(msg.sender, address(this), amount);
            _amount = t.balanceOf(address(this)) - _balance;
        }

        IBridge.Message memory message;
        message.destChainId = destChainId;
        message.owner = msg.sender;
        message.to = resolve(destChainId, "token_vault", false);
        message.data = abi.encodeWithSelector(
            TokenVault.receiveERC20.selector,
            canonicalToken,
            message.owner,
            to,
            _amount
        );
        message.gasLimit = gasLimit;
        message.processingFee = processingFee;
        message.depositValue = msg.value - processingFee;
        message.refundAddress = refundAddress;
        message.memo = memo;

        bytes32 msgHash = IBridge(resolve("bridge", false)).sendMessage{
            value: msg.value
        }(message);

        // record the deposit for this message
        messageDeposits[msgHash] = MessageDeposit(token, _amount);

        emit ERC20Sent({
            msgHash: msgHash,
            from: message.owner,
            to: to,
            destChainId: destChainId,
            token: token,
            amount: _amount
        });
    }

    /**
     * Release deposited ERC20 back to the owner on the source TokenVault with
     * a proof that the message processing on the destination Bridge has failed.
     *
     * @param message The message that corresponds to the ERC20 deposit on the
     * source chain.
     * @param proof The proof from the destination chain to show the message has
     * failed.
     */
    function releaseERC20(
        IBridge.Message calldata message,
        bytes calldata proof
    )
        external
        nonReentrant
    {
        if (message.owner == address(0)) revert TOKENVAULT_INVALID_OWNER();
        if (message.srcChainId != block.chainid) {
            revert TOKENVAULT_INVALID_SRC_CHAIN_ID();
        }

        IBridge bridge = IBridge(resolve("bridge", false));
        bytes32 msgHash = bridge.hashMessage(message);

        address token = messageDeposits[msgHash].token;
        uint256 amount = messageDeposits[msgHash].amount;
        if (token == address(0)) revert TOKENVAULT_INVALID_TOKEN();

        if (!bridge.isMessageFailed(msgHash, message.destChainId, proof)) {
            revert TOKENVAULT_MESSAGE_NOT_FAILED();
        }
        messageDeposits[msgHash] = MessageDeposit(address(0), 0);

        if (amount > 0) {
            if (isBridgedToken[token]) {
                BridgedERC20(token).bridgeMintTo(message.owner, amount);
            } else {
                ERC20Upgradeable(token).safeTransfer(message.owner, amount);
            }
        }

        emit ERC20Released({
            msgHash: msgHash,
            from: message.owner,
            token: token,
            amount: amount
        });
    }

    /**
     * This function can only be called by the bridge contract while
     * invoking a message call. See sendERC20, which sets the data to invoke
     * this function.
     *
     * @param canonicalToken The canonical ERC20 token which may or may not
     * live on this chain. If not, a BridgedERC20 contract will be deployed.
     * @param from The source address.
     * @param to The destination address.
     * @param amount The amount of tokens to be sent. 0 is a valid value.
     */
    function receiveERC20(
        CanonicalERC20 calldata canonicalToken,
        address from,
        address to,
        uint256 amount
    )
        external
        nonReentrant
        onlyFromNamed("bridge")
    {
        IBridge.Context memory ctx = IBridge(msg.sender).context();
        if (ctx.sender != resolve(ctx.srcChainId, "token_vault", false)) {
            revert TOKENVAULT_INVALID_SENDER();
        }

        address token;
        if (canonicalToken.chainId == block.chainid) {
            token = canonicalToken.addr;
            ERC20Upgradeable(token).safeTransfer(to, amount);
        } else {
            token = _getOrDeployBridgedToken(canonicalToken);
            BridgedERC20(token).bridgeMintTo(to, amount);
        }

        emit ERC20Received({
            msgHash: ctx.msgHash,
            from: from,
            to: to,
            srcChainId: ctx.srcChainId,
            token: token,
            amount: amount
        });
    }

    /*//////////////////////////////////////////////////////////////
                           PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * Internal function to get or deploy bridged token
     * @param canonicalToken Canonical token information
     * @return token Address of the deployed bridged token
     */
    function _getOrDeployBridgedToken(CanonicalERC20 calldata canonicalToken)
        private
        returns (address)
    {
        address token =
            canonicalToBridged[canonicalToken.chainId][canonicalToken.addr];

        return token != address(0) ? token : _deployBridgedToken(canonicalToken);
    }

    /**
     * Internal function to deploy a new BridgedERC20 contract and initializes
     * it.
     * This must be called before the first time a bridged token is sent to this
     * chain.
     * @param canonicalToken Canonical token information
     * @return bridgedToken Address of the newly deployed bridged token
     */
    function _deployBridgedToken(CanonicalERC20 calldata canonicalToken)
        private
        returns (address bridgedToken)
    {
        bridgedToken = Create2Upgradeable.deploy(
            0, // amount of Ether to send
            keccak256(
                bytes.concat(
                    bytes32(canonicalToken.chainId),
                    bytes32(uint256(uint160(canonicalToken.addr)))
                )
            ),
            type(BridgedERC20).creationCode
        );

        BridgedERC20(payable(bridgedToken)).init({
            _addressManager: address(_addressManager),
            _srcToken: canonicalToken.addr,
            _srcChainId: canonicalToken.chainId,
            _decimals: canonicalToken.decimals,
            _symbol: canonicalToken.symbol,
            _name: string.concat(
                canonicalToken.name,
                unicode"(bridged🌈",
                Strings.toString(canonicalToken.chainId),
                ")"
                )
        });

        isBridgedToken[bridgedToken] = true;
        bridgedToCanonical[bridgedToken] = canonicalToken;
        canonicalToBridged[canonicalToken.chainId][canonicalToken.addr] =
            bridgedToken;

        emit BridgedERC20Deployed({
            srcChainId: canonicalToken.chainId,
            canonicalToken: canonicalToken.addr,
            bridgedToken: bridgedToken,
            canonicalTokenSymbol: canonicalToken.symbol,
            canonicalTokenName: canonicalToken.name,
            canonicalTokenDecimal: canonicalToken.decimals
        });
    }
}

contract ProxiedTokenVault is Proxied, TokenVault { }
