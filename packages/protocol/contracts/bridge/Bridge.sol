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

pragma solidity 0.8.20;

import "../common/EssentialContract.sol";
import "../libs/LibAddress.sol";
import "../signal/ISignalService.sol";
import "./IBridge.sol";

/// @title Bridge
/// @dev Labeled in AddressResolver as "bridge"
/// @notice See the documentation for {IBridge}.
/// @dev The code hash for the same address on L1 and L2 may be different.
contract Bridge is EssentialContract, IBridge {
    using LibAddress for address;
    using LibAddress for address payable;

    enum Status {
        NEW,
        RETRIABLE,
        DONE,
        FAILED,
        RECALLED
    }

    uint256 internal constant PLACEHOLDER = type(uint256).max;

    uint128 public nextMessageId; // slot 1
    mapping(bytes32 msgHash => bool recalled) private __deprecated__isMessageRecalled;
    mapping(bytes32 msgHash => Status) public messageStatus; // slot 3
    Context private _ctx; // // slot 4,5,6
    mapping(bytes32 msgHash => uint64) public messageReceivedAt;
    uint256[43] private __gap;

    event SignalSent(address indexed sender, bytes32 msgHash);
    event MessageSent(bytes32 indexed msgHash, Message message);
    event MessageReceived(bytes32 indexed msgHash, Message message, bool isRecall);
    event MessageRecalled(bytes32 indexed msgHash);
    event MessageExecuted(bytes32 indexed msgHash);
    event DestChainEnabled(uint64 indexed chainId, bool enabled);
    event MessageStatusChanged(bytes32 indexed msgHash, Status status);

    error B_INVALID_CHAINID();
    error B_INVALID_CONTEXT();
    error B_INVALID_GAS_LIMIT();
    error B_INVALID_USER();
    error B_INVALID_VALUE();
    error B_MESSAGE_NOT_SENT();
    error B_NON_RETRIABLE();
    error B_NOT_FAILED();
    error B_NOT_RECEIVED();
    error B_PERMISSION_DENIED();
    error B_RECALLED_ALREADY();
    error B_STATUS_MISMATCH();
    error B_TOO_EARLY();

    modifier sameChain(uint64 chainId) {
        if (chainId != block.chainid) revert B_INVALID_CHAINID();
        _;
    }

    receive() external payable { }

    /// @notice Initializes the contract.
    /// @param _addressManager The address of the {AddressManager} contract.
    function init(address _addressManager) external initializer {
        __Essential_init(_addressManager);
        _ctx.msgHash == bytes32(PLACEHOLDER);
    }

    /// @notice Sends a message to the destination chain and takes custody
    /// of Ether required in this contract. All extra Ether will be refunded.
    /// @inheritdoc IBridge
    function sendMessage(Message calldata message)
        external
        payable
        override
        nonReentrant
        whenNotPaused
        returns (bytes32 msgHash, Message memory _message)
    {
        // Ensure the message user is not null.
        if (message.owner == address(0)) revert B_INVALID_USER();

        // Check if the destination chain is enabled.
        (bool destChainEnabled,) = isDestChainEnabled(message.destChainId);

        // Verify destination chain and to address.
        if (!destChainEnabled) revert B_INVALID_CHAINID();
        if (message.destChainId == block.chainid) {
            revert B_INVALID_CHAINID();
        }

        // Ensure the sent value matches the expected amount.
        uint256 expectedAmount = message.value + message.fee;
        if (expectedAmount != msg.value) revert B_INVALID_VALUE();

        _message = message;
        // Configure message details and send signal to indicate message
        // sending.
        _message.id = nextMessageId++;
        _message.from = msg.sender;
        _message.srcChainId = uint64(block.chainid);

        msgHash = hashMessage(_message);

        ISignalService(resolve("signal_service", false)).sendSignal(msgHash);
        emit MessageSent(msgHash, _message);
    }

    /// @notice Recalls a failed message on its source chain, releasing
    /// associated assets.
    /// @dev This function checks if the message failed on the source chain and
    /// releases associated Ether or tokens.
    /// @param message The message whose associated Ether should be released.
    /// @param proof The merkle inclusion proof.
    function recallMessage(
        Message calldata message,
        bytes calldata proof
    )
        external
        nonReentrant
        whenNotPaused
        sameChain(message.srcChainId)
    {
        bytes32 msgHash = hashMessage(message);
        bytes32 failureSignal = _signalForFailedMessage(msgHash);
        if (messageStatus[failureSignal] != Status.NEW) revert B_RECALLED_ALREADY();

        bool isMessageNew = messageReceivedAt[failureSignal] == 0;
        if (isMessageNew) {
            ISignalService signalService = ISignalService(resolve("signal_service", false));

            if (!signalService.isSignalSent(address(this), msgHash)) {
                revert B_MESSAGE_NOT_SENT();
            }

            if (!_proveSignalReceived(signalService, failureSignal, message.destChainId, proof)) {
                revert B_NOT_FAILED();
            }

            messageReceivedAt[failureSignal] = uint64(block.timestamp);
        }

        if (block.timestamp >= messageReceivedAt[failureSignal] + getMessageExecutionDelay()) {
            delete messageReceivedAt[failureSignal];
            messageStatus[failureSignal] = Status.RECALLED;

            // Execute the recall logic based on the contract's support for the
            // IRecallableSender interface
            if (message.from.supportsInterface(type(IRecallableSender).interfaceId)) {
                _ctx = Context({
                    msgHash: msgHash,
                    from: address(this),
                    srcChainId: message.srcChainId
                });

                // Perform recall
                IRecallableSender(message.from).onMessageRecalled{ value: message.value }(
                    message, msgHash
                );

                // Reset the context after the message call
                _ctx = Context({
                    msgHash: bytes32(PLACEHOLDER),
                    from: address(uint160(PLACEHOLDER)),
                    srcChainId: uint64(PLACEHOLDER)
                });
            } else {
                message.owner.sendEther(message.value);
            }
            emit MessageRecalled(msgHash);
        } else if (isMessageNew) {
            emit MessageReceived(msgHash, message, true);
        } else {
            revert B_TOO_EARLY();
        }
    }

    /// @notice Processes a bridge message on the destination chain. This
    /// function is callable by any address, including the `message.owner`.
    /// @dev The process begins by hashing the message and checking the message
    /// status in the bridge  If the status is "NEW", the message is invoked. The
    /// status is updated accordingly, and processing fees are refunded as
    /// needed.
    /// @param message The message to be processed.
    /// @param proof The merkle inclusion proof.
    function processMessage(
        Message calldata message,
        bytes calldata proof
    )
        external
        nonReentrant
        whenNotPaused
        sameChain(message.destChainId)
    {
        bytes32 msgHash = hashMessage(message);
        if (messageStatus[msgHash] != Status.NEW) revert B_STATUS_MISMATCH();

        ISignalService signalService = ISignalService(resolve("signal_service", false));
        bool isMessageNew = messageReceivedAt[msgHash] == 0;

        if (isMessageNew) {
            if (!_proveSignalReceived(signalService, msgHash, message.srcChainId, proof)) {
                revert B_NOT_RECEIVED();
            }
            messageReceivedAt[msgHash] = uint64(block.timestamp);
        }

        if (block.timestamp >= messageReceivedAt[msgHash] + getMessageExecutionDelay()) {
            // If the gas limit is set to zero, only the owner can process the
            // message.
            if (message.gasLimit == 0 && msg.sender != message.owner) {
                revert B_PERMISSION_DENIED();
            }

            delete messageReceivedAt[msgHash];

            Status status;
            uint256 refundAmount;

            // Process message differently based on the target address
            if (
                message.to == address(0) || message.to == address(this)
                    || message.to == address(signalService)
            ) {
                // Handle special addresses that don't require actual invocation but
                // mark message as DONE
                status = Status.DONE;
                refundAmount = message.value;
            } else {
                // Use the specified message gas limit if called by the owner, else
                // use remaining gas
                uint256 gasLimit = msg.sender == message.owner ? gasleft() : message.gasLimit;

                if (_invokeMessageCall(message, msgHash, gasLimit)) {
                    status = Status.DONE;
                } else {
                    status = Status.RETRIABLE;
                }
            }

            // Update the message status
            _updateMessageStatus(signalService, msgHash, status);

            // Determine the refund recipient
            address refundTo = message.refundTo == address(0) ? message.owner : message.refundTo;

            // Refund the processing fee
            if (msg.sender == refundTo) {
                refundTo.sendEther(message.fee + refundAmount);
            } else {
                // If sender is another address, reward it and refund the rest
                msg.sender.sendEther(message.fee);
                refundTo.sendEther(refundAmount);
            }
            emit MessageExecuted(msgHash);
        } else if (isMessageNew) {
            emit MessageReceived(msgHash, message, false);
        } else {
            revert B_TOO_EARLY();
        }
    }

    /// @notice Retries to invoke the messageCall after releasing associated
    /// Ether and tokens.
    /// @dev This function can be called by any address, including the
    /// `message.owner`.
    /// It attempts to invoke the messageCall and updates the message status
    /// accordingly.
    /// @param message The message to retry.
    /// @param isLastAttempt Specifies if this is the last attempt to retry the
    /// message.
    function retryMessage(
        Message calldata message,
        bool isLastAttempt
    )
        external
        nonReentrant
        whenNotPaused
        sameChain(message.destChainId)
    {
        // If the gasLimit is set to 0 or isLastAttempt is true, the caller must
        // be the message.owner.
        if (message.gasLimit == 0 || isLastAttempt) {
            if (msg.sender != message.owner) revert B_PERMISSION_DENIED();
        }

        bytes32 msgHash = hashMessage(message);
        if (messageStatus[msgHash] != Status.RETRIABLE) {
            revert B_NON_RETRIABLE();
        }

        // Attempt to invoke the messageCall.
        if (_invokeMessageCall(message, msgHash, gasleft())) {
            // Update the message status to "DONE" on successful invocation.
            _updateMessageStatus(
                ISignalService(resolve("signal_service", false)), msgHash, Status.DONE
            );
        } else if (isLastAttempt) {
            // Update the message status to "FAILED"
            _updateMessageStatus(
                ISignalService(resolve("signal_service", false)), msgHash, Status.FAILED
            );
        }
    }

    /// @notice Checks if the message was sent.
    /// @param message The message.
    /// @return True if the message was sent.
    function isMessageSent(Message calldata message) public view returns (bool) {
        if (message.srcChainId != block.chainid) return false;
        return ISignalService(resolve("signal_service", false)).isSignalSent({
            app: address(this),
            signal: hashMessage(message)
        });
    }

    /// @notice Checks if a msgHash has failed on its destination chain.
    /// @param message The message.
    /// @param proof The merkle inclusion proof.
    /// @return Returns true if the message has failed, false otherwise.
    function proveMessageFailed(
        Message calldata message,
        bytes calldata proof
    )
        public
        view
        returns (bool)
    {
        if (message.srcChainId != block.chainid) return false;

        return _proveSignalReceived(
            ISignalService(resolve("signal_service", false)),
            _signalForFailedMessage(hashMessage(message)),
            message.destChainId,
            proof
        );
    }

    /// @notice Checks if a msgHash has failed on its destination chain.
    /// @param message The message.
    /// @param proof The merkle inclusion proof.
    /// @return Returns true if the message has failed, false otherwise.
    function proveMessageReceived(
        Message calldata message,
        bytes calldata proof
    )
        public
        view
        returns (bool)
    {
        if (message.destChainId != block.chainid) return false;
        return _proveSignalReceived(
            ISignalService(resolve("signal_service", false)),
            hashMessage(message),
            message.srcChainId,
            proof
        );
    }

    /// @notice Checks if the destination chain is enabled.
    /// @param chainId The destination chain ID.
    /// @return enabled True if the destination chain is enabled.
    /// @return destBridge The bridge of the destination chain.
    function isDestChainEnabled(uint64 chainId)
        public
        view
        returns (bool enabled, address destBridge)
    {
        destBridge = resolve(chainId, "bridge", true);
        enabled = destBridge != address(0);
    }

    /// @notice Gets the current context.
    /// @inheritdoc IBridge
    function context() public view returns (Context memory) {
        if (_ctx.msgHash == bytes32(PLACEHOLDER) || _ctx.msgHash == 0) {
            revert B_INVALID_CONTEXT();
        }
        return _ctx;
    }

    function getMessageExecutionDelay() public view virtual returns (uint64) {
        return 0;
    }

    /// @notice Hash the message
    function hashMessage(Message memory message) public pure returns (bytes32) {
        return keccak256(abi.encode("TAIKO_MESSAGE", message));
    }

    /// @notice Invokes a call message on the Bridge.
    /// @param message The call message to be invoked.
    /// @param msgHash The hash of the message.
    /// @param gasLimit The gas limit for the message call.
    /// @return success A boolean value indicating whether the message call was
    /// successful.
    /// @dev This function updates the context in the state before and after the
    /// message call.
    function _invokeMessageCall(
        Message calldata message,
        bytes32 msgHash,
        uint256 gasLimit
    )
        private
        returns (bool success)
    {
        if (gasLimit == 0) revert B_INVALID_GAS_LIMIT();
        assert(message.from != address(this));

        _ctx = Context({ msgHash: msgHash, from: message.from, srcChainId: message.srcChainId });

        // Perform the message call and capture the success value
        (success,) = message.to.call{ value: message.value, gas: gasLimit }(message.data);

        // Reset the context after the message call
        _ctx = Context({
            msgHash: bytes32(PLACEHOLDER),
            from: address(uint160(PLACEHOLDER)),
            srcChainId: uint64(PLACEHOLDER)
        });
    }

    /// @notice Updates the status of a bridge message.
    /// @dev If the new status is different from the current status in the
    /// mapping, the status is updated and an event is emitted.
    /// @param msgHash The hash of the message.
    /// @param status The new status of the message.
    function _updateMessageStatus(
        ISignalService signalService,
        bytes32 msgHash,
        Status status
    )
        private
    {
        if (messageStatus[msgHash] == status) return;

        messageStatus[msgHash] = status;
        emit MessageStatusChanged(msgHash, status);

        if (status == Status.FAILED) {
            signalService.sendSignal(_signalForFailedMessage(msgHash));
        }
    }

    /// @notice Checks if the signal was received.
    /// @param signalService The signalService
    /// @param signal The signal.
    /// @param srcChainId The ID of the source chain.
    /// @param proof The merkle inclusion proof.
    /// @return True if the message was received.
    function _proveSignalReceived(
        ISignalService signalService,
        bytes32 signal,
        uint64 srcChainId,
        bytes calldata proof
    )
        private
        view
        returns (bool)
    {
        return signalService.proveSignalReceived({
            srcChainId: srcChainId,
            app: resolve(srcChainId, "bridge", false),
            signal: signal,
            proof: proof
        });
    }

    function _signalForFailedMessage(bytes32 msgHash) private pure returns (bytes32) {
        return msgHash ^ bytes32(uint256(Status.FAILED));
    }
}
