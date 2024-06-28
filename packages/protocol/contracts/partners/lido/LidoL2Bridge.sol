// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Bridge} from "../../bridge/Bridge.sol";
import {IBridge} from "../../bridge/IBridge.sol";
import {ILidoL1Bridge} from "./ILidoL1Bridge.sol";
import {ILidoL2Bridge} from "./ILidoL2Bridge.sol";
import {BridgeableTokens} from "../../thirdparty/lido/BridgeableTokens.sol";
import {ILidoBridgedToken} from "./ILidoBridgedToken.sol";


contract LidoL2Bridge is Bridge, ILidoL2Bridge, BridgeableTokens {

    IBridge bridge;
    uint32 destChainId;
    address public lidoL1Bridge;
    ILidoBridgedToken bridgedToken;
    mapping(bytes32 => bool) failedMsgHashes;

    error Lido_notSelf();
    error Lido_notL1Bridge();
    error Lido_messageTampered();
    error Lido_messageNotFailed();
    error Lido_messageProcessingFailed();
    error Lido_failedMsgAlreadyProcessed();

    /**
     * @dev Modifier to restrict function access to only the contract itself
     */
    modifier onlySelf() {
        if (msg.sender != address(this)) revert Lido_notSelf();
        _;
    }

    /**
     * @dev Modifier to restrict function access to only the L1 bridge
     * @param bridge_ The address to be checked against the Lido L1 bridge address
     */
    modifier onlyL1Bridge(address bridge_) {
        if (bridge_ != lidoL1Bridge) revert Lido_notL1Bridge();
        _;
    }

    /**
     * @notice Initializes the LidoL2Bridge contract
     * @param bridge_ The address of the bridge contract
     * @param l1Token_ The address of the L1 token
     * @param l2Token_ The address of the L2 token
     * @param dstChainId_ The destination chain ID
     * @param bridgedToken_ The address of the bridged token contract
     * @param lidoL1TokenBridge_ The address of the Lido L1 bridge contract
     */
    constructor(
        address bridge_,
        address l1Token_,
        address l2Token_,
        uint32 dstChainId_,
        address bridgedToken_,
        address lidoL1TokenBridge_
    ) BridgeableTokens(l1Token_, l2Token_) {
        bridge = IBridge(bridge_);
        destChainId = dstChainId_;
        lidoL1Bridge = lidoL1TokenBridge_;
        bridgedToken = ILidoBridgedToken(bridgedToken_);
    }

    /**
     * @notice Initiates a withdrawal of tokens from the L2 bridge
     * @param amount_ The amount of tokens to withdraw
     * @param l1Gas_ The amount of gas to be used for the transaction on L1
     * @param data_ Additional data for the withdrawal
     */
    function withdraw(
        uint256 amount_,
        uint32 l1Gas_,
        bytes calldata data_
    )
    external
    payable
    {
        withdrawTo(msg.sender, amount_, l1Gas_, data_);
    }

    /**
     * @notice Receives and processes a message from the L1 bridge
     * @param _message The message received from the L1 bridge
     * @param _proof The proof of the message
     */
    function receiveMessage(
        IBridge.Message calldata _message,
        bytes calldata _proof
    )
    external
    {
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

        ILidoL2Bridge(address(this)).finalizeDeposit(_message.from, l1Token_, l2Token_, from_, to_, amount_, data_);
    }

    /**
     * @notice Handles a failed message
     * @param _message The failed message received
     */
    function handleFailMessage(
        IBridge.Message calldata _message
    ) external {
        bytes32 failedHash_ = bridge.hashMessage(_message);

        if (failedMsgHashes[failedHash_]) revert Lido_failedMsgAlreadyProcessed();
        if (bridge.messageStatus(bridge.hashMessage(_message)) != IBridge.Status.FAILED) revert Lido_messageNotFailed();

        failedMsgHashes[failedHash_] = true;
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
        ) revert Lido_messageTampered();

        bridgedToken.bridgeMint(from_, amount_);

        emit FailedMessageProcessed(l1Token, l2Token, from_, to_, amount_, data_);
    }

    /**
     * @notice Finalizes the deposit of tokens into the L2 bridge
     * @param fromBridge_ Address of calling bridge
     * @param l1Token_ The L1 token address
     * @param l2Token_ The L2 token address
     * @param from_ The address initiating the deposit
     * @param to_ The address receiving the deposited tokens
     * @param amount_ The amount of tokens deposited
     * @param data_ Additional data for the deposit
     */
    function finalizeDeposit(
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
    onlyL1Bridge(fromBridge_)
    onlyNonZeroAccount(from_)
    onlyNonZeroAccount(to_)
    onlySupportedL1Token(l1Token_)
    onlySupportedL2Token(l2Token_)
    {
        bridgedToken.bridgeMint(to_, amount_);
        emit DepositFinalized(l1Token_, l2Token_, from_, to_, amount_, data_);
    }

    /**
     * @notice Initiates a withdrawal of tokens to a specified address from the L2 bridge
     * @param to_ The address to receive the tokens on L1
     * @param amount_ The amount of tokens to withdraw
     * @param l1Gas_ The amount of gas to be used for the transaction on L1
     * @param data_ Additional data for the withdrawal
     */
    function withdrawTo(
        address to_,
        uint256 amount_,
        uint32 l1Gas_,
        bytes calldata data_
    )
    public
    payable
    {
        _initiateWithdrawal(msg.sender, to_, amount_, l1Gas_, msg.value, data_);
    }


    function _initiateWithdrawal(
        address from_,
        address to_,
        uint256 amount_,
        uint32 l1Gas_,
        uint256 fee_,
        bytes calldata data_
    ) internal {
        bridgedToken.bridgeBurn(from_, amount_);

        bytes memory message_ = abi.encodeWithSelector(
            ILidoL1Bridge.finalizeWithdrawal.selector,
            l1Token,
            l2Token,
            from_,
            to_,
            amount_,
            data_
        );

        IBridge.Message memory message = IBridge.Message({
            id: 0,
            from: address(this),
            srcChainId: uint64(block.chainid),
            destChainId: destChainId,
            srcOwner: from_,
            destOwner: to_,
            to: to_,
            value: 0,
            fee: uint64(fee_),
            gasLimit: l1Gas_,
            data: message_
        });
        bridge.sendMessage{value: fee_}(message);

        emit WithdrawalInitiated(l1Token, l2Token, from_, to_, amount_, data_);
    }

}
