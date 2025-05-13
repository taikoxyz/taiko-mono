// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoInbox.sol";
import "src/layer1/based/IProposeBatch.sol";
import "src/shared/common/EssentialContract.sol";
import "src/layer1/preconf/iface/ILookaheadStore.sol";
import "src/layer1/preconf/iface/IPreconfWhitelist.sol";
import "src/layer1/preconf/libs/LibPreconfUtils.sol";
import "@eth-fabric/urc/IRegistry.sol";

/// @title PreconfRouter2
/// @custom:security-contact security@taiko.xyz
contract PreconfRouter2 is EssentialContract, IProposeBatch {
    ILookaheadStore public immutable lookaheadStore;
    IPreconfWhitelist public immutable preconfWhitelist;
    IProposeBatch public immutable iProposeBatch;
    IRegistry public immutable urc;
    address public immutable preconfSlasher;
    address public immutable fallbackPreconfer;

    uint256[50] private __gap;

    error ForcedInclusionNotSupported();
    error InvalidCurrentLookahead();
    error InvalidLookaheadProof();
    error InvalidLookaheadTimestamp();
    error InvalidPreviousLookahead();
    error NotPreconfer();
    error NotPreconferOrFallback();
    error OperatorIsNotOptedIn();
    error OperatorIsSlashed();
    error OperatorIsUnregistered();
    error ProposerIsNotPreconfer();

    constructor(
        address _lookaheadStore,
        address _preconfWhitelist,
        address _iProposeBatch,
        address _preconfSlasher,
        address _urc,
        address _fallbackPreconfer
    )
        EssentialContract(address(0))
    {
        lookaheadStore = ILookaheadStore(_lookaheadStore);
        preconfWhitelist = IPreconfWhitelist(_preconfWhitelist);
        iProposeBatch = IProposeBatch(_iProposeBatch);
        preconfSlasher = _preconfSlasher;
        urc = IRegistry(_urc);
        fallbackPreconfer = _fallbackPreconfer;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IProposeBatch
    function v4ProposeBatch(
        bytes calldata _params,
        bytes calldata _txList,
        bytes calldata _lookaheadData
    )
        external
        nonReentrant
        returns (ITaikoInbox.BatchInfo memory info_, ITaikoInbox.BatchMetadata memory meta_)
    {
        uint256 epochTimestamp = LibPreconfUtils.getEpochTimestamp();
        bytes26 currentLookaheadHash = lookaheadStore.getLookaheadHash(epochTimestamp);

        // Try fetching the lookahead for the next epoch.
        // This call fails if the lookahead for next epoch is not posted, thus requiring the first
        // preconfer to post the next epoch's lookahead before proposing a batch in the current
        // epoch.
        lookaheadStore.getLookaheadHash(epochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH);

        if (_isEmptyLookahead(epochTimestamp, currentLookaheadHash)) {
            // The current lookahead is empty, so we use a whitelisted preconfer
            _validateWhitelistPreconfer();
        } else {
            // We validate the provided lookahead data and confirm if the sender is the preconfer
            // within the lookahead
            (
                uint256 currentLookaheadIndex,
                ILookaheadStore.LookaheadSlot[] memory previousLookahead,
                ILookaheadStore.LookaheadSlot[] memory currentLookahead
            ) = abi.decode(
                _lookaheadData,
                (uint256, ILookaheadStore.LookaheadSlot[], ILookaheadStore.LookaheadSlot[])
            );

            ILookaheadStore.LookaheadSlot memory lookaheadSlot =
                currentLookahead[currentLookaheadIndex];

            _validatePreconfingPeriod(
                epochTimestamp,
                currentLookaheadIndex,
                currentLookaheadHash,
                previousLookahead,
                currentLookahead,
                lookaheadSlot
            );

            _validateProposer(lookaheadSlot);
        }

        // Both TaikoInbox and TaikoWrapper implement the same ABI for IProposeBatch.
        (info_, meta_) = iProposeBatch.v4ProposeBatch(_params, _txList, hex"");

        // Verify that the sender had set itself as the proposer
        require(info_.proposer == msg.sender, ProposerIsNotPreconfer());
    }

    // Internal functions ----------------------------------------------------------------------

    function _validateWhitelistPreconfer() internal view {
        require(
            msg.sender == fallbackPreconfer
                || msg.sender == preconfWhitelist.getOperatorForCurrentEpoch(),
            NotPreconferOrFallback()
        );
    }

    /// @dev Validates if the sender has proposing rights for the current slot
    function _validateProposer(ILookaheadStore.LookaheadSlot memory _lookaheadSlot) internal view {
        // Sender must be the expected committer (i.e the preconfer) for the current preconfing
        // period
        require(msg.sender == _lookaheadSlot.committer, ProposerIsNotPreconfer());

        // Ensure that the associated operator is active and opted into the preconf slasher
        IRegistry.OperatorData memory operatorData =
            urc.getOperatorData(_lookaheadSlot.registrationRoot);
        require(operatorData.slashedAt == 0, OperatorIsSlashed());
        require(operatorData.unregisteredAt == 0, OperatorIsUnregistered());
        require(
            urc.isOptedIntoSlasher(_lookaheadSlot.registrationRoot, preconfSlasher),
            OperatorIsNotOptedIn()
        );
    }

    /// @dev Validates if the provided lookahead data points to the current preconfing period.
    function _validatePreconfingPeriod(
        uint256 _epochTimestamp,
        uint256 _currentLookaheadIndex,
        bytes26 _currentLookaheadHash,
        ILookaheadStore.LookaheadSlot[] memory _previousLookahead,
        ILookaheadStore.LookaheadSlot[] memory _currentLookahead,
        ILookaheadStore.LookaheadSlot memory _lookaheadSlot
    )
        internal
        view
    {
        // Validate the current lookahead data
        require(
            LibPreconfUtils.calculateLookaheadHash(_epochTimestamp, _currentLookahead)
                == _currentLookaheadHash,
            InvalidCurrentLookahead()
        );

        if (_currentLookaheadIndex != 0) {
            // This is the case when the preconfer does not have the first preconfing slot in this
            // epoch.
            //
            // Eg: [ x x x x Pa x x x Pb x x x]
            // - Pb is our preconfer for this epoch.
            // - Pa is the preconfer at `previousLookaheadSlot`.
            // - x represents empty slots with no opted in preconfer.

            ILookaheadStore.LookaheadSlot memory previousLookaheadSlot =
                _currentLookahead[_currentLookaheadIndex - 1];

            // Validate the preconfing period
            require(
                block.timestamp > previousLookaheadSlot.slotTimestamp
                    && block.timestamp <= _lookaheadSlot.slotTimestamp,
                InvalidLookaheadTimestamp()
            );
        } else {
            // This is the case when the preconfer does have the first preconfing slot in this
            // epoch.
            //
            // Eg: [ prev-epoch ] [ x x x Pa x x x ]
            // - Pa is our preconfer for this epoch.
            // - x represents empty slots with no opted in preconfer.
            //
            // This opens up three scenarios:
            // 1. prev-epoch lookahead had 1 or more preconfers
            // 2. prev-epoch lookahead was empty
            // 3. prev-epoch lookahead was not posted
            //
            // For case 2 and 3, we leave _previousLookahead as an empty array.

            if (_previousLookahead.length != 0) {
                // Validate previous lookahead data
                uint256 previousEpochTimestamp =
                    _epochTimestamp - LibPreconfConstants.SECONDS_IN_EPOCH;
                bytes26 previousLookaheadHash =
                    lookaheadStore.getLookaheadHash(previousEpochTimestamp);
                require(
                    LibPreconfUtils.calculateLookaheadHash(
                        previousEpochTimestamp, _previousLookahead
                    ) == previousLookaheadHash,
                    InvalidPreviousLookahead()
                );

                ILookaheadStore.LookaheadSlot memory previousLookaheadSlot =
                    _previousLookahead[_previousLookahead.length - 1];

                // Validate the preconfing period for case 1
                require(
                    block.timestamp > previousLookaheadSlot.slotTimestamp
                        && block.timestamp <= _lookaheadSlot.slotTimestamp,
                    InvalidLookaheadTimestamp()
                );
            } else {
                // Validate the preconfing period case 2 and 3
                require(
                    block.timestamp >= _epochTimestamp
                        && block.timestamp <= _lookaheadSlot.slotTimestamp,
                    InvalidLookaheadTimestamp()
                );
            }
        }
    }

    function _isEmptyLookahead(
        uint256 _epochTimestamp,
        bytes26 _lookaheadHash
    )
        internal
        pure
        returns (bool)
    {
        return _lookaheadHash
            == LibPreconfUtils.calculateLookaheadHash(
                _epochTimestamp, new ILookaheadStore.LookaheadSlot[](0)
            );
    }
}
