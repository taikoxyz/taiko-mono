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
    address public immutable protector;

    uint256[50] private __gap;

    error ForcedInclusionNotSupported();
    error InvalidCurrentLookahead();
    error InvalidLookaheadProof();
    error InvalidLookaheadTimestamp();
    error InvalidNextLookahead();
    error InvalidPreviousLookahead();
    error InvalidSlotIndex();
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
        address _fallbackPreconfer,
        address _protector
    )
        EssentialContract()
    {
        lookaheadStore = ILookaheadStore(_lookaheadStore);
        preconfWhitelist = IPreconfWhitelist(_preconfWhitelist);
        iProposeBatch = IProposeBatch(_iProposeBatch);
        preconfSlasher = _preconfSlasher;
        urc = IRegistry(_urc);
        fallbackPreconfer = _fallbackPreconfer;
        protector = _protector;
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
            bytes32 registrationRoot,
            ILookaheadStore.LookaheadSlot[] memory currLookahead,
            ILookaheadStore.LookaheadSlot[] memory nextLookahead,
            bytes memory commitmentSignature
        ) = abi.decode(
            _lookaheadData,
            (
                uint256,
                bytes32,
                ILookaheadStore.LookaheadSlot[],
                ILookaheadStore.LookaheadSlot[],
                bytes
            )
        );

        require(
            slotIndex == type(uint256).max || slotIndex < currLookahead.length, InvalidSlotIndex()
        );

        {
            uint256 epochTimestamp = LibPreconfUtils.getEpochTimestamp();

            {
                bytes26 currLookaheadHash = lookaheadStore.getLookaheadHash(epochTimestamp);
                if (currLookaheadHash != 0) {
                    _validateLookahead(epochTimestamp, currLookahead, currLookaheadHash);
                } else {
                    require(currLookahead.length == 0, InvalidCurrentLookahead());
                }
            }

            uint256 nextEpochTimestamp = epochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH;
            bytes26 nextLookaheadHash = lookaheadStore.getLookaheadHash(nextEpochTimestamp);
            bool nextLookaheadNeedsValidation;

            // Wrapped inside a scope to avoid stack too deep error
            {
                if (nextLookaheadHash == 0) {
                    // If the lookahead for the next epoch is not posted, we post it here.
                    if (currLookahead.length == 0) {
                        // A whitelist preconfer is expected since the current lookahead is empty.
                        // A commitment is not required for the whitelist preconfer.
                        nextLookaheadHash =
                            lookaheadStore.updateLookahead(bytes32(0), abi.encode(nextLookahead));
                    } else {
                        // Build and pass the commitment to the lookahead store
                        ISlasher.SignedCommitment memory signedCommitment =
                            _buildLookaheadCommitment(nextLookahead, commitmentSignature);

                        nextLookaheadHash = lookaheadStore.updateLookahead(
                            registrationRoot, abi.encode(signedCommitment)
                        );
                    }
                } else {
                    require(commitmentSignature.length == 0, InvalidNextLookahead());
                    nextLookaheadNeedsValidation = true;
                }
            }

            if (currLookahead.length == 0) {
                // The current lookahead is empty, so we use a whitelisted preconfer
                _validateWhitelistPreconfer();
            } else {
                uint256 preconfSlotTimestamp; // Upper boundry of the preconfing period
                uint256 prevSlotTimestamp; // Lower boundary of the preconfing period

                ILookaheadStore.LookaheadSlot memory _lookaheadSlot;

                if (slotIndex == type(uint256).max) {
                    // This is the case when the first preconfer from the next epoch is proposing in
                    // advanced in the current epoch.
                    //
                    // Eg: [x x x Pa y y y] [z z z Pb v v v]
                    //     [  curr epoch  ] [  next epoch  ]
                    // - Pb is our preconfer.
                    // - x, y, z and v represent empty slots with no opted in preconfer.
                    // - Pb intends to propose at any slot y
                    //
                    if (nextLookaheadNeedsValidation) {
                        _validateLookahead(nextEpochTimestamp, nextLookahead, nextLookaheadHash);
                    }

                    if (nextLookahead.length == 0) {
                        // This the special case when the next lookahead is empty
                        // Eg: [x x x Pa y y y] [     empty    ]
                        //     [  curr epoch  ] [  next epoch  ]
                        //
                        // The empty slots y will be taken over by the whitelist preconfer
                        // for the current epoch.
                        // The upper boundary of the preconfing period is the last slot of the
                        // current epoch.
                        preconfSlotTimestamp =
                            nextEpochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT;
                    } else {
                        preconfSlotTimestamp = nextLookahead[0].slotTimestamp;
                        _lookaheadSlot = nextLookahead[0];
                    }

                    prevSlotTimestamp = currLookahead[currLookahead.length - 1].slotTimestamp;
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
                    preconfSlotTimestamp = currLookahead[slotIndex].slotTimestamp;
                    prevSlotTimestamp = slotIndex == 0
                        ? epochTimestamp - LibPreconfConstants.SECONDS_IN_SLOT
                        : currLookahead[slotIndex - 1].slotTimestamp;
                    _lookaheadSlot = currLookahead[slotIndex];
                }

                require(
                    block.timestamp > prevSlotTimestamp && block.timestamp <= preconfSlotTimestamp,
                    InvalidLookaheadTimestamp()
                );

                if (nextLookahead.length == 0) {
                    _validateWhitelistPreconfer();
                } else {
                    _validateProposer(_lookaheadSlot);
                }
            }
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
        IRegistry.OperatorData memory operatorData =
            urc.getOperatorData(_lookaheadSlot.registrationRoot);

        // If the operator is slashed or unregistered, we use the fallback or whitelist preconfer
        if (operatorData.unregisteredAt != 0 || operatorData.slashedAt != 0) {
            _validateWhitelistPreconfer();
        } else {
            // Sender must be the expected committer (i.e the opted in preconfer) for
            // the current preconfing period
            require(msg.sender == _lookaheadSlot.committer, ProposerIsNotPreconfer());
            require(
                urc.isOptedIntoSlasher(_lookaheadSlot.registrationRoot, preconfSlasher),
                OperatorIsNotOptedIn()
            );
        }
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

    function _buildLookaheadCommitment(
        ILookaheadStore.LookaheadSlot[] memory _lookahead,
        bytes memory _signature
    )
        internal
        view
        returns (ISlasher.SignedCommitment memory)
    {
        ISlasher.Commitment memory commitment = ISlasher.Commitment({
            commitmentType: 0,
            payload: abi.encode(_lookahead),
            slasher: protector
        });

        return ISlasher.SignedCommitment({ commitment: commitment, signature: _signature });
    }
}
