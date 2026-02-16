// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Anchor } from "src/layer2/core/Anchor.sol";
import { IBridge, IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { IPreconfSlasher } from "src/shared/preconf/IPreconfSlasher.sol";

import "./PreconfSlasherL2_Layout.sol"; // DO NOT DELETE

/// @title PreconfSlasherL2
/// @notice PreconfSlasherL2 is a smart contract that validates preconfirmations on Layer 2
/// and forwards slashing requests to the L1 preconfirmation slasher contract when violations
/// are detected. It handles liveness and safety preconfirmation faults.
/// @dev This contract acts as the L2 component of the preconfirmation slashing system.
/// @custom:security-contact security@taiko.xyz
contract PreconfSlasherL2 is EssentialContract {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @dev A Commitment message binding an opaque payload to a slasher contract.
    /// Extracted from URC's `ISlasher` to enable compilation to Shanghai.
    struct Commitment {
        uint64 commitmentType;
        bytes payload;
        address slasher;
    }

    /// @dev A commitment message signed by a delegate's ECDSA key.
    /// Extracted from URC's `ISlasher` to enable compilation to Shanghai.
    struct SignedCommitment {
        Commitment commitment;
        bytes signature;
    }

    // ---------------------------------------------------------------
    // Immutables
    // ---------------------------------------------------------------

    address public immutable preconfSlasherL1;
    address public immutable anchor;
    address public immutable bridge;

    constructor(
        address _preconfSlasherL1,
        address _anchor,
        address _bridge
    )
        EssentialContract()
    {
        preconfSlasherL1 = _preconfSlasherL1;
        anchor = _anchor;
        bridge = _bridge;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @dev Validates if a preconfirmation is slashable and forwards the fault to the
    /// L1 preconfirmation slasher.
    function slash(
        IPreconfSlasher.PreconfirmationFault _fault,
        bytes32 _registrationRoot,
        SignedCommitment calldata _signedCommitment
    )
        external
    {
        IPreconfSlasher.Preconfirmation memory preconfirmation =
            abi.decode(_signedCommitment.commitment.payload, (IPreconfSlasher.Preconfirmation));

        Anchor.PreconfMetadata memory preconfMetadata =
            Anchor(anchor).getPreconfMetadata(preconfirmation.blockNumber);

        // The parent preconfirmation must not have been messed up during submission
        require(
            preconfirmation.parentRawTxListHash == preconfMetadata.parentRawTxListHash,
            ParentRawTxListHashMismatch()
        );
        require(
            preconfirmation.parentSubmissionWindowEnd == preconfMetadata.parentSubmissionWindowEnd,
            ParentSubmissionWindowEndMismatch()
        );

        if (_fault == IPreconfSlasher.PreconfirmationFault.Liveness) {
            _validateLivenessFault(preconfirmation, preconfMetadata);
        } else {
            _validateSafetyFault(preconfirmation, preconfMetadata);
        }

        _invokePreconfSlasherL1(_fault, _registrationRoot, _signedCommitment);
    }

    // Internal functions
    // ---------------------------------------------------------------

    /// @dev Validates a liveness fault. This covers both missed submissions and missing EOP.
    function _validateLivenessFault(
        IPreconfSlasher.Preconfirmation memory _preconfirmation,
        Anchor.PreconfMetadata memory _preconfMeta
    )
        internal
        view
    {
        // If the block was submitted in a future window, we may have a missed submission.
        // Else, we may have a missing EOP.
        if (_preconfirmation.submissionWindowEnd > _preconfMeta.submissionWindowEnd) {
            // EOP-only preconfirmations are not required to be submitted
            require(
                !(_preconfirmation.eop == true && _preconfirmation.rawTxListHash == bytes32(0)),
                NotALivenessFault()
            );
        } else {
            // EOP flag must be missing
            require(!_preconfirmation.eop, InvalidEOPFlag());

            // The preconfirmation and the submission must be in the same window
            require(
                _preconfirmation.submissionWindowEnd == _preconfMeta.submissionWindowEnd,
                UnexpectedExtraProposalsInPreviousWindow()
            );

            // Next block must be submitted in the next window
            Anchor.PreconfMetadata memory nextPreconfMeta =
                Anchor(anchor).getPreconfMetadata(_preconfirmation.blockNumber + 1);
            require(
                nextPreconfMeta.submissionWindowEnd > _preconfirmation.submissionWindowEnd,
                NotALivenessFault()
            );
        }
    }

    /// @dev Validates a safety fault. This covers raw tx list hash / anchor block mismatches
    /// and invalid EOP.
    function _validateSafetyFault(
        IPreconfSlasher.Preconfirmation memory _preconfirmation,
        Anchor.PreconfMetadata memory _preconfMeta
    )
        internal
        view
    {
        // The submission must have landed in the assigned window
        require(
            _preconfirmation.submissionWindowEnd == _preconfMeta.submissionWindowEnd,
            NotASafetyFault()
        );

        if (
            _preconfirmation.rawTxListHash != _preconfMeta.rawTxListHash
                || uint48(_preconfirmation.anchorBlockNumber) != _preconfMeta.anchorBlockNumber
        ) {
            // No further checks required. This is a slashable preconfirmation.
        } else {
            // EOP flag must be present
            require(_preconfirmation.eop, InvalidEOPFlag());

            // Either an EOP-only preconfirmation is violated or an extra block is submitted
            // in the same window
            Anchor.PreconfMetadata memory nextPreconfMeta =
                Anchor(anchor).getPreconfMetadata(_preconfirmation.blockNumber + 1);
            require(
                _preconfirmation.rawTxListHash == bytes32(0)
                    || _preconfirmation.submissionWindowEnd == nextPreconfMeta.submissionWindowEnd,
                NotASafetyFault()
            );
        }
    }

    /// @dev Invokes a call to L1 preconf slasher's onMessageInvocation(bytes) via the bridge
    function _invokePreconfSlasherL1(
        IPreconfSlasher.PreconfirmationFault _fault,
        bytes32 _registrationRoot,
        SignedCommitment memory _signedCommitment
    )
        internal
    {
        bytes memory callData = abi.encodeWithSelector(
            IMessageInvocable.onMessageInvocation.selector,
            abi.encode(_fault, _registrationRoot, _signedCommitment)
        );

        uint64 destChainId = Anchor(anchor).l1ChainId();

        IBridge.Message memory message = IBridge.Message({
            id: 0,
            fee: 0,
            gasLimit: 0,
            from: address(0),
            srcChainId: 0,
            srcOwner: msg.sender,
            destChainId: destChainId,
            destOwner: msg.sender,
            to: preconfSlasherL1,
            value: 0,
            data: callData
        });

        IBridge(bridge).sendMessage(message);
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InvalidEOPFlag();
    error NotALivenessFault();
    error NotASafetyFault();
    error ParentRawTxListHashMismatch();
    error ParentSubmissionWindowEndMismatch();
    error UnexpectedExtraProposalsInPreviousWindow();
}
