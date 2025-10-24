// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IPreconfSlasherL2 } from "src/layer2/preconf/IPreconfSlasherL2.sol";
import { ShastaAnchor } from "src/layer2/based/ShastaAnchor.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { IBridge, IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";

/// @title PreconfSlasherL2
/// @notice PreconfSlasherL2 is a smart contract that validates preconfirmations on Layer 2
/// and forwards slashing requests to the L1 preconfirmation slasher contract when violations
/// are detected.
/// @dev This contract acts as the L2 component of the preconfirmation slashing system.
/// @custom:security-contact security@taiko.xyz
contract PreconfSlasherL2 is IPreconfSlasherL2, EssentialContract {
    address public immutable unifiedSlasher;
    address public immutable taikoAnchor;
    address public immutable bridge;

    constructor(
        address _unifiedSlasher,
        address _taikoAnchor,
        address _bridge
    )
        EssentialContract()
    {
        unifiedSlasher = _unifiedSlasher;
        taikoAnchor = _taikoAnchor;
        bridge = _bridge;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IPreconfSlasherL2
    function slash(
        Fault _fault,
        bytes32 _registrationRoot,
        SignedCommitment calldata _signedCommitment
    )
        external
    {
        Preconfirmation memory preconfirmation =
            abi.decode(_signedCommitment.commitment.payload, (Preconfirmation));

        ShastaAnchor.PreconfMeta memory preconfMeta =
            ShastaAnchor(taikoAnchor).getPreconfMeta(preconfirmation.blockNumber);

        if (_fault == Fault.MissedSubmission) {
            _validateMissedSubmissionFault(preconfirmation, preconfMeta);
        } else if (_fault == Fault.MissingEOP) {
            _validateMissingEOPFault(preconfirmation, preconfMeta);
        } else if (_fault == Fault.RawTxListHashOrAnchorBlockMismatch) {
            _validateRawTxListHashOrAnchorBlockMismatchFault(preconfirmation, preconfMeta);
        } else if (_fault == Fault.InvalidEOP) {
            _validateInvalidEOPFault(preconfirmation, preconfMeta);
        }

        _invokePreconfSlasherL1(_fault, _registrationRoot, _signedCommitment);
    }

    // Internal functions
    // ---------------------------------------------------------------

    /// @dev Validates that a preconfirmation was never submitted to the inbox.
    function _validateMissedSubmissionFault(
        Preconfirmation memory _preconfirmation,
        ShastaAnchor.PreconfMeta memory _preconfMeta
    )
        internal
        view
    {
        // EOP-only preconfirmations are not expected to be submitted
        require(
            !_isEOPOnlyPreconfirmation(_preconfirmation),
            EOPOnlyPreconfirmationDoesNotRequireSubmission()
        );

        // The block at preconfirmation height must be submitted in a future submission window
        require(
            _preconfMeta.submissionWindowEnd > _preconfirmation.submissionWindowEnd,
            NotAMissedSubmission()
        );
    }

    /// @dev Validates that the last preconfirmation in the assigned window does not have
    /// the eop flag set to true
    function _validateMissingEOPFault(
        Preconfirmation memory _preconfirmation,
        ShastaAnchor.PreconfMeta memory _preconfMeta
    )
        internal
        view
    {
        // EOP flag must be missing
        require(!_preconfirmation.eop, InvalidEOPFlag());

        // Protection against a scenario where the previous preconfer submitted an extra
        // block that it never preconfirmed.
        require(
            _preconfirmation.submissionWindowEnd == _preconfMeta.submissionWindowEnd,
            UnexpectedExtraProposalsInPreviousWindow()
        );

        // Confirm that the block with missing EOP is the last block in it's
        // submission window
        ShastaAnchor.PreconfMeta memory nextPreconfMeta =
            ShastaAnchor(taikoAnchor).getPreconfMeta(_preconfirmation.blockNumber + 1);
        require(
            nextPreconfMeta.submissionWindowEnd > _preconfirmation.submissionWindowEnd,
            NotALivenessFault()
        );
    }

    /// @dev Validates that the tx list hash or the anchor block values on the preconfirmation
    /// does not match the submitted values
    function _validateRawTxListHashOrAnchorBlockMismatchFault(
        Preconfirmation memory _preconfirmation,
        ShastaAnchor.PreconfMeta memory _preconfMeta
    )
        internal
        view
    {
        // Protection against a scenario where a previous preconfer submitted an extra block
        // that it never preconfirmed.
        require(
            _preconfirmation.parentRawTxListHash == _preconfMeta.parentRawTxListHash,
            ParentRawTxListHashMismatch()
        );

        // Protection against a scenario where a previous preconfer submitted an extra block
        // with the same `rawTxListHash` as the one preconfirmed by the current preconfer.
        require(
            _preconfirmation.parentSubmissionWindowEnd == _preconfMeta.parentSubmissionWindowEnd,
            ParentSubmissionWindowEndMismatch()
        );

        // The submission must have landed in the assigned window, otherwise it may be a
        // potential `MissedSubmissionFault`
        require(
            _preconfirmation.submissionWindowEnd == _preconfMeta.submissionWindowEnd,
            SubmissionWindowMismatch()
        );

        require(
            _preconfirmation.rawTxListHash != _preconfMeta.rawTxListHash
                || uint48(_preconfirmation.anchorBlockNumber) != _preconfMeta.anchorBlockNumber,
            NotARawTxListHashOrAnchorBlockMismatch()
        );
    }

    /// @dev Validates that a non-terminal preconfirmation has it's eop flag set to true
    function _validateInvalidEOPFault(
        Preconfirmation memory _preconfirmation,
        ShastaAnchor.PreconfMeta memory _preconfMeta
    )
        internal
        view
    {
        // The submission must have landed in the assigned window, otherwise it may be a
        // potential `MissedSubmissionFault`
        require(
            _preconfirmation.submissionWindowEnd == _preconfMeta.submissionWindowEnd,
            SubmissionWindowMismatch()
        );

        // EOP flag must be present
        require(_preconfirmation.eop, InvalidEOPFlag());

        // If it's an EOP-only preconfirmation, we already have enough evidence for a violation
        // (i.e a block is proposed in the window where an EOP-only preconfirmation was issued).
        // Otherwise, validate that another block was submitted in the same window after issuing
        // an EOP
        if (_preconfirmation.rawTxListHash != bytes32(0)) {
            ShastaAnchor.PreconfMeta memory nextPreconfMeta =
                ShastaAnchor(taikoAnchor).getPreconfMeta(_preconfirmation.blockNumber + 1);
            require(
                nextPreconfMeta.submissionWindowEnd == _preconfirmation.submissionWindowEnd,
                NotAnInvalidEOP()
            );
        }
    }

    /// @dev EOP-only preconfirmations are issued when the preconfer does not intend to
    /// preconf even a single block in its assigned window.
    function _isEOPOnlyPreconfirmation(Preconfirmation memory _preconfirmation)
        internal
        view
        returns (bool)
    {
        return (_preconfirmation.eop && _preconfirmation.rawTxListHash == bytes32(0));
    }

    /// @dev Invokes a call to L1 preconf slasher's onMessageInvocation(bytes) via the bridge
    /// @dev The invocation happens on the `UnifiedSlasher` on L1 which further delegatecalls
    /// to `PreconfSlasherL1`
    function _invokePreconfSlasherL1(
        Fault _fault,
        bytes32 _registrationRoot,
        SignedCommitment memory _signedCommitment
    )
        internal
    {
        bytes memory callData = abi.encodeWithSelector(
            IMessageInvocable.onMessageInvocation.selector,
            abi.encode(_fault, _registrationRoot, _signedCommitment)
        );

        IBridge.Message memory message = IBridge.Message({
            id: 0,
            fee: 0,
            gasLimit: 0,
            from: address(0),
            srcChainId: 0,
            srcOwner: msg.sender,
            destChainId: uint64(LibNetwork.ETHEREUM_MAINNET),
            destOwner: msg.sender,
            to: unifiedSlasher,
            value: 0,
            data: callData
        });

        IBridge(bridge).sendMessage(message);
    }
}
