// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibNames.sol";
import "src/shared/libs/LibAddress.sol";
import "src/shared/libs/LibBytes.sol";
import "src/shared/bridge/IBridge.sol";

/// @title DelegateOwner
/// @notice This contract will be the owner of all essential contracts deployed on the L2 chain.
/// @dev Notice that when sending the message on the owner chain, the gas limit of the message must
/// not be zero, so on this chain, some EOA can help execute this transaction.
/// @dev This contract is used by Hekla and can be upgraded to DelegateController.
/// @custom:security-contact security@taiko.xyz
contract DelegateOwner is EssentialContract, IMessageInvocable {
    address public immutable l2Bridge;
    address public immutable daoController;
    uint64 public immutable l1ChainId;

    // Was remoteChainId + admin before being immutable
    uint256 public __deprecated;

    /// @notice The next transaction ID.
    uint64 public nextTxId; // slot 2

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

    error DO_DRYRUN_SUCCEEDED();
    error DO_INVALID_SENDER();
    error DO_INVALID_TARGET();
    error DO_INVALID_TX_ID();
    error DO_PERMISSION_DENIED();

    constructor(uint64 _l1ChainId, address _l2Bridge, address _daoController) {
        l1ChainId = _l1ChainId;
        l2Bridge = _l2Bridge;
        daoController = _daoController;
    }

    function init() external initializer {
        __Essential_init(address(this));
    }

    /// @inheritdoc IMessageInvocable
    function onMessageInvocation(bytes calldata _data) external payable {
        require(msg.sender == l2Bridge, DO_INVALID_SENDER());

        IBridge.Context memory ctx = IBridge(msg.sender).context();
        require(ctx.srcChainId == l1ChainId && ctx.from == daoController, DO_PERMISSION_DENIED());

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

    /// @notice Accept ownership of the given contract.
    /// @dev This function is callable by anyone to accept ownership without going through
    /// the TaikoDAO.
    /// @param _contractToOwn The contract to accept ownership of.
    function acceptOwnership(address _contractToOwn) external nonReentrant {
        Ownable2StepUpgradeable(_contractToOwn).acceptOwnership();
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
        require(call.txdata.length == 0 || Address.isContract(call.target), DO_INVALID_TARGET());

        (bool success, bytes memory result) = call.isDelegateCall //
            ? call.target.delegatecall(call.txdata)
            : call.target.call{ value: msg.value }(call.txdata);

        if (!success) LibBytes.revertWithExtractedError(result);

        emit MessageInvoked(call.txId, call.target, call.isDelegateCall, call.txdata);
    }
}
