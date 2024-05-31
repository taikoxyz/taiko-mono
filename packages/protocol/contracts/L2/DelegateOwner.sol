// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";
import "../libs/LibAddress.sol";
import "../libs/LibBytes.sol";
import "../bridge/IBridge.sol";

/// @title DelegateOwner
/// @notice This contract will be the owner of all essential contracts deployed on the L2 chain.
/// @dev Notice that when sending the message on the owner chain, the gas limit of the message must
/// not be zero, so on this chain, some EOA can help execute this transaction.
/// @custom:security-contact security@taiko.xyz
contract DelegateOwner is EssentialContract, IMessageInvocable {
    /// @notice The owner chain ID.
    uint64 public l1ChainId; // slot 1

    /// @notice The security council who can directly call `invokeCall`.
    address public admin;

    /// @notice The next transaction ID.
    uint64 public nextTxId; // slot 2

    /// @notice The real owner on L1, supposedly the DAO.
    address public realOwner;

    uint256[48] private __gap;

    struct Call {
        uint64 txId;
        address target;
        bool isDelegateCall;
        bytes txdata;
    }

    /// @notice Emitted when a message is invoked.
    /// @param txId The transaction ID.
    /// @param target The target address.
    /// @param isDelegateCall True if the call is a `delegatecall`.
    /// @param selector The function selector.
    event MessageInvoked(
        uint64 indexed txId, address indexed target, bool isDelegateCall, bytes4 indexed selector
    );

    /// @notice Emitted when the admin has been changed.
    /// @param oldAdmin The old admin address.
    /// @param newAdmin The new admin address.
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);

    error DO_DRYRUN_SUCCEEDED();
    error DO_INVALID_PARAM();
    error DO_INVALID_TARGET();
    error DO_INVALID_TX_ID();
    error DO_PERMISSION_DENIED();
    error DO_TARGET_CALL_REVERTED();

    /// @notice Initializes the contract.
    /// @param _realOwner The real owner on L1 that can send a cross-chain message to invoke
    /// `onMessageInvocation`.
    /// @param _l1ChainId The L1 chain's ID.
    /// @param _addressManager The address of the {AddressManager} contract.
    /// @param _admin The security council address.
    function init(
        address _realOwner,
        address _addressManager,
        uint64 _l1ChainId,
        address _admin
    )
        external
        initializer
    {
        // This contract's owner will be itself.
        __Essential_init(address(this), _addressManager);

        if (_realOwner == address(0) || _l1ChainId == 0 || _l1ChainId == block.chainid) {
            revert DO_INVALID_PARAM();
        }

        l1ChainId = _l1ChainId;
        realOwner = _realOwner;
        admin = _admin;
    }

    /// @inheritdoc IMessageInvocable
    /// @dev Do not guard with nonReentrant as this function may re-enter the contract as _data
    /// represents calls to address(this).
    function onMessageInvocation(bytes calldata _data)
        external
        payable
        onlyFromNamed(LibStrings.B_BRIDGE)
    {
        IBridge.Context memory ctx = IBridge(msg.sender).context();
        if (ctx.srcChainId != l1ChainId || ctx.from != realOwner) {
            revert DO_PERMISSION_DENIED();
        }
        _invokeCall(_data, true);
    }

    /// @dev Invokes a call by the security council
    /// @param _data The data for this contract to interpret.
    function invokeCall(bytes calldata _data) external {
        if (msg.sender != admin) revert DO_PERMISSION_DENIED();
        _invokeCall(_data, true);
    }

    /// @dev Updates the security council address.
    /// @param _admin The new security council address.
    function setAdmin(address _admin) external {
        if (msg.sender != owner() && msg.sender != admin) revert DO_PERMISSION_DENIED();
        if (admin == _admin) revert DO_INVALID_PARAM();

        emit AdminUpdated(admin, _admin);
        admin = _admin;
    }

    /// @notice Dryruns a message invocation but always revert.
    /// If this tx is reverted with DO_TRY_RUN_SUCCEEDED, the try run is successful.
    /// Note that this function shall not be used in transaction and is designed for offchain
    /// simulation only.
    function dryrunCall(bytes calldata _data) external payable {
        _invokeCall(_data, false);
        revert DO_DRYRUN_SUCCEEDED();
    }

    function acceptOwnership(address target) external {
        Ownable2StepUpgradeable(target).acceptOwnership();
    }

    function transferOwnership(address) public pure override notImplemented { }

    function _authorizePause(address, bool) internal pure override notImplemented { }

    function _invokeCall(bytes calldata _data, bool _verifyTxId) internal {
        Call memory call = abi.decode(_data, (Call));

        if (_verifyTxId && call.txId != nextTxId++) revert DO_INVALID_TX_ID();

        // By design, the target must be a contract address.
        if (!Address.isContract(call.target)) revert DO_INVALID_TARGET();

        (bool success, bytes memory result) = call.isDelegateCall //
            ? call.target.delegatecall(call.txdata)
            : call.target.call{ value: msg.value }(call.txdata);

        if (!success) LibBytes.revertWithExtractedError(result);
        emit MessageInvoked(call.txId, call.target, call.isDelegateCall, bytes4(call.txdata));
    }
}
