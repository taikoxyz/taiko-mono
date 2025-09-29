// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IPreconfSlasherL2.sol";
import "../based/ShastaAnchor.sol";
import "src/shared/common/EssentialResolverContract.sol";
import "src/shared/bridge/IBridge.sol";
import "src/shared/libs/LibNames.sol";
import "src/shared/libs/LibNetwork.sol";

/// @title PreconfSlasherL2
/// @notice PreconfSlasherL2 is a smart contract that validates preconfirmations on Layer 2
/// and forwards slashing requests to the L1 preconfirmation slasher contract when violations
/// are detected. It handles liveness and safety preconfirmation faults.
/// @dev This contract acts as the L2 component of the preconfirmation slashing system.
/// @custom:security-contact security@taiko.xyz
contract PreconfSlasherL2 is IPreconfSlasherL2, EssentialResolverContract {
    address public immutable preconfSlasherL1;
    address public immutable taikoAnchor;

    constructor(
        address _resolver,
        address _preconfSlasherL1,
        address _taikoAnchor
    )
        EssentialResolverContract(_resolver)
    {
        preconfSlasherL1 = _preconfSlasherL1;
        taikoAnchor = _taikoAnchor;
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

        // Pull the preconf metadata for the block proposed at the preconfirmation height
        ShastaAnchor.PreconfMeta memory preconfMeta =
            ShastaAnchor(taikoAnchor).getPreconfMeta(preconfirmation.blockNumber);

        // The parent preconfirmation must not have been messed up during submission
        require(
            preconfirmation.parentRawTxListHash == preconfMeta.parentRawTxListHash,
            ParentRawTxListHashMismatch()
        );
        require(
            preconfirmation.parentSubmissionWindowEnd == preconfMeta.parentSubmissionWindowEnd,
            ParentSubmissionWindowEndMismatch()
        );

        if (_fault == Fault.Liveness) {
            _validateLivenessFault(preconfirmation, preconfMeta);
        } else {
            _validateSafetyFault(preconfirmation, preconfMeta);
        }

        _invokePreconfSlasherL1(_fault, _registrationRoot, _signedCommitment);
    }

    // Internal functions
    // ---------------------------------------------------------------

    function _validateLivenessFault(
        Preconfirmation memory _preconfirmation,
        ShastaAnchor.PreconfMeta memory _preconfMeta
    )
        internal
        view
    {
        // If the block was submitted in the future, we may have a missed submission.
        // Else, we may have a missing EOP
        if (_preconfirmation.submissionWindowEnd > _preconfMeta.submissionWindowEnd) {
            // EOP-only preconfirmations are not required to be submitted
            require(
                !(_preconfirmation.eop == true && _preconfirmation.rawTxListHash == bytes32(0)),
                NotALivenessFault()
            );

            // Note: Uncomment if we want to allow missed proposal recovery by the next preconfer
            // require(
            //     !(
            //         _preconfirmation.rawTxListHash == _preconfMeta.rawTxListHash
            //             && uint48(_preconfirmation.anchorBlockNumber) ==
            // _preconfMeta.anchorBlockNumber
            //     ),
            //     NotALivenessFault()
            // );
        } else {
            // EOP flag must be missing
            require(!_preconfirmation.eop, InvalidEOPFlag());

            // The preconfirmation and the submission must be in the same window
            require(
                _preconfirmation.submissionWindowEnd == _preconfMeta.submissionWindowEnd,
                UnexpectedExtraProposalsInPreviousWindow()
            );

            // Next block must be submitted in the next window
            ShastaAnchor.PreconfMeta memory nextPreconfMeta =
                ShastaAnchor(taikoAnchor).getPreconfMeta(_preconfirmation.blockNumber + 1);
            require(
                nextPreconfMeta.submissionWindowEnd > _preconfirmation.submissionWindowEnd,
                NotALivenessFault()
            );
        }
    }

    function _validateSafetyFault(
        Preconfirmation memory _preconfirmation,
        ShastaAnchor.PreconfMeta memory _preconfMeta
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
            ShastaAnchor.PreconfMeta memory nextPreconfMeta =
                ShastaAnchor(taikoAnchor).getPreconfMeta(_preconfirmation.blockNumber + 1);
            require(
                _preconfirmation.rawTxListHash == bytes32(0)
                    || _preconfirmation.submissionWindowEnd == nextPreconfMeta.submissionWindowEnd,
                NotASafetyFault()
            );
        }
    }

    /// @dev Invokes a call to L1 preconf slasher's onMessageInvocation(bytes) via the bridge
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
            to: preconfSlasherL1,
            value: 0,
            data: callData
        });

        IBridge(resolve(LibNames.B_BRIDGE, false)).sendMessage(message);
    }
}
