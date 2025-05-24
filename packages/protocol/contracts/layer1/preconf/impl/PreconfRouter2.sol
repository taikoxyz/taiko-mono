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
    error InvalidNextLookahead();
    error InvalidPreviousLookahead();
    error NotPreconfer();
    error NotPreconferOrFallback();
    error OperatorIsNotOptedIn();
    error OperatorIsNotRegistered();
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
        EssentialContract()
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
        (
            uint256 slotIndex,
            ILookaheadStore.LookaheadSlot[] memory currLookahead,
            ILookaheadStore.LookaheadSlot[] memory nextLookahead,
            bytes memory nextLookaheadUpdateData
        ) = abi.decode(
            _lookaheadData,
            (uint256, ILookaheadStore.LookaheadSlot[], ILookaheadStore.LookaheadSlot[], bytes)
        );

        uint256 epochTimestamp = LibPreconfUtils.getEpochTimestamp();

        {
            bytes26 currLookaheadHash = lookaheadStore.getLookaheadHash(epochTimestamp);
            if (currLookaheadHash != 0) {
                _validateLookahead(epochTimestamp, currLookahead, currLookaheadHash);
            }
        }

        {
            // Try fetching the lookahead for the next epoch.
            uint256 nextEpochTimestamp = epochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH;
            bytes26 nextLookaheadHash = lookaheadStore.getLookaheadHash(nextEpochTimestamp);
            if (nextLookaheadHash == 0) {
                // If the lookahead for the next epoch is not posted, we post it here.
                (bytes32 registrationRoot, bytes memory data) =
                    abi.decode(nextLookaheadUpdateData, (bytes32, bytes));
                nextLookaheadHash = lookaheadStore.updateLookahead(registrationRoot, data);
            }
        }

        if (currLookahead.length == 0) {
            // The current lookahead is empty, so we use a whitelisted preconfer
            _validateWhitelistPreconfer();
        } else {
            _validatePreconfingPeriod(epochTimestamp, slotIndex, currLookahead, nextLookahead);

            ILookaheadStore.LookaheadSlot memory _lookaheadSlot =
                slotIndex == type(uint256).max ? nextLookahead[0] : currLookahead[slotIndex];
            _validateProposer(_lookaheadSlot);
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

        require(operatorData.unregisteredAt == 0, OperatorIsUnregistered());
        require(operatorData.slashedAt == 0, OperatorIsSlashed());
        require(
            urc.isOptedIntoSlasher(_lookaheadSlot.registrationRoot, preconfSlasher),
            OperatorIsNotOptedIn()
        );
    }

    /// @dev Validates if the provided lookahead data points to the current preconfing period.
    function _validatePreconfingPeriod(
        uint256 _epochTimestamp,
        uint256 _slotIndex,
        ILookaheadStore.LookaheadSlot[] memory _currLookahead,
        ILookaheadStore.LookaheadSlot[] memory _nextLookahead
    )
        internal
        view
    {
        uint256 preconfSlotTimestamp;
        uint256 prevSlotTimestamp;

        if (_slotIndex == type(uint256).max) {
            // This is the case when the first preconfer from the next epoch is proposing in
            // advanced in the current epoch.
            //
            // Eg: [x x x Pa y y y] [z z z Pb v v v]
            //     [  curr epoch  ] [  next epoch  ]
            // - Pb is our preconfer.
            // - x, y, z and v represent empty slots with no opted in preconfer.
            // - Pb intends to propose at any slot y
            //
            uint256 nextEpochTimestamp = _epochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH;
            bytes26 nextLookaheadHash = lookaheadStore.getLookaheadHash(nextEpochTimestamp);
            _validateLookahead(nextEpochTimestamp, _nextLookahead, nextLookaheadHash);

            preconfSlotTimestamp = _nextLookahead[0].slotTimestamp;
            prevSlotTimestamp = _currLookahead[_currLookahead.length - 1].slotTimestamp;
        } else {
            // This is the case when the preconfer is proposing in the same epoch in which
            // it has its lookahead slot.
            //
            // Eg: [x x x Pa y y y]
            //     [  curr epoch  ]
            // - Pa is our preconfer.
            // - x and y represent empty slots with no opted in preconfer.
            // - Pa intends to propose at any slot x
            //
            // OR
            //
            // Eg: [x x x Pa y y y Pb z z z]
            //     [      curr epoch       ]
            // - Pb is our preconfer.
            // - x, y and z represent empty slots with no opted in preconfer.
            // - Pb intends to propose at any slot y
            //
            preconfSlotTimestamp = _currLookahead[_slotIndex].slotTimestamp;
            prevSlotTimestamp = _slotIndex == 0
                ? _epochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT
                : _currLookahead[_slotIndex - 1].slotTimestamp;
        }

        require(
            block.timestamp > prevSlotTimestamp
                && block.timestamp <= _currLookahead[_slotIndex].slotTimestamp,
            InvalidLookaheadTimestamp()
        );
    }

    function _validateLookahead(
        uint256 _epochTimestamp,
        ILookaheadStore.LookaheadSlot[] memory _lookahead,
        bytes26 _lookaheadHash
    )
        internal
        pure
    {
        bytes26 actualHash = LibPreconfUtils.calculateLookaheadHash(_epochTimestamp, _lookahead);
        require(_lookaheadHash == actualHash, InvalidPreviousLookahead());
    }
}
