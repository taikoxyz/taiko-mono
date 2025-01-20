// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Bridge.sol";
import "../../shared/based/ITaiko.sol";
import "src/layer1/based/ITaikoInbox.sol";
import "src/shared/libs/LibAddress.sol";
import "src/shared/common/EssentialContract.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract EtherBridgeWrapper is EssentialContract {
    using Address for address;
    using LibAddress for address;

    /// @dev Represents an operation to send Ether to another chain.
    struct EtherBridgeOp {
        // Destination chain ID.
        uint64 destChainId;
        // The owner of the bridge message on the destination chain.
        address destOwner;
        // Recipient address.
        address to;
        // Processing fee for the relayer.
        uint64 fee;
        // Gas limit for the operation.
        uint32 gasLimit;
        // Amount of Ether to be sent.
        uint256 amount;
        // Added solver fee
        uint256 solverFee;
    }

    /// @dev Represents an operation to solve an Ether bridging intent
    struct SolverOp {
        uint256 nonce;
        address to;
        uint256 amount;
        // Fields for L2 batch verification
        uint64 l2BatchId;
        bytes32 l2BatchMetaHash;
    }

    /// @notice Emitted when Ether is sent to another chain.
    event EtherSent(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 solverFee
    );

    /// @notice Emitted when Ether is received from another chain.
    event EtherReceived(
        bytes32 indexed msgHash,
        address indexed from,
        address indexed to,
        address solver,
        uint64 srcChainId,
        uint256 amount,
        uint256 solverFee
    );

    /// @notice Emitted when a bridging intent is solved
    event EtherSolved(bytes32 indexed solverCondition, address solver);

    error INVALID_AMOUNT();
    error INSUFFICIENT_VALUE();
    error ETHER_BRIDGE_PERMISSION_DENIED();
    error ETHER_BRDIGE_INVALID_TO_ADDR();
    error VAULT_NOT_ON_L1();
    error VAULT_METAHASH_MISMATCH();
    error VAULT_ALREADY_SOLVED();

    /// @notice Mapping from solver condition to the address of solver
    mapping(bytes32 solverCondition => address solver) public solverConditionToSolver;

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _sharedResolver The {IResolver} used by multipel rollups.
    function init(address _owner, address _sharedResolver) external initializer {
        __Essential_init(_owner, _sharedResolver);
    }

    /// @notice Sends Ether to another chain.
    /// @param _op Options for sending Ether.
    /// @return message_ The constructed message.
    function sendToken(EtherBridgeOp calldata _op)
        external
        payable
        whenNotPaused
        nonReentrant
        returns (IBridge.Message memory message_)
    {
        if (_op.amount == 0) revert INVALID_AMOUNT();
        if (msg.value < _op.amount + _op.fee + _op.solverFee) revert INSUFFICIENT_VALUE();

        address bridge = resolve(LibStrings.B_BRIDGE, false);

        // Generate solver condition if solver fee is specified
        bytes32 solverCondition;
        if (_op.solverFee > 0) {
            uint256 _nonce = IBridge(bridge).nextMessageId();
            solverCondition = getSolverCondition(_nonce, _op.to, _op.amount);
        }

        bytes memory data = abi.encodeCall(
            this.onMessageInvocation,
            abi.encode(msg.sender, _op.to, _op.amount, _op.solverFee, solverCondition)
        );

        IBridge.Message memory message = IBridge.Message({
            id: 0, // will receive a new value
            from: address(0), // will receive a new value
            srcChainId: 0, // will receive a new value
            destChainId: _op.destChainId,
            srcOwner: msg.sender,
            destOwner: _op.destOwner != address(0) ? _op.destOwner : msg.sender,
            to: resolve(_op.destChainId, name(), false),
            value: _op.amount + _op.solverFee,
            fee: _op.fee,
            gasLimit: _op.gasLimit,
            data: data
        });

        bytes32 msgHash;
        (msgHash, message_) = IBridge(bridge).sendMessage{ value: msg.value }(message);

        emit EtherSent({
            msgHash: msgHash,
            from: message_.srcOwner,
            to: _op.to,
            amount: _op.amount,
            solverFee: _op.solverFee
        });
    }

    /// @notice Handles incoming Ether bridge messages.
    /// @param _data The encoded message data.
    function onMessageInvocation(bytes calldata _data)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        // `onlyFromBridge` checked in checkProcessMessageContext
        IBridge.Context memory ctx = checkProcessMessageContext();

        (address from, address to, uint256 amount, uint256 solverFee, bytes32 solverCondition) =
            abi.decode(_data, (address, address, uint256, uint256, bytes32));

        // Don't allow sending to disallowed addresses
        checkToAddress(to);

        address recipient = to;

        // If the bridging intent has been solved, the solver becomes the recipient
        address solver = solverConditionToSolver[solverCondition];
        if (solver != address(0)) {
            recipient = solver;
            delete solverConditionToSolver[solverCondition];
        }

        // Transfer Ether to recipient
        recipient.sendEtherAndVerify(amount + solverFee);

        emit EtherReceived({
            msgHash: ctx.msgHash,
            from: from,
            to: to,
            solver: solver,
            srcChainId: ctx.srcChainId,
            amount: amount,
            solverFee: solverFee
        });
    }

    /// @notice Lets a solver fulfil a bridging intent by transferring Ether to the recipient.
    /// @param _op Parameters for the solve operation
    function solve(SolverOp memory _op) external payable nonReentrant whenNotPaused {
        if (_op.l2BatchMetaHash != 0) {
            // Verify that the required L2 batch containing the intent transaction has been proposed
            address taiko = resolve(LibStrings.B_TAIKO, false);
            if (!ITaiko(taiko).isOnL1()) revert VAULT_NOT_ON_L1();

            bytes32 l2BatchMetaHash = ITaikoInbox(taiko).getBatch(_op.l2BatchId).metaHash;
            if (l2BatchMetaHash != _op.l2BatchMetaHash) revert VAULT_METAHASH_MISMATCH();
        }

        // Record the solver's address
        bytes32 solverCondition = getSolverCondition(_op.nonce, _op.to, _op.amount);
        if (solverConditionToSolver[solverCondition] != address(0)) revert VAULT_ALREADY_SOLVED();
        solverConditionToSolver[solverCondition] = msg.sender;

        // Transfer the Ether to the recipient
        _op.to.sendEtherAndVerify(_op.amount);

        emit EtherSolved(solverCondition, msg.sender);
    }

    /// @notice Returns the solver condition for a bridging intent
    /// @param _nonce Unique numeric value to prevent nonce collision
    /// @param _to Recipient on destination chain
    /// @param _amount Amount of Ether expected by the recipient
    /// @return solver condition
    function getSolverCondition(
        uint256 _nonce,
        address _to,
        uint256 _amount
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_nonce, _to, _amount));
    }

    function checkProcessMessageContext()
        internal
        view
        onlyFromNamed(LibStrings.B_BRIDGE)
        returns (IBridge.Context memory ctx_)
    {
        ctx_ = IBridge(msg.sender).context();
        address selfOnSourceChain = resolve(ctx_.srcChainId, name(), false);
        if (ctx_.from != selfOnSourceChain) revert ETHER_BRIDGE_PERMISSION_DENIED();
    }

    function checkToAddress(address _to) internal view {
        if (_to == address(0) || _to == address(this)) revert ETHER_BRDIGE_INVALID_TO_ADDR();
    }

    function name() public pure returns (bytes32) {
        return LibStrings.B_ETHER_BRIDGE_WRAPPER;
    }
}
