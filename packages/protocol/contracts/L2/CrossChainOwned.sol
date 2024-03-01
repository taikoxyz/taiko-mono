// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../common/EssentialContract.sol";
import "../bridge/IBridge.sol";

/// @title CrossChainOwned
/// @notice This contract's owner can be a local address or one that lives on another chain and uses
/// signals for transaction approval.
/// @dev Notice that when sending the message on the owner chain, the gas limit of the message must
/// not be zero, so on this chain, some EOA can help execute this transaction.
/// @custom:security-contact security@taiko.xyz
abstract contract CrossChainOwned is EssentialContract, IMessageInvocable {
    /// @notice The owner chain ID.
    uint64 public ownerChainId;

    /// @notice The next transaction ID.
    uint64 public nextTxId;

    uint256[49] private __gap;

    /// @notice Emitted when a transaction is executed.
    /// @param txId The transaction ID.
    /// @param selector The function selector.
    event TransactionExecuted(uint64 indexed txId, bytes4 indexed selector);

    error XCO_INVALID_OWNER_CHAINID();
    error XCO_INVALID_TX_ID();
    error XCO_PERMISSION_DENIED();
    error XCO_TX_REVERTED();

    /// @inheritdoc IMessageInvocable
    /// @dev Do not guard with nonReentrant as this function will re-enter the contract as _data
    /// represents calls to address(this).
    function onMessageInvocation(bytes calldata _data)
        external
        payable
        whenNotPaused
        onlyFromNamed("bridge")
    {
        (uint64 txId, bytes memory txdata) = abi.decode(_data, (uint64, bytes));
        if (txId != nextTxId) revert XCO_INVALID_TX_ID();

        IBridge.Context memory ctx = IBridge(msg.sender).context();
        if (ctx.srcChainId != ownerChainId || ctx.from != owner()) {
            revert XCO_PERMISSION_DENIED();
        }

        (bool success,) = address(this).call(txdata);
        if (!success) revert XCO_TX_REVERTED();

        emit TransactionExecuted(nextTxId++, bytes4(txdata));
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    /// @param _ownerChainId The owner's deployment chain ID.
    function __CrossChainOwned_init(
        address _owner,
        address _addressManager,
        uint64 _ownerChainId
    )
        internal
        virtual
        onlyInitializing
    {
        __Essential_init(_owner, _addressManager);
        if (_ownerChainId == 0 || _ownerChainId == block.chainid) {
            revert XCO_INVALID_OWNER_CHAINID();
        }
        ownerChainId = _ownerChainId;
    }
}
