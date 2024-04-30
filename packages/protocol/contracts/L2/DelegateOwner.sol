// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";
import "../bridge/IBridge.sol";

/// @title DelegateOwner
/// @notice This contract will be the owner of all essential contracts deployed on the L2 chain.
/// @dev Notice that when sending the message on the owner chain, the gas limit of the message must
/// not be zero, so on this chain, some EOA can help execute this transaction.
/// @custom:security-contact security@taiko.xyz
contract DelegateOwner is EssentialContract, IMessageInvocable {
    /// @notice The owner chain ID.
    uint64 public srcChainId;

    /// @notice The next transaction ID.
    uint64 public nextTxId;

    /// @notice The real owner on L1, supposedly the DAO.
    address public srcOwner;

    uint256[48] private __gap;

    /// @notice Emitted when a transaction is executed.
    /// @param txId The transaction ID.
    /// @param target The target address.
    /// @param selector The function selector.
    event TransactionExecuted(uint64 indexed txId, address indexed target, bytes4 indexed selector);

    /// @notice Emitted when this contract accepted the ownership of a target contract.
    /// @param target The target address.
    event OwnershipAccepted(address indexed target);

    error DO_INVALID_PARAM();
    error DO_INVALID_TX_ID();
    error DO_INVALID_VALUE();
    error DO_PERMISSION_DENIED();
    error DO_TX_REVERTED();
    error DO_UNSUPPORTED();

    /// @notice Initializes the contract.
    /// @param _srcOwner The real owner on L1 that can send a cross-chain message to invoke
    /// `onMessageInvocation`.
    /// @param _addressManager The address of the {AddressManager} contract.
    /// @param _srcChainId The L1 chain's ID.
    function init(
        address _srcOwner,
        address _addressManager,
        uint64 _srcChainId
    )
        external
        initializer
    {
        // This contract's owner will be itself.
        __Essential_init(address(this), _addressManager);

        if (_srcOwner == address(0) || _srcChainId == 0 || _srcChainId == block.chainid) {
            revert DO_INVALID_PARAM();
        }

        srcOwner = _srcOwner;
        srcChainId = _srcChainId;
    }

    /// @inheritdoc IMessageInvocable
    /// @dev Do not guard with nonReentrant as this function may re-enter the contract as _data
    /// represents calls to address(this).
    function onMessageInvocation(bytes calldata _data)
        external
        payable
        onlyFromNamed(LibStrings.B_BRIDGE)
    {
        (uint64 txId, address target, uint256 txValue, bytes memory txdata) =
            abi.decode(_data, (uint64, address, uint256, bytes));

        if (txId != nextTxId) revert DO_INVALID_TX_ID();
        if (txValue != msg.value) revert DO_INVALID_VALUE();

        IBridge.Context memory ctx = IBridge(msg.sender).context();
        if (ctx.srcChainId != srcChainId || ctx.from != srcOwner) {
            revert DO_PERMISSION_DENIED();
        }
        nextTxId++;
        // Sending ether along with the function call. Although this is sending Ether from this
        // contract back to itself, txData's function can now be payable.
        (bool success,) = target.call{ value: txValue }(txdata);
        if (!success) revert DO_TX_REVERTED();

        emit TransactionExecuted(txId, target, bytes4(txdata));
    }

    function acceptOwnership(address target) external {
        Ownable2StepUpgradeable(target).acceptOwnership();
        emit OwnershipAccepted(target);
    }

    function _authorizePause(address, bool) internal pure override {
        revert DO_UNSUPPORTED();
    }
}
