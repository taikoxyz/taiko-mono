// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Bridge} from "../../bridge/Bridge.sol";
import {IBridge} from "../../bridge/IBridge.sol";
import {ILidoL1Bridge} from "./ILidoL1Bridge.sol";
import {ILidoL2Bridge} from "./ILidoL2Bridge.sol";
import {BridgeableTokens} from "../../thirdparty/lido/BridgeableTokens.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title LidoL1Bridge
 * @dev Implementation of the Lido L1 Bridge, extending the ILidoL1Bridge interface and BridgeableTokens contract
 */
contract LidoL1Bridge is ILidoL1Bridge, BridgeableTokens {
    using SafeERC20 for IERC20;

    IBridge bridge;
    uint32 destChainId;
    address public lidoL2Bridge;
    mapping(bytes32 => bool) failedMsgHases;

    error Lido_notSelf();
    error Lido_notL2Bridge();
    error Lido_messageTampered();
    error Lido_messageNotFailed();
    error Lido_messageProcessingFailed();
    error Lido_incorrectFundsTransferred();
    error Lido_failedMsgAlreadyProcessed();

    /**
     * @dev Modifier to restrict function access to only the contract itself
     */
    modifier onlySelf() {
        if (msg.sender != address(this)) revert Lido_notSelf();
        _;
    }

    /**
     * @dev Modifier to restrict function access to only the L2 bridge
     * @param bridge_ The address to be checked against the Lido L2 bridge address
     */
    modifier onlyL2Bridge(address bridge_) {
        if (bridge_ != lidoL2Bridge) revert Lido_notL2Bridge();
        _;
    }

    /**
    * @dev Modifier to ensure correct transfer of L1 tokens before and after a function call.
    * @param isTo Boolean indicating whether tokens are being transferred to (`true`) or from (`false`) the contract.
    * @param amount_ The amount of tokens being transferred.
    */
    modifier transferL1Tokens(bool isTo, uint256 amount_) {

        uint256 before_balance = IERC20(l1Token).balanceOf(address(this));
        _;

        uint256 after_balance = IERC20(l1Token).balanceOf(address(this));

        // To handle Fee-on-Transafer and other misc tokens
        if (isTo) {
            if (before_balance - after_balance != amount_) revert Lido_incorrectFundsTransferred();
        } else {
            if (after_balance - before_balance != amount_) revert Lido_incorrectFundsTransferred();
        }
    }

    /**
     * @notice Initializes the LidoL1Bridge contract
     * @param l1Token_ The address of the L1 token
     * @param l2Token_ The address of the L2 token
     * @param bridge_ The address of the bridge contract
     * @param dstChainId_ The destination chain ID
     * @param lidoL2TokenBridge_ The address of the Lido L2 bridge
     */
    constructor(
        address l1Token_,
        address l2Token_,
        address bridge_,
        uint32 dstChainId_,
        address lidoL2TokenBridge_
    ) BridgeableTokens(l1Token_, l2Token_) {
        bridge = IBridge(bridge_);
        destChainId = dstChainId_;
        lidoL2Bridge = lidoL2TokenBridge_;
    }

    /**
     * @notice Sends Deposit request to the L2 bridge
     * @param amount_ The amount of tokens to deposit
     * @param l2Gas_ The amount of gas to be used for the transaction on L2
     * @param data_ Additional data for the deposit
     */
    function deposit(
        uint256 amount_,
        uint32 l2Gas_,
        bytes calldata data_
    )
    external
    payable
    {
        depositTo(msg.sender, amount_,l2Gas_, data_);
    }

    /**
     * @notice Receives and processes a message from the L2 bridge
     * @param _message The message received from the L2 bridge
     * @param _proof The proof of the message
     */
    function receiveMessage(IBridge.Message calldata _message, bytes calldata _proof) external {
        bridge.processMessage(_message, _proof);

        if (bridge.messageStatus(bridge.hashMessage(_message)) != IBridge.Status.DONE) revert Lido_messageProcessingFailed();

        (
            address l1Token_,
            address l2Token_,
            address from_,
            address to_,
            uint256 amount_,
            bytes memory data_
        ) = abi.decode(_message.data, (address, address, address, address, uint256, bytes));

        ILidoL1Bridge(address(this)).finalizeWithdrawal(_message.from, l1Token_, l2Token_, from_, to_, amount_, data_);
    }

    /**
     * @notice Handles a failed message
     * @param _message The failed message
     * @param amount_to_receive The amount of tokens to be received as compensation
     */
    function handleFailMessage(
        IBridge.Message calldata _message,
        uint256 amount_to_receive
    )
    external
    transferL1Tokens(true, amount_to_receive)
    {
        bytes32 failedHash_ = bridge.hashMessage(_message);

        if (failedMsgHases[failedHash_]) revert Lido_failedMsgAlreadyProcessed();
        if (bridge.messageStatus(bridge.hashMessage(_message)) != IBridge.Status.FAILED) revert Lido_messageNotFailed();

        failedMsgHases[failedHash_] = true;
        (
            address l1Token_,
            address l2Token_,
            address from_,
            address to_,
            uint256 amount_,
            bytes memory data_
        ) = abi.decode(_message.data, (address, address, address, address, uint256, bytes));

        if (
            l1Token_ != l1Token
            || l2Token_ != l2Token
            || amount_to_receive != amount_
        ) revert Lido_messageTampered();

        IERC20(l1Token).safeTransfer(from_, amount_); // Transfer to User

        emit FailedMessageProcessed(l1Token, l2Token, from_, to_, amount_, data_);
    }

    /**
     * @notice Finalizes the withdrawal of tokens from the L2 bridge
     * @param fromBridge_ Address of calling bridge
     * @param l1Token_ The L1 token address
     * @param l2Token_ The L2 token address
     * @param from_ The address initiating the withdrawal
     * @param to_ The address receiving the withdrawn tokens
     * @param amount_ The amount of tokens to withdraw
     * @param data_ Additional data for the withdrawal
     */
    function finalizeWithdrawal(
        address fromBridge_,
        address l1Token_,
        address l2Token_,
        address from_,
        address to_,
        uint256 amount_,
        bytes calldata data_
    )
    external
    onlySelf
    onlyL2Bridge(fromBridge_)
    onlyNonZeroAccount(to_)
    onlyNonZeroAccount(from_)
    transferL1Tokens(true, amount_)
    onlySupportedL1Token(l1Token_)
    onlySupportedL2Token(l2Token_)
    {
        IERC20(l1Token).safeTransfer(to_, amount_); // Transfer to User
        emit TokenWithdrawalFinalized(l1Token_, from_, to_, amount_, data_);
    }

    /**
     * @notice Sends Deposit request to L2 bridge for a specified address
     * @param to_ The address to receive the tokens on L2
     * @param amount_ The amount of tokens to deposit
     * @param l2Gas_ The amount of gas to be used for the transaction on L2
     * @param data_ Additional data for the deposit
     */
    function depositTo(
        address to_,
        uint256 amount_,
        uint32 l2Gas_,
        bytes calldata data_
    )
    public
    payable
    transferL1Tokens(false, amount_)
    onlyNonZeroAccount(to_)
    {
        _initiateTokenDeposit(msg.sender, to_, amount_, l2Gas_, msg.value, data_);
    }

    function _initiateTokenDeposit(
        address from_,
        address to_,
        uint256 amount_,
        uint32 l2Gas_,
        uint256 fee_,
        bytes calldata data_
    )
    internal
    {
        IERC20(l1Token).safeTransferFrom(from_, address(this), amount_); // Transfer From user.

        bytes memory message_ = abi.encodeWithSelector(
            ILidoL2Bridge.finalizeDeposit.selector, l1Token, l2Token, from_, to_, amount_, data_
        );

        // Sends Cross Domain Message

        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: address(this),
            srcChainId: uint64(block.chainid),
            destChainId: destChainId,
            srcOwner: msg.sender,
            destOwner: to_,
            to: to_,
            value: 0,
            fee: uint64(fee_),
            gasLimit: l2Gas_,
            data: message_
        });
        bridge.sendMessage{value: fee_}(message);

        emit TokenDepositInitiated(l1Token, l2Token, from_, to_, amount_, data_);
    }

}
