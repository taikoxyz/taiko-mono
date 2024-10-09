// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../../../shared/common/EssentialContract.sol";
import "../../based/ITaikoL1.sol";
import "../libs/LibNames.sol";
import "../libs/LibBlockHeader.sol";
import "../iface/IPreconfServiceManager.sol";
import "../iface/IPreconfTaskManager.sol";

/// @title PreconfTaskManager
/// @custom:security-contact security@taiko.xyz
abstract contract PreconfTaskManager is IPreconfTaskManager, EssentialContract {
    uint256[50] private __gap;

    error SenderNotCurrentPreconfer();

    /// @notice Modifier to update the lookahead and ensure the caller is the current preconfer
    /// @param _lookaheadParams Encoded parameters to set lookahead
    modifier checkCurrentPreconferAndPostLookahead(
        uint256 _lookaheadPointer,
        ILookahead.EntryParam[] calldata _lookaheadParams
    ) {
        ILookahead lookahead = _lookahead();
        require(
            lookahead.isCurrentPreconfer(_lookaheadPointer, msg.sender), SenderNotCurrentPreconfer()
        );

        // Conditionally post a new lookahead to the lookahead contract
        lookahead.postLookahead(_lookaheadParams);

        _;
    }

    /// @notice Initializes the contract.
    function init(address _owner, address _preconfAddressManager) external initializer {
        __Essential_init(_owner, _preconfAddressManager);
    }

    /// @inheritdoc IPreconfTaskManager
    function proposeBlock(
        uint256 _lookaheadPointer,
        ILookahead.EntryParam[] calldata _lookaheadParams,
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        checkCurrentPreconferAndPostLookahead(_lookaheadPointer, _lookaheadParams)
        nonReentrant
        returns (TaikoData.BlockMetadataV2 memory)
    {
        return _taiko().proposeBlockV2(_params, _txList);
    }

    /// @inheritdoc IPreconfTaskManager
    function proposeBlocks(
        uint256 _lookaheadPointer,
        ILookahead.EntryParam[] calldata _lookaheadParams,
        bytes[] calldata _paramsArr,
        bytes[] calldata _txListArr
    )
        external
        checkCurrentPreconferAndPostLookahead(_lookaheadPointer, _lookaheadParams)
        nonReentrant
        returns (TaikoData.BlockMetadataV2[] memory)
    {
        return _taiko().proposeBlocksV2(_paramsArr, _txListArr);
    }

    /// @inheritdoc IPreconfTaskManager
    function proveReceiptViolation(
        IReceiptProver.Receipt calldata _receipt,
        bytes calldata _proof
    )
        external
        nonReentrant
    {
        address preconfer = _receiptProver().proveReceiptViolation(_receipt, _proof);
        _preconfServiceManager().slashOperator(preconfer);
    }

    // --- internal/private helper functions
    // ----------------------------------------------------------

    function _preconfServiceManager() private view returns (IPreconfServiceManager) {
        return IPreconfServiceManager(resolve(LibNames.B_PRECONF_SERVICE_MANAGER, false));
    }

    function _receiptProver() private view returns (IReceiptProver) {
        return IReceiptProver(resolve(LibNames.B_RECEIPT_PROVER, false));
    }

    function _lookahead() private view returns (ILookahead) {
        return ILookahead(resolve(LibNames.B_LOOKAHEAD, false));
    }

    function _taiko() private view returns (ITaikoL1) {
        return ITaikoL1(resolve(LibNames.B_TAIKO, false));
    }
}
