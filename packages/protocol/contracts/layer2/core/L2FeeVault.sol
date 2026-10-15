// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IBridge, IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

import "./L2FeeVault_Layout.sol"; // DO NOT DELETE

/// @title L2FeeVault
/// @notice Holds the L2 transaction fees of the Etna chain until a sweep sends them through the L2
/// Bridge to the L1 `EtnaRewardPool`.
/// @dev This contract's address is the Etna node's `fee_vault` chain constant: the coinbase and
/// suggested fee recipient of every Etna block. Each block credits it the whole base fee
/// (`basefeeSharingPctg` is pinned to 100) and the priority fees. Coinbase credits run no code, so
/// the vault keeps no per-block ledger. It has no `receive`: direct transfers revert, and Ether
/// forced in without a call (such as by `selfdestruct`) is swept as fees.
///
/// `sweep` is the only outflow. Any account may call it but picks only its timing, the message
/// gas limit and the relay fee; the destination (`rewardPool` on `l1ChainId`) is immutable and
/// the amount is always the whole balance.
/// @custom:security-contact security@taiko.xyz
contract L2FeeVault is EssentialContract {
    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice The largest message gas limit a sweep accepts. A relayer on L1 must be able to
    /// forward the requested gas, or the L1 Bridge rejects every relayed `processMessage` and the
    /// message never leaves `NEW`.
    uint32 public constant MAX_SWEEP_GAS_LIMIT = 3_000_000;

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @notice The Bridge on this chain that carries sweeps to L1.
    address public immutable l2Bridge;

    /// @notice The chain ID of L1, the destination of every sweep.
    uint64 public immutable l1ChainId;

    /// @notice The `EtnaRewardPool` proxy on L1: the `to` and `destOwner` of every sweep message.
    address public immutable rewardPool;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice The total amount swept to the reward pool, in wei; relay fees excluded.
    uint256 public sweptTotal;

    /// @notice The nonce of the next sweep; each sweep message carries its nonce.
    uint64 public sweepNonce;

    uint256[48] private __gap;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when the vault sweeps its balance to the reward pool.
    /// @param nonce The sweep nonce carried by the message.
    /// @param amount The amount sent to the reward pool, in wei.
    /// @param relayFee The relay fee paid by the caller, in wei.
    /// @param msgHash The hash of the Bridge message.
    event FeesSwept(uint64 indexed nonce, uint256 amount, uint256 relayFee, bytes32 msgHash);

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Sets the sweep destination.
    /// @param _l2Bridge The Bridge on this chain; must be non-zero.
    /// @param _l1ChainId The chain ID of L1; must be non-zero.
    /// @param _rewardPool The `EtnaRewardPool` proxy on L1; must be non-zero.
    constructor(address _l2Bridge, uint64 _l1ChainId, address _rewardPool) {
        require(_l2Bridge != address(0), ZERO_ADDRESS());
        require(_l1ChainId != 0, ZERO_VALUE());
        require(_rewardPool != address(0), ZERO_ADDRESS());

        l2Bridge = _l2Bridge;
        l1ChainId = _l1ChainId;
        rewardPool = _rewardPool;
    }

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the vault.
    /// @param _owner The owner of the vault (the L2 `DelegateController`). `msg.sender` is used if
    /// this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @notice Sends the vault's whole balance through the L2 Bridge to the reward pool.
    /// @dev Permissionless. `msg.value` is the relay fee: it becomes the message `fee` and is not
    /// taken from the swept amount. The message invokes `rewardPool.onMessageInvocation` with
    /// `abi.encode(nonce)` and makes the pool its `destOwner`, so only the pool can fail or
    /// finally retry it on L1, and unused fees are refunded to the pool. An empty vault sends no
    /// message, changes no state and returns zero; a relay fee is then rejected.
    /// @param _gasLimit The gas limit of the message on L1, in `(0, MAX_SWEEP_GAS_LIMIT]`. A zero
    /// limit lets only the pool process the message; a limit no relayer can forward under the
    /// L1 transaction gas cap makes the Bridge reject every relayed attempt. Either way the
    /// message would never leave `NEW`. The Bridge also rejects a limit at or below its minimum
    /// for the message.
    /// @return msgHash_ The hash of the Bridge message, or zero for an empty vault.
    function sweep(uint32 _gasLimit) external payable nonReentrant returns (bytes32 msgHash_) {
        uint256 amount = address(this).balance - msg.value;
        if (amount == 0) {
            require(msg.value == 0, EmptyVaultWithFee());
            return 0;
        }
        require(_gasLimit != 0, ZeroGasLimit());
        require(_gasLimit <= MAX_SWEEP_GAS_LIMIT, GasLimitTooLarge());
        require(msg.value <= type(uint64).max, RelayFeeTooLarge());

        uint64 nonce = sweepNonce;
        sweptTotal += amount;
        sweepNonce = nonce + 1;

        IBridge.Message memory message;
        message.fee = uint64(msg.value);
        message.gasLimit = _gasLimit;
        message.srcOwner = address(this);
        message.destChainId = l1ChainId;
        message.destOwner = rewardPool;
        message.to = rewardPool;
        message.value = amount;
        message.data = abi.encodeCall(IMessageInvocable.onMessageInvocation, (abi.encode(nonce)));

        (msgHash_,) = IBridge(l2Bridge).sendMessage{ value: amount + msg.value }(message);
        emit FeesSwept(nonce, amount, msg.value, msgHash_);
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error EmptyVaultWithFee();
    error GasLimitTooLarge();
    error RelayFeeTooLarge();
    error ZeroGasLimit();
}
