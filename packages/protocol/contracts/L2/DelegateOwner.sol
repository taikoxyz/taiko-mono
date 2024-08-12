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
    uint64 public remoteChainId; // slot 1

    /// @notice The admin who can directly call `invokeCall`.
    address public admin;

    /// @notice The next transaction ID.
    uint64 public nextTxId; // slot 2

    /// @notice The real owner on L1, supposedly the DAO.
    address public remoteOwner;

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
    /// @param txdata The transaction data.
    event MessageInvoked(
        uint64 indexed txId, address indexed target, bool isDelegateCall, bytes txdata
    );

    /// @notice Emitted when the admin has been changed.
    /// @param oldAdmin The old admin address.
    /// @param newAdmin The new admin address.
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);

    error DO_DRYRUN_SUCCEEDED();
    error DO_INVALID_PARAM();
    error DO_INVALID_SENDER();
    error DO_INVALID_TARGET();
    error DO_INVALID_TX_ID();
    error DO_PERMISSION_DENIED();

    modifier onlyAdminOrRemoteOwner() {
        if (!_isAdminOrRemoteOwner(msg.sender)) revert DO_PERMISSION_DENIED();
        _;
    }

    /// @notice Initializes the contract.
    /// @param _remoteOwner The real owner on L1 that can send a cross-chain message to invoke
    /// `onMessageInvocation`.
    /// @param _remoteChainId The L1 chain's ID.
    /// @param _sharedAddressManager The address of the {AddressManager} contract.
    /// @param _admin The admin address.
    function init(
        address _remoteOwner,
        address _sharedAddressManager,
        uint64 _remoteChainId,
        address _admin
    )
        external
        initializer
    {
        // This contract's owner will be itself.
        __Essential_init(address(this), _sharedAddressManager);

        if (_remoteOwner == address(0) || _remoteChainId == 0 || _remoteChainId == block.chainid) {
            revert DO_INVALID_PARAM();
        }

        remoteChainId = _remoteChainId;
        remoteOwner = _remoteOwner;
        admin = _admin;
    }

    /// @inheritdoc IMessageInvocable
    function onMessageInvocation(bytes calldata _data) external payable onlyAdminOrRemoteOwner {
        _invokeCall(_data, true);
    }

    /// @notice Dryruns a message invocation but always revert.
    /// If this tx is reverted with DO_TRY_RUN_SUCCEEDED, the try run is successful.
    /// Note that this function shall not be used in transaction and is designed for offchain
    /// simulation only.
    function dryrunInvocation(bytes calldata _data) external payable {
        _invokeCall(_data, false);
        revert DO_DRYRUN_SUCCEEDED();
    }

    /// @dev Updates the admin address.
    /// @param _admin The new admin address.
    function setAdmin(address _admin) external nonReentrant onlyOwner {
        if (_admin == admin || _admin == address(this)) revert DO_INVALID_PARAM();

        emit AdminUpdated(admin, _admin);
        admin = _admin;
    }

    /// @dev Accepts contract ownership
    /// @param _target Target addresses.
    function acceptOwnership(address _target) external nonReentrant onlyOwner {
        Ownable2StepUpgradeable(_target).acceptOwnership();
    }

    function transferOwnership(address) public pure override notImplemented { }

    function _authorizePause(address, bool) internal pure override notImplemented { }

    function _invokeCall(bytes calldata _data, bool _verifyTxId) private {
        Call memory call = abi.decode(_data, (Call));

        if (call.txId == 0) {
            call.txId = nextTxId;
        } else if (_verifyTxId && call.txId != nextTxId) {
            revert DO_INVALID_TX_ID();
        }

        nextTxId += 1;

        // By design, the target must be a contract address if the txdata is not empty
        if (call.txdata.length != 0 && !Address.isContract(call.target)) revert DO_INVALID_TARGET();

        (bool success, bytes memory result) = call.isDelegateCall //
            ? call.target.delegatecall(call.txdata)
            : call.target.call{ value: msg.value }(call.txdata);

        if (!success) LibBytes.revertWithExtractedError(result);
        emit MessageInvoked(call.txId, call.target, call.isDelegateCall, call.txdata);
    }

    function _isAdminOrRemoteOwner(address _sender) private view returns (bool) {
        if (_sender == admin) return true;
        if (_sender != resolve(LibStrings.B_BRIDGE, false)) return false;

        IBridge.Context memory ctx = IBridge(_sender).context();
        return ctx.srcChainId == remoteChainId && ctx.from == remoteOwner;
    }
}
