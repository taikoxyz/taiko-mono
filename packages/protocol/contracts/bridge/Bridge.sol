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

    // Note that this struct shall take only 1 slot to minimize gas cost
    struct ProofReceipt {
        // The time a message is marked as received on the destination chain
        uint64 receivedAt;
        // The address that can execute the message after the invocation delay without an extra
        // delay.
        // For a failed message, preferredExecutor's value doesn't matter as only the owner can
        // invoke the message.
        address preferredExecutor;
    }

    // The slot in transient storage of the call context
    // This is the keccak256 hash of "bridge.ctx_slot"
    bytes32 private constant _CTX_SLOT =
        0xe4ece82196de19aabe639620d7f716c433d1348f96ce727c9989a982dbadc2b9;
    // Place holder value when not using transient storage
    uint256 internal constant PLACEHOLDER = type(uint256).max;

    uint128 public nextMessageId; // slot 1
    mapping(bytes32 msgHash => bool recalled) private __isMessageRecalled; // slot 2, deprecated
    mapping(bytes32 msgHash => Status) public messageStatus; // slot 3
    Context private _ctx; // slot 4,5,6
    mapping(address => bool) public addressBanned; // slot 7
    mapping(bytes32 msgHash => ProofReceipt) public proofReceipt; // slot 8
    uint256[42] private __gap;

    event MessageSent(bytes32 indexed msgHash, Message message);
    event MessageReceived(bytes32 indexed msgHash, Message message, bool isRecall);
    event MessageRecalled(bytes32 indexed msgHash);
    event MessageExecuted(bytes32 indexed msgHash);
    event MessageStatusChanged(bytes32 indexed msgHash, Status status);
    event MessageSuspended(bytes32 msgHash, bool suspended);
    event AddressBanned(address indexed addr, bool banned);

    error B_INVALID_CHAINID();
    error B_INVALID_CONTEXT();
    error B_INVALID_GAS_LIMIT();
    error B_INVALID_STATUS();
    error B_INVALID_USER();
    error B_INVALID_VALUE();
    error B_MESSAGE_NOT_SENT();
    error B_NON_RETRIABLE();
    error B_NOT_FAILED();
    error B_NOT_RECEIVED();
    error B_PERMISSION_DENIED();
    error B_STATUS_MISMATCH();
    error B_INVOCATION_TOO_EARLY();

    modifier sameChain(uint64 chainId) {
        if (chainId != block.chainid) revert B_INVALID_CHAINID();
        _;
    }

    receive() external payable { }

    /// @notice Initializes the contract.
    /// @param _addressManager The address of the {AddressManager} contract.
    function init(address _addressManager) external initializer {
        __Essential_init(_addressManager);
    }

    /// @notice Suspend or unsuspend invocation for a list of messages.
    function suspendMessages(
        bytes32[] calldata msgHashes,
        bool toSuspend
    )
        external
        onlyFromOwnerOrNamed("bridge_watchdog")
    {
        uint64 _timestamp = toSuspend ? type(uint64).max : uint64(block.timestamp);
        for (uint256 i; i < msgHashes.length; ++i) {
            bytes32 msgHash = msgHashes[i];
            proofReceipt[msgHash].receivedAt = _timestamp;
            emit MessageSuspended(msgHash, toSuspend);
        }
    }

    /// @notice Ban or unban an address. A banned addresses will not be invoked upon
    /// with message calls.
    function banAddress(
        address addr,
        bool toBan
    )
        external
        onlyFromOwnerOrNamed("bridge_watchdog")
        nonReentrant
    {
        if (addressBanned[addr] == toBan) revert B_INVALID_STATUS();
        addressBanned[addr] = toBan;
        emit AddressBanned(addr, toBan);
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
        // Ensure the message owner is not null.
        if (message.srcOwner == address(0) || message.destOwner == address(0)) {
            revert B_INVALID_USER();
        }

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

        if (messageStatus[msgHash] != Status.NEW) revert B_STATUS_MISMATCH();

        uint64 receivedAt = proofReceipt[msgHash].receivedAt;
        bool isMessageProven = receivedAt != 0;

        if (!isMessageProven) {
            address signalService = resolve("signal_service", false);

            if (!ISignalService(signalService).isSignalSent(address(this), msgHash)) {
                revert B_MESSAGE_NOT_SENT();
            }

            bytes32 failureSignal = signalForFailedMessage(msgHash);
            if (!_proveSignalReceived(signalService, failureSignal, message.destChainId, proof)) {
                revert B_NOT_FAILED();
            }

            receivedAt = uint64(block.timestamp);
            proofReceipt[msgHash].receivedAt = receivedAt;
        }

        // assert(receivedAt != 0);
        (uint256 invocationDelay,) = getInvocationDelays();

        if (block.timestamp >= invocationDelay + receivedAt) {
            delete proofReceipt[msgHash];
            messageStatus[msgHash] = Status.RECALLED;

            // Execute the recall logic based on the contract's support for the
            // IRecallableSender interface
            if (message.from.supportsInterface(type(IRecallableSender).interfaceId)) {
                _storeContext({
                    msgHash: msgHash,
                    from: address(this),
                    srcChainId: message.srcChainId
                });

                // Perform recall
                IRecallableSender(message.from).onMessageRecalled{ value: message.value }(
                    message, msgHash
                );

                // Reset the context after the message call
                _resetContext();
            } else {
                message.srcOwner.sendEther(message.value);
            }
            emit MessageRecalled(msgHash);
        } else if (!isMessageProven) {
            emit MessageReceived(msgHash, message, true);
        } else {
            revert B_INVOCATION_TOO_EARLY();
        }
    }

    /// @notice Processes a bridge message on the destination chain. This
    /// function is callable by any address, including the `message.destOwner`.
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

        address signalService = resolve("signal_service", false);
        uint64 receivedAt = proofReceipt[msgHash].receivedAt;
        bool isMessageProven = receivedAt != 0;

        (uint256 invocationDelay, uint256 invocationExtraDelay) = getInvocationDelays();

        if (!isMessageProven) {
            if (!_proveSignalReceived(signalService, msgHash, message.srcChainId, proof)) {
                revert B_NOT_RECEIVED();
            }

            receivedAt = uint64(block.timestamp);

            if (invocationDelay != 0) {
                proofReceipt[msgHash] = ProofReceipt({
                    receivedAt: receivedAt,
                    preferredExecutor: message.gasLimit == 0 ? message.destOwner : msg.sender
                });
            }
        }

        if (invocationDelay != 0 && msg.sender != proofReceipt[msgHash].preferredExecutor) {
            // If msg.sender is not the one that proved the message, then there
            // is an extra delay.
            unchecked {
                invocationDelay += invocationExtraDelay;
            }
        }

        if (block.timestamp >= invocationDelay + receivedAt) {
            // If the gas limit is set to zero, only the owner can process the message.
            if (message.gasLimit == 0 && msg.sender != message.destOwner) {
                revert B_PERMISSION_DENIED();
            }

            delete proofReceipt[msgHash];

            uint256 refundAmount;

            // Process message differently based on the target address
            if (
                message.to == address(0) || message.to == address(this)
                    || message.to == signalService || addressBanned[message.to]
            ) {
                // Handle special addresses that don't require actual invocation but
                // mark message as DONE
                refundAmount = message.value;
                _updateMessageStatus(msgHash, Status.DONE);
            } else {
                // Use the specified message gas limit if called by the owner, else
                // use remaining gas
                uint256 gasLimit = msg.sender == message.destOwner ? gasleft() : message.gasLimit;

                if (_invokeMessageCall(message, msgHash, gasLimit)) {
                    _updateMessageStatus(msgHash, Status.DONE);
                } else {
                    _updateMessageStatus(msgHash, Status.RETRIABLE);
                }
            }

            // Determine the refund recipient
            address refundTo = message.refundTo == address(0) ? message.destOwner : message.refundTo;

            // Refund the processing fee
            if (msg.sender == refundTo) {
                refundTo.sendEther(message.fee + refundAmount);
            } else {
                // If sender is another address, reward it and refund the rest
                msg.sender.sendEther(message.fee);
                refundTo.sendEther(refundAmount);
            }
            emit MessageExecuted(msgHash);
        } else if (!isMessageProven) {
            emit MessageReceived(msgHash, message, false);
        } else {
            revert B_INVOCATION_TOO_EARLY();
        }
    }

    /// @notice Retries to invoke the messageCall after releasing associated
    /// Ether and tokens.
    /// @dev This function can be called by any address, including the
    /// `message.destOwner`.
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
        // be the message.destOwner.
        if (message.gasLimit == 0 || isLastAttempt) {
            if (msg.sender != message.destOwner) revert B_PERMISSION_DENIED();
        }

        bytes32 msgHash = hashMessage(message);
        if (messageStatus[msgHash] != Status.RETRIABLE) {
            revert B_NON_RETRIABLE();
        }

        // Attempt to invoke the messageCall.
        if (_invokeMessageCall(message, msgHash, gasleft())) {
            _updateMessageStatus(msgHash, Status.DONE);
        } else if (isLastAttempt) {
            _updateMessageStatus(msgHash, Status.FAILED);
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
            resolve("signal_service", false),
            signalForFailedMessage(hashMessage(message)),
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
            resolve("signal_service", false), hashMessage(message), message.srcChainId, proof
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
    function context() public view returns (Context memory ctx) {
        ctx = _loadContext();
        if (ctx.msgHash == 0 || ctx.msgHash == bytes32(PLACEHOLDER)) {
            revert B_INVALID_CONTEXT();
        }
    }

    /// @notice Returns invocation delay values.
    /// @dev Bridge contract deployed on L1 shall use a non-zero value for better
    /// security.
    /// @return invocationDelay The minimal delay in second before a message can be executed since
    /// and the time it was received on the this chain.
    /// @return invocationExtraDelay The extra delay in second (to be added to invocationDelay) if
    /// the transactor is not the preferredExecutor who proved this message.
    function getInvocationDelays()
        public
        view
        virtual
        returns (uint256 invocationDelay, uint256 invocationExtraDelay)
    {
        if (
            block.chainid == 1 // Ethereum mainnet
        ) {
            // 384 seconds = 6.4 minutes = one ethereum epoch
            return (6 hours, 384 seconds);
        } else if (
            block.chainid == 2 // Ropsten
                || block.chainid == 4 // Rinkeby
                || block.chainid == 5 // Goerli
                || block.chainid == 42 // Kovan
                || block.chainid == 17_000 // Holesky
                || block.chainid == 11_155_111 // Sepolia
                || block.chainid == 32_382 // Chain ID for all Taiko devnet L1s
        ) {
            return (30 minutes, 384 seconds);
        } else {
            // This is a L2 chain where there is no delay in message executation.
            return (0, 0);
        }
    }

    /// @notice Hash the message
    function hashMessage(Message memory message) public pure returns (bytes32) {
        return keccak256(abi.encode("TAIKO_MESSAGE", message));
    }

    /// @notice Returns a signal representing a failed/recalled message.
    function signalForFailedMessage(bytes32 msgHash) public pure returns (bytes32) {
        return msgHash ^ bytes32(uint256(Status.FAILED));
    }

    /// @notice Checks if the given address can pause and unpause the bridge.
    function _authorizePause(address addr)
        internal
        view
        virtual
        override
        onlyFromOwnerOrNamed("bridge_pauser")
    { }

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

        _storeContext({ msgHash: msgHash, from: message.from, srcChainId: message.srcChainId });

        // Perform the message call and capture the success value
        (success,) = message.to.call{ value: message.value, gas: gasLimit }(message.data);

        // Reset the context after the message call
        _resetContext();
    }

    /// @notice Updates the status of a bridge message.
    /// @dev If the new status is different from the current status in the
    /// mapping, the status is updated and an event is emitted.
    /// @param msgHash The hash of the message.
    /// @param status The new status of the message.
    function _updateMessageStatus(bytes32 msgHash, Status status) private {
        if (messageStatus[msgHash] == status) return;

        messageStatus[msgHash] = status;
        emit MessageStatusChanged(msgHash, status);

        if (status == Status.FAILED) {
            ISignalService(resolve("signal_service", false)).sendSignal(
                signalForFailedMessage(msgHash)
            );
        }
    }

    /// @notice Resets the call context
    function _resetContext() private {
        if (block.chainid == 1) {
            _storeContext(bytes32(0), address(0), uint64(0));
        } else {
            _storeContext(bytes32(PLACEHOLDER), address(uint160(PLACEHOLDER)), uint64(PLACEHOLDER));
        }
    }

    /// @notice Stores the call context
    function _storeContext(bytes32 msgHash, address from, uint64 srcChainId) private {
        if (block.chainid == 1) {
            assembly {
                tstore(_CTX_SLOT, msgHash)
                tstore(add(_CTX_SLOT, 1), from)
                tstore(add(_CTX_SLOT, 2), srcChainId)
            }
        } else {
            _ctx = Context({ msgHash: msgHash, from: from, srcChainId: srcChainId });
        }
    }

    /// @notice Loads the call context
    function _loadContext() private view returns (Context memory) {
        if (block.chainid == 1) {
            bytes32 msgHash;
            address from;
            uint64 srcChainId;
            assembly {
                msgHash := tload(_CTX_SLOT)
                from := tload(add(_CTX_SLOT, 1))
                srcChainId := tload(add(_CTX_SLOT, 2))
            }
            return Context({ msgHash: msgHash, from: from, srcChainId: srcChainId });
        } else {
            return _ctx;
        }
    }

    /// @notice Checks if the signal was received.
    /// @param signalService The signalService
    /// @param signal The signal.
    /// @param chainId The ID of the chain the signal is stored on
    /// @param proof The merkle inclusion proof.
    /// @return success True if the message was received.
    function _proveSignalReceived(
        address signalService,
        bytes32 signal,
        uint64 chainId,
        bytes calldata proof
    )
        private
        view
        returns (bool success)
    {
        bytes memory data = abi.encodeCall(
            ISignalService.proveSignalReceived,
            (chainId, resolve(chainId, "bridge", false), signal, proof)
        );
        (success,) = signalService.staticcall(data);
    }
}
