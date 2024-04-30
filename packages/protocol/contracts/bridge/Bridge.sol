// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";
import "../libs/LibAddress.sol";
import "../libs/LibMath.sol";
import "../signal/ISignalService.sol";
import "./IBridge.sol";

/// @title Bridge
/// @notice See the documentation for {IBridge}.
/// @dev Labeled in AddressResolver as "bridge". Additionally, the code hash for the same address on
/// L1 and L2 may be different.
/// @custom:security-contact security@taiko.xyz
contract Bridge is EssentialContract, IBridge {
    using Address for address;
    using LibMath for uint256;
    using LibAddress for address;
    using LibAddress for address payable;

    struct ProcessingStats {
        uint32 gasUsedInFeeCalc;
        uint32 proofSize;
        uint32 numCacheOps;
    }

    /// @dev A debug event for fine-tuning gas related constants in the future.
    event MessageProcessed(bytes32 indexed msgHash, Message message, ProcessingStats stats);

    /// @dev The amount of gas that will be deducted from message.gasLimit before calculating the
    /// invocation gas limit. This value should be fine-tuned with production data.
    uint32 public constant GAS_RESERVE = 800_000;

    /// @dev The gas overhead for both receiving and invoking a message, as well as the proof
    /// calldata cost.
    /// This value should be fine-tuned with production data.
    uint32 public constant GAS_OVERHEAD = 120_000;

    /// @dev The amount of gas not to charge fee per cache operation.
    uint256 private constant _GAS_REFUND_PER_CACHE_OPERATION = 20_000;

    /// @dev The slot in transient storage of the call context. This is the keccak256 hash
    /// of "bridge.ctx_slot"
    bytes32 private constant _CTX_SLOT =
        0xe4ece82196de19aabe639620d7f716c433d1348f96ce727c9989a982dbadc2b9;

    /// @dev Gas limit for sending Ether.
    // - EOA gas used is < 21000
    // - For Loopring smart wallet, gas used is about 23000
    // - For Argent smart wallet on Ethereum, gas used is about 24000
    // - For Gnosis Safe wallet, gas used is about 28000
    uint256 private constant _SEND_ETHER_GAS_LIMIT = 35_000;

    /// @dev Place holder value when not using transient storage
    uint256 private constant _PLACEHOLDER = type(uint256).max;

    /// @notice The next message ID.
    /// @dev Slot 1.
    uint64 private __reserved1;
    uint64 public nextMessageId;

    /// @notice Mapping to store the status of a message from its hash.
    /// @dev Slot 2.
    mapping(bytes32 msgHash => Status status) public messageStatus;

    /// @dev Slots 3 and 4
    Context private __ctx;

    /// @dev Slot 5.
    uint256 private __reserved2;

    /// @dev Slot 6.
    uint256 private __reserved3;

    uint256[44] private __gap;

    error B_INVALID_CHAINID();
    error B_INVALID_CONTEXT();
    error B_INVALID_FEE();
    error B_INVALID_GAS_LIMIT();
    error B_INVALID_STATUS();
    error B_INVALID_USER();
    error B_INVALID_VALUE();
    error B_INSUFFICIENT_GAS();
    error B_MESSAGE_NOT_SENT();
    error B_PERMISSION_DENIED();
    error B_RETRY_FAILED();
    error B_SIGNAL_NOT_RECEIVED();

    modifier sameChain(uint64 _chainId) {
        if (_chainId != block.chainid) revert B_INVALID_CHAINID();
        _;
    }

    /// @notice Function to receive Ether.
    receive() external payable { }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    function init(address _owner, address _addressManager) external initializer {
        __Essential_init(_owner, _addressManager);
    }

    function init2() external onlyOwner reinitializer(2) {
        // reset some previously used slots for future reuse
        __reserved1 = 0;
        __reserved2 = 0;
        __reserved3 = 0;
    }

    /// @inheritdoc IBridge
    function sendMessage(Message calldata _message)
        external
        payable
        override
        whenNotPaused
        nonReentrant
        returns (bytes32 msgHash_, Message memory message_)
    {
        // Ensure the message owner is not null.
        if (_message.srcOwner == address(0) || _message.destOwner == address(0)) {
            revert B_INVALID_USER();
        }

        if (_message.gasLimit == 0) {
            if (_message.fee != 0) revert B_INVALID_FEE();
        } else if (_invocationGasLimit(_message, false) == 0) {
            revert B_INVALID_GAS_LIMIT();
        }

        // Check if the destination chain is enabled.
        (bool destChainEnabled,) = isDestChainEnabled(_message.destChainId);

        // Verify destination chain and to address.
        if (!destChainEnabled) revert B_INVALID_CHAINID();
        if (_message.destChainId == block.chainid) revert B_INVALID_CHAINID();

        // Ensure the sent value matches the expected amount.
        uint256 expectedAmount = _message.value + _message.fee;
        if (expectedAmount != msg.value) revert B_INVALID_VALUE();

        message_ = _message;

        // Configure message details and send signal to indicate message sending.
        message_.id = nextMessageId++;
        message_.from = msg.sender;
        message_.srcChainId = uint64(block.chainid);

        msgHash_ = hashMessage(message_);

        emit MessageSent(msgHash_, message_);
        ISignalService(resolve(LibStrings.B_SIGNAL_SERVICE, false)).sendSignal(msgHash_);
    }

    /// @inheritdoc IBridge
    function recallMessage(
        Message calldata _message,
        bytes calldata _proof
    )
        external
        whenNotPaused
        sameChain(_message.srcChainId)
        nonReentrant
    {
        bytes32 msgHash = hashMessage(_message);
        _checkStatus(msgHash, Status.NEW);

        address signalService = resolve(LibStrings.B_SIGNAL_SERVICE, false);

        if (!ISignalService(signalService).isSignalSent(address(this), msgHash)) {
            revert B_MESSAGE_NOT_SENT();
        }

        (bool received,) = _proveSignalReceived(
            signalService, signalForFailedMessage(msgHash), _message.destChainId, _proof
        );
        if (!received) revert B_SIGNAL_NOT_RECEIVED();

        _updateMessageStatus(msgHash, Status.RECALLED);

        // Execute the recall logic based on the contract's support for the
        // IRecallableSender interface
        if (_message.from.supportsInterface(type(IRecallableSender).interfaceId)) {
            _storeContext(msgHash, address(this), _message.srcChainId);

            // Perform recall
            IRecallableSender(_message.from).onMessageRecalled{ value: _message.value }(
                _message, msgHash
            );

            // Must reset the context after the message call
            _resetContext();
        } else {
            _message.srcOwner.sendEtherAndVerify(_message.value, _SEND_ETHER_GAS_LIMIT);
        }
    }

    /// @inheritdoc IBridge
    /// @dev This transaction's gas limit must not be smaller than:
    /// `(message.gasLimit - GAS_RESERVE) * 64 / 63 + GAS_RESERVE`,
    /// Or we can use a simplified rule: `tx.gaslimit = message.gaslimit * 102%`.
    function processMessage(
        Message calldata _message,
        bytes calldata _proof
    )
        external
        whenNotPaused
        sameChain(_message.destChainId)
        nonReentrant
    {
        uint256 gasStart = gasleft();

        // If the gas limit is set to zero, only the owner can process the message.
        if (_message.gasLimit == 0 && msg.sender != _message.destOwner) {
            revert B_PERMISSION_DENIED();
        }

        bytes32 msgHash = hashMessage(_message);
        _checkStatus(msgHash, Status.NEW);

        address signalService = resolve(LibStrings.B_SIGNAL_SERVICE, false);

        ProcessingStats memory stats;
        bool received;

        (received, stats.numCacheOps) =
            _proveSignalReceived(signalService, msgHash, _message.srcChainId, _proof);
        if (!received) revert B_SIGNAL_NOT_RECEIVED();

        uint256 refundAmount;
        if (
            _message.to == address(0) || _message.to == address(this)
                || _message.to == signalService
        ) {
            // Handle special addresses that don't require actual invocation but
            // mark message as DONE
            refundAmount = _message.value;
            _updateMessageStatus(msgHash, Status.DONE);
        } else {
            Status status = _invokeMessageCall(
                _message, msgHash, _invocationGasLimit(_message, true)
            ) ? Status.DONE : Status.RETRIABLE;
            _updateMessageStatus(msgHash, status);
        }

        if (_message.fee != 0) {
            refundAmount += _message.fee;

            if (msg.sender != _message.destOwner && _message.gasLimit != 0) {
                unchecked {
                    uint256 refund = stats.numCacheOps * _GAS_REFUND_PER_CACHE_OPERATION;
                    stats.gasUsedInFeeCalc = uint32(GAS_OVERHEAD + gasStart - gasleft());
                    uint256 gasCharged = refund.max(stats.gasUsedInFeeCalc) - refund;
                    uint256 maxFee = gasCharged * _message.fee / _message.gasLimit;
                    uint256 baseFee = gasCharged * block.basefee;
                    uint256 fee =
                        (baseFee >= maxFee ? maxFee : (maxFee + baseFee) >> 1).min(_message.fee);

                    refundAmount -= fee;
                    msg.sender.sendEtherAndVerify(fee, _SEND_ETHER_GAS_LIMIT);
                }
            }
        }

        _message.destOwner.sendEtherAndVerify(refundAmount, _SEND_ETHER_GAS_LIMIT);

        stats.proofSize = uint32(_proof.length);
        emit MessageProcessed(msgHash, _message, stats);
    }

    /// @inheritdoc IBridge
    function retryMessage(
        Message calldata _message,
        bool _isLastAttempt
    )
        external
        whenNotPaused
        sameChain(_message.destChainId)
        nonReentrant
    {
        bytes32 msgHash = hashMessage(_message);
        _checkStatus(msgHash, Status.RETRIABLE);

        uint256 invocationGasLimit;
        if (msg.sender != _message.destOwner) {
            if (_message.gasLimit == 0 || _isLastAttempt) revert B_PERMISSION_DENIED();
            invocationGasLimit = _invocationGasLimit(_message, true);
        } else {
            // The owner uses all gas left in message invocation
            invocationGasLimit = gasleft();
        }

        // Attempt to invoke the messageCall.
        if (_invokeMessageCall(_message, msgHash, invocationGasLimit)) {
            _updateMessageStatus(msgHash, Status.DONE);
        } else if (_isLastAttempt) {
            _updateMessageStatus(msgHash, Status.FAILED);

            ISignalService(resolve(LibStrings.B_SIGNAL_SERVICE, false)).sendSignal(
                signalForFailedMessage(msgHash)
            );
        } else {
            revert B_RETRY_FAILED();
        }
    }

    /// @inheritdoc IBridge
    function failMessage(Message calldata _message)
        external
        whenNotPaused
        sameChain(_message.destChainId)
        nonReentrant
    {
        if (msg.sender != _message.destOwner) revert B_PERMISSION_DENIED();

        bytes32 msgHash = hashMessage(_message);
        _checkStatus(msgHash, Status.RETRIABLE);

        _updateMessageStatus(msgHash, Status.FAILED);
        ISignalService(resolve(LibStrings.B_SIGNAL_SERVICE, false)).sendSignal(
            signalForFailedMessage(msgHash)
        );
    }

    /// @inheritdoc IBridge
    function isMessageSent(Message calldata _message) external view returns (bool) {
        if (_message.srcChainId != block.chainid) return false;
        return ISignalService(resolve(LibStrings.B_SIGNAL_SERVICE, false)).isSignalSent({
            _app: address(this),
            _signal: hashMessage(_message)
        });
    }

    /// @notice Checks if a msgHash has failed on its destination chain.
    /// This is the 'readonly' version of proveMessageFailed.
    /// @param _message The message.
    /// @param _proof The merkle inclusion proof.
    /// @return true if the message has failed, false otherwise.
    function isMessageFailed(
        Message calldata _message,
        bytes calldata _proof
    )
        external
        view
        returns (bool)
    {
        if (_message.srcChainId != block.chainid) return false;

        return _isSignalReceived(
            resolve(LibStrings.B_SIGNAL_SERVICE, false),
            signalForFailedMessage(hashMessage(_message)),
            _message.destChainId,
            _proof
        );
    }

    /// @notice Checks if a msgHash has been received on its source chain.
    /// This is the 'readonly' version of proveMessageReceived.
    /// @param _message The message.
    /// @param _proof The merkle inclusion proof.
    /// @return true if the message has been received, false otherwise.
    function isMessageReceived(
        Message calldata _message,
        bytes calldata _proof
    )
        external
        view
        returns (bool)
    {
        if (_message.destChainId != block.chainid) return false;
        return _isSignalReceived(
            resolve(LibStrings.B_SIGNAL_SERVICE, false),
            hashMessage(_message),
            _message.srcChainId,
            _proof
        );
    }

    /// @notice Checks if the destination chain is enabled.
    /// @param _chainId The destination chain ID.
    /// @return enabled_ True if the destination chain is enabled.
    /// @return destBridge_ The bridge of the destination chain.
    function isDestChainEnabled(uint64 _chainId)
        public
        view
        returns (bool enabled_, address destBridge_)
    {
        destBridge_ = resolve(_chainId, "bridge", true);
        enabled_ = destBridge_ != address(0);
    }

    /// @notice Gets the current context.
    /// @inheritdoc IBridge
    function context() external view returns (Context memory ctx_) {
        ctx_ = _loadContext();
        if (ctx_.msgHash == 0 || ctx_.msgHash == bytes32(_PLACEHOLDER)) {
            revert B_INVALID_CONTEXT();
        }
    }

    /// @inheritdoc IBridge
    function hashMessage(Message memory _message) public pure returns (bytes32) {
        return keccak256(abi.encode("TAIKO_MESSAGE", _message));
    }

    /// @notice Returns a signal representing a failed/recalled message.
    /// @param _msgHash The message hash.
    /// @return The failed representation of it as bytes32.
    function signalForFailedMessage(bytes32 _msgHash) public pure returns (bytes32) {
        return _msgHash ^ bytes32(uint256(Status.FAILED));
    }

    /// @notice Returns the minimal gas limit required for sending a given message.
    /// @param dataLength The length of message.data.
    /// @return The minimal gas limit required for sending this message.
    function getMessageMinGasLimit(uint256 dataLength) public pure returns (uint32) {
        unchecked {
            // Message struct takes 7*32=224 bytes + a variable length array.
            // Since ABI.encode pads data to multiples of 32 bytes, we over-charge 32 bytes
            return GAS_RESERVE + uint32((dataLength + 256) >> 4);
        }
    }

    /// @notice Checks if the given address can pause and/or unpause the bridge.
    /// @dev Considering that the watchdog is a hot wallet, in case its private key is leaked, we
    /// only allow watchdog to pause the bridge, but does not allow it to unpause the bridge.
    function _authorizePause(address addr, bool toPause) internal view override {
        // Owenr and chain_pauser can pause/unpause the bridge.
        if (addr == owner() || addr == resolve(LibStrings.B_CHAIN_WATCHDOG, true)) return;

        // bridge_watchdog can pause the bridge, but cannot unpause it.
        if (toPause && addr == resolve(LibStrings.B_BRIDGE_WATCHDOG, true)) return;

        revert RESOLVER_DENIED();
    }

    /// @notice Invokes a call message on the Bridge.
    /// @param _message The call message to be invoked.
    /// @param _msgHash The hash of the message.
    /// @return success_ A boolean value indicating whether the message call was successful.
    /// @dev This function updates the context in the state before and after the
    /// message call.
    function _invokeMessageCall(
        Message calldata _message,
        bytes32 _msgHash,
        uint256 _gasLimit
    )
        private
        returns (bool success_)
    {
        assert(_message.from != address(this));

        if (_gasLimit == 0) return false;

        if (
            _message.data.length >= 4 // msg can be empty
                && bytes4(_message.data) != IMessageInvocable.onMessageInvocation.selector
                && _message.to.isContract()
        ) return false;

        _storeContext(_msgHash, _message.from, _message.srcChainId);
        success_ = _message.to.sendEther(_message.value, _gasLimit, _message.data);
        _resetContext();
    }

    /// @notice Updates the status of a bridge message.
    /// @dev If the new status is different from the current status in the
    /// mapping, the status is updated and an event is emitted.
    /// @param _msgHash The hash of the message.
    /// @param _status The new status of the message.
    function _updateMessageStatus(bytes32 _msgHash, Status _status) private {
        if (messageStatus[_msgHash] == _status) revert B_INVALID_STATUS();
        messageStatus[_msgHash] = _status;
        emit MessageStatusChanged(_msgHash, _status);
    }

    /// @notice Resets the call context
    function _resetContext() private {
        if (LibNetwork.isDencunSupported(block.chainid)) {
            _storeContext(bytes32(0), address(0), uint64(0));
        } else {
            _storeContext(
                bytes32(_PLACEHOLDER), address(uint160(_PLACEHOLDER)), uint64(_PLACEHOLDER)
            );
        }
    }

    /// @notice Stores the call context
    /// @param _msgHash The message hash.
    /// @param _from The sender's address.
    /// @param _srcChainId The source chain ID.
    function _storeContext(bytes32 _msgHash, address _from, uint64 _srcChainId) private {
        if (LibNetwork.isDencunSupported(block.chainid)) {
            assembly {
                tstore(_CTX_SLOT, _msgHash)
                tstore(add(_CTX_SLOT, 1), _from)
                tstore(add(_CTX_SLOT, 2), _srcChainId)
            }
        } else {
            __ctx = Context(_msgHash, _from, _srcChainId);
        }
    }

    /// @notice Loads and returns the call context.
    /// @return ctx_ The call context.
    function _loadContext() private view returns (Context memory) {
        if (LibNetwork.isDencunSupported(block.chainid)) {
            bytes32 msgHash;
            address from;
            uint64 srcChainId;
            assembly {
                msgHash := tload(_CTX_SLOT)
                from := tload(add(_CTX_SLOT, 1))
                srcChainId := tload(add(_CTX_SLOT, 2))
            }
            return Context(msgHash, from, srcChainId);
        } else {
            return __ctx;
        }
    }

    /// @notice Checks if the signal was received and caches cross-chain data if requested.
    /// @param _signalService The signal service address.
    /// @param _signal The signal.
    /// @param _chainId The ID of the chain the signal is stored on.
    /// @param _proof The merkle inclusion proof.
    /// @return success_ true if the message was received.
    /// @return numCacheOps_ Num of cached items
    function _proveSignalReceived(
        address _signalService,
        bytes32 _signal,
        uint64 _chainId,
        bytes calldata _proof
    )
        private
        returns (bool success_, uint32 numCacheOps_)
    {
        try ISignalService(_signalService).proveSignalReceived(
            _chainId, resolve(_chainId, "bridge", false), _signal, _proof
        ) returns (uint256 numCacheOps) {
            numCacheOps_ = uint32(numCacheOps);
            success_ = true;
        } catch {
            success_ = false;
        }
    }

    /// @notice Checks if the signal was received.
    /// This is the 'readonly' version of _proveSignalReceived.
    /// @param _signalService The signal service address.
    /// @param _signal The signal.
    /// @param _chainId The ID of the chain the signal is stored on.
    /// @param _proof The merkle inclusion proof.
    /// @return true if the message was received.
    function _isSignalReceived(
        address _signalService,
        bytes32 _signal,
        uint64 _chainId,
        bytes calldata _proof
    )
        private
        view
        returns (bool)
    {
        try ISignalService(_signalService).verifySignalReceived(
            _chainId, resolve(_chainId, "bridge", false), _signal, _proof
        ) {
            return true;
        } catch {
            return false;
        }
    }

    function _invocationGasLimit(
        Message calldata _message,
        bool _checkThe63Over64Rule
    )
        private
        view
        returns (uint256 gasLimit_)
    {
        unchecked {
            uint256 minGasRequired = getMessageMinGasLimit(_message.data.length);
            gasLimit_ = minGasRequired.max(_message.gasLimit) - minGasRequired;
        }

        if (_checkThe63Over64Rule && (gasleft() * 63) >> 6 < gasLimit_) {
            revert B_INSUFFICIENT_GAS();
        }
    }

    function _checkStatus(bytes32 _msgHash, Status _expectedStatus) private view {
        if (messageStatus[_msgHash] != _expectedStatus) revert B_INVALID_STATUS();
    }
}
