// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ISyncedBlockManager } from "src/shared/based/iface/ISyncedBlockManager.sol";
import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";
import { IInbox } from "../iface/IInbox.sol";
import { IProofVerifier } from "../iface/IProofVerifier.sol";
import { IProposerChecker } from "../iface/IProposerChecker.sol";
import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { LibDecoder } from "../libs/LibDecoder.sol";

/// @title ShastaInbox
/// @notice Manages L2 proposals, proofs, and verification for a based rollup architecture.
/// @custom:security-contact security@taiko.xyz

abstract contract Inbox is EssentialContract, IInbox {
    using LibDecoder for bytes;
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when bond is withdrawn from the contract
    /// @param user The user whose bond was withdrawn
    /// @param amount The amount of bond withdrawn
    event BondWithdrawn(address indexed user, uint256 amount);

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Extended claim record that stores both the claim hash and encoded metadata.
    /// @dev The metadata includes the proposal ID and partial parent claim hash for efficient
    /// lookups.
    struct ExtendedClaimRecord {
        bytes32 claimRecordHash;
        uint256 slotReuseMarker;
    }

    /// @notice Stores proposal data and associated claim records.
    /// @dev Each proposal can have multiple claims associated with it, indexed by parent claim
    /// hash.
    struct ProposalRecord {
        /// @dev Hash of the proposal data
        bytes32 proposalHash;
        /// @dev Maps parent claim hashes to their corresponding claim record hashes
        mapping(bytes32 parentClaimHash => ExtendedClaimRecord claimRecordHash) claimHashLookup;
    }

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    // 5 slots are used by the State object defined in Pacaya inbox:
    // mapping(uint256 batchId_mod_batchRingBufferSize => Batch batch) batches;
    // mapping(uint256 batchId => mapping(bytes32 parentHash => uint24 transitionId)) transitionIds;
    // mapping(uint256 batchId_mod_batchRingBufferSize => mapping(uint24 transitionId =>
    //         TransitionState ts)) transitions;
    // bytes32 __reserve1;
    // Stats1 stats1;
    uint256[5] private __slotsUsedByPacaya;

    // Reserved slot for future migration compatibility
    uint256 private __reservedSlot;

    mapping(address account => uint256 bond) public bondBalance;

    /// @dev The hash of the core state.
    bytes32 internal coreStateHash;

    /// @dev Ring buffer for storing proposal records.
    mapping(uint256 bufferSlot => ProposalRecord proposalRecord) internal proposalRingBuffer;

    uint256[41] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes the Inbox contract
    constructor() EssentialContract() { }

    /// @notice Initializes the Inbox contract with genesis block
    /// @param _owner The owner of this contract
    /// @param _genesisBlockHash The hash of the genesis block
    function init(address _owner, bytes32 _genesisBlockHash) external initializer {
        __Essential_init(_owner);

        Claim memory claim;
        claim.endBlockHash = _genesisBlockHash;

        CoreState memory coreState;
        coreState.nextProposalId = 1;
        coreState.lastFinalizedClaimHash = keccak256(abi.encode(claim));
        coreStateHash = keccak256(abi.encode(coreState));

        emit CoreStateSet(coreState);
    }

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IInbox
    function propose(bytes calldata, /*_lookahead*/ bytes calldata _data) external nonReentrant {
        Config memory config = getConfig();
        IProposerChecker(config.proposerChecker).checkProposer(msg.sender);

        (
            uint64 deadline,
            CoreState memory coreState,
            LibBlobs.BlobReference memory blobReference,
            ClaimRecord[] memory claimRecords
        ) = _data.decodeProposeData();

        require(deadline == 0 || block.timestamp <= deadline, DeadlineExceeded());

        bytes32 coreStateHash_ = keccak256(abi.encode(coreState));
        require(coreStateHash_ == coreStateHash, InvalidState());

        // Check if new proposals would exceed the unfinalized proposal capacity
        require(
            coreState.nextProposalId - coreState.lastFinalizedProposalId <= _getCapacity(config),
            ExceedsUnfinalizedProposalCapacity()
        );

        Proposal memory proposal;

        // Handle forced inclusion if required
        if (IForcedInclusionStore(config.forcedInclusionStore).isOldestForcedInclusionDue()) {
            IForcedInclusionStore.ForcedInclusion memory forcedInclusion = IForcedInclusionStore(
                config.forcedInclusionStore
            ).consumeOldestForcedInclusion(msg.sender);

            (coreState, proposal) = _propose(config, coreState, forcedInclusion.blobSlice, true);
            emit Proposed(proposal, coreState);
            coreStateHash_ = keccak256(abi.encode(coreState));
        }

        // Create regular proposal
        LibBlobs.BlobSlice memory blobSlice = LibBlobs.validateBlobReference(blobReference);
        (coreState, proposal) = _propose(config, coreState, blobSlice, false);
        // Finalize proved proposals
        coreState = _finalize(config, coreState, claimRecords);
        emit Proposed(proposal, coreState);

        // Update stored hash with final coreState
        _setCoreStateHash(keccak256(abi.encode(coreState)));
    }

    /// @inheritdoc IInbox
    function prove(bytes calldata _data, bytes calldata _proof) external nonReentrant {
        Config memory config = getConfig();
        (Proposal[] memory proposals, Claim[] memory claims) = _data.decodeProveData();

        require(proposals.length == claims.length, InconsistentParams());
        require(proposals.length != 0, EmptyProposals());

        ClaimRecord[] memory claimRecords = _buildClaimRecords(config, proposals, claims);

        for (uint256 i; i < proposals.length; ++i) {
            _setClaimRecordHash(
                config,
                proposals[i].id,
                claimRecords[i].claim.parentClaimHash,
                keccak256(abi.encode(claimRecords[i]))
            );
            emit Proved(proposals[i], claimRecords[i]);
        }

        bytes32 claimsHash = keccak256(abi.encode(claims));
        IProofVerifier(config.proofVerifier).verifyProof(claimsHash, _proof);
    }

    /// @notice Withdraws bond balance for a given user.
    /// @dev Anyone can call this function to withdraw bond for any user.
    function withdrawBond() external nonReentrant {
        uint256 amount = bondBalance[msg.sender];
        require(amount > 0, NoBondToWithdraw());

        bondBalance[msg.sender] = 0;
        Config memory config = getConfig();
        IERC20(config.bondToken).safeTransfer(msg.sender, amount);

        emit BondWithdrawn(msg.sender, amount);
    }

    /// @notice Gets the proposal hash for a given proposal ID.
    /// @param _proposalId The proposal ID to look up.
    /// @return proposalHash_ The hash stored at the proposal's ring buffer slot.
    function getProposalHash(uint48 _proposalId) public view returns (bytes32 proposalHash_) {
        Config memory config = getConfig();
        uint256 bufferSlot = _proposalId % config.ringBufferSize;
        proposalHash_ = proposalRingBuffer[bufferSlot].proposalHash;
    }

    /// @notice Gets the claim record hash for a given proposal and parent claim.
    /// @param _proposalId The proposal ID to look up.
    /// @param _parentClaimHash The parent claim hash to look up.
    /// @return claimRecordHash_ The claim record hash, or bytes32(0) if not found.
    function getClaimRecordHash(
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        public
        view
        returns (bytes32 claimRecordHash_)
    {
        Config memory config = getConfig();
        return _getClaimRecordHash(config, _proposalId, _parentClaimHash);
    }

    /// @notice Gets the capacity for unfinalized proposals.
    /// @return _ The maximum number of unfinalized proposals that can exist.
    function getCapacity() public view returns (uint256) {
        Config memory config = getConfig();
        return _getCapacity(config);
    }

    /// @notice Gets the configuration for this Inbox contract
    /// @dev This function must be overridden by subcontracts to provide their specific
    /// configuration
    /// @return _ The configuration struct
    function getConfig() public view virtual returns (Config memory);

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Builds claim records for multiple proposals and claims.
    /// @param _config The configuration parameters.
    /// @param _proposals The proposals to prove.
    /// @param _claims The claims containing the proof details.
    /// @return claimRecords_ The built claim records.
    function _buildClaimRecords(
        Config memory _config,
        Proposal[] memory _proposals,
        Claim[] memory _claims
    )
        internal
        view
        virtual
        returns (ClaimRecord[] memory claimRecords_)
    {
        claimRecords_ = new ClaimRecord[](_proposals.length);
        for (uint256 i; i < _proposals.length; ++i) {
            Proposal memory proposal = _proposals[i];
            Claim memory claim = _claims[i];

            _validateProposal(_config, proposal, claim);

            LibBonds.BondInstruction[] memory bondInstructions =
                _calculateBondInstructions(_config, proposal, claim);

            claimRecords_[i] =
                ClaimRecord({ claim: claim, span: 1, bondInstructions: bondInstructions });
        }
    }

    /// @dev Validates that a proposal hash matches both the claim and storage.
    /// @param _config The configuration parameters.
    /// @param _proposal The proposal to validate.
    /// @param _claim The claim to validate against.
    function _validateProposal(
        Config memory _config,
        Proposal memory _proposal,
        Claim memory _claim
    )
        internal
        view
    {
        bytes32 proposalHash = keccak256(abi.encode(_proposal));
        // Validate proposal hash matches claim and storage in one check
        if (proposalHash != _claim.proposalHash) revert ProposalHashMismatch();

        uint256 bufferSlot = _proposal.id % _config.ringBufferSize;
        if (proposalHash != proposalRingBuffer[bufferSlot].proposalHash) {
            revert ProposalHashMismatch();
        }
    }

    /// @dev Sets the hash of the core state.
    function _setCoreStateHash(bytes32 _coreStateHash) internal {
        coreStateHash = _coreStateHash;
    }

    /// @dev Sets the proposal hash for a given proposal ID.
    function _setProposalHash(
        Config memory _config,
        uint48 _proposalId,
        bytes32 _proposalHash
    )
        internal
    {
        uint256 bufferSlot = _proposalId % _config.ringBufferSize;
        proposalRingBuffer[bufferSlot].proposalHash = _proposalHash;
    }

    /// @dev Sets the claim record hash for a given proposal and parent claim.
    function _setClaimRecordHash(
        Config memory _config,
        uint48 _proposalId,
        bytes32 _parentClaimHash,
        bytes32 _claimRecordHash
    )
        internal
        virtual
    {
        uint256 bufferSlot = _proposalId % _config.ringBufferSize;
        proposalRingBuffer[bufferSlot].claimHashLookup[_parentClaimHash].claimRecordHash =
            _claimRecordHash;
    }

    /// @dev Gets the capacity for unfinalized proposals.
    function _getCapacity(Config memory _config) internal pure returns (uint256) {
        // The ring buffer can hold ringBufferSize proposals total, but we need to ensure
        // unfinalized proposals are not overwritten. Therefore, the maximum number of
        // unfinalized proposals is ringBufferSize - 1.
        unchecked {
            return _config.ringBufferSize - 1;
        }
    }

    /// @dev Gets the claim record hash for a given proposal and parent claim.
    function _getClaimRecordHash(
        Config memory _config,
        uint48 _proposalId,
        bytes32 _parentClaimHash
    )
        internal
        view
        virtual
        returns (bytes32 claimRecordHash_)
    {
        uint256 bufferSlot = _proposalId % _config.ringBufferSize;
        claimRecordHash_ =
            proposalRingBuffer[bufferSlot].claimHashLookup[_parentClaimHash].claimRecordHash;
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Proposes a new proposal of L2 blocks.
    /// @param _config The configuration parameters.
    /// @param _coreState The core state of the inbox.
    /// @param _blobSlice The blob slice of the proposal.
    /// @param _isForcedInclusion Whether the proposal is a forced inclusion.
    /// @return coreState_ The updated core state.
    /// @return proposal_ The created proposal.
    function _propose(
        Config memory _config,
        CoreState memory _coreState,
        LibBlobs.BlobSlice memory _blobSlice,
        bool _isForcedInclusion
    )
        private
        returns (CoreState memory coreState_, Proposal memory proposal_)
    {
        uint48 proposalId = _coreState.nextProposalId++;
        uint48 originTimestamp = uint48(block.timestamp);
        uint48 originBlockNumber = uint48(block.number);

        proposal_ = Proposal({
            id: proposalId,
            proposer: msg.sender,
            originTimestamp: originTimestamp,
            originBlockNumber: originBlockNumber,
            isForcedInclusion: _isForcedInclusion,
            basefeeSharingPctg: _config.basefeeSharingPctg,
            blobSlice: _blobSlice
        });

        bytes32 proposalHash = keccak256(abi.encode(proposal_));

        _setProposalHash(_config, proposalId, proposalHash);

        return (_coreState, proposal_);
    }

    /// @dev Calculates the bond instructions based on proof timing and prover identity
    /// @notice Bond instructions determine how provability and liveness bonds are handled:
    /// - On-time proofs: Bonds may be refunded or remain unchanged
    /// - Late proofs: Liveness bonds may be slashed and redistributed
    /// - Very late proofs: Provability bonds may also be slashed and redistributed
    /// @param _config The configuration parameters.
    /// @param _proposal The proposal containing timing and proposer information
    /// @param _claim The claim containing the proof details.
    /// @return bondInstructions_ The bond instructions that affect aggregation eligibility
    function _calculateBondInstructions(
        Config memory _config,
        Proposal memory _proposal,
        Claim memory _claim
    )
        internal
        view
        returns (LibBonds.BondInstruction[] memory bondInstructions_)
    {
        unchecked {
            if (block.timestamp <= _proposal.originTimestamp + _config.provingWindow) {
                // Proof submitted within the designated proving window (on-time proof)
                return new LibBonds.BondInstruction[](0);
            } else {
                LibBonds.BondInstruction[] memory bondInstructions =
                    new LibBonds.BondInstruction[](1);

                if (block.timestamp <= _proposal.originTimestamp + _config.extendedProvingWindow) {
                    if (_claim.designatedProver != _claim.actualProver) {
                        bondInstructions[0] = LibBonds.BondInstruction({
                            proposalId: _proposal.id,
                            bondType: LibBonds.BondType.LIVENESS,
                            payer: _claim.designatedProver,
                            receiver: _claim.actualProver
                        });
                    }
                } else {
                    if (_proposal.proposer != _claim.actualProver) {
                        bondInstructions[0] = LibBonds.BondInstruction({
                            proposalId: _proposal.id,
                            bondType: LibBonds.BondType.PROVABILITY,
                            payer: _proposal.proposer,
                            receiver: _claim.actualProver
                        });
                    }
                }
                return bondInstructions;
            }
        }
    }

    /// @dev Finalizes proposals by verifying claim records and updating state.
    /// @param _config The configuration parameters.
    /// @param _coreState The current core state.
    /// @param _claimRecords The claim records to finalize.
    /// @return coreState_ The updated core state
    function _finalize(
        Config memory _config,
        CoreState memory _coreState,
        ClaimRecord[] memory _claimRecords
    )
        private
        returns (CoreState memory coreState_)
    {
        // The last finalized claim record.
        ClaimRecord memory claimRecord;
        bool hasFinalized;

        uint48 proposalId = _coreState.lastFinalizedProposalId + 1;

        for (uint256 i; i < _config.maxFinalizationCount; ++i) {
            // Id for the next proposal to be finalized.

            // There is no more unfinalized proposals
            if (proposalId >= _coreState.nextProposalId) break;

            bytes32 storedClaimRecordHash =
                _getClaimRecordHash(_config, proposalId, _coreState.lastFinalizedClaimHash);

            // The next proposal cannot be finalized as there is no claim record to link the chain
            if (storedClaimRecordHash == 0) break;

            // There is no claim record provided for the next proposal.
            require(i < _claimRecords.length, ClaimRecordNotProvided());

            claimRecord = _claimRecords[i];

            bytes32 claimRecordHash = keccak256(abi.encode(claimRecord));
            require(claimRecordHash == storedClaimRecordHash, ClaimRecordHashMismatch());

            _coreState.lastFinalizedProposalId = proposalId;
            _coreState.lastFinalizedClaimHash = keccak256(abi.encode(claimRecord.claim));

            if (claimRecord.bondInstructions.length > 0) {
                emit BondInstructed(claimRecord.bondInstructions);
                for (uint256 j; j < claimRecord.bondInstructions.length; ++j) {
                    _coreState.bondInstructionsHash = LibBonds.aggregateBondInstruction(
                        _coreState.bondInstructionsHash, claimRecord.bondInstructions[j]
                    );
                }
            }

            // Validate span is within bounds
            require(_claimRecords[i].span > 0, InvalidSpan());
            require(
                proposalId + _claimRecords[i].span < _coreState.nextProposalId + 1,
                SpanOutOfBounds()
            );

            proposalId = proposalId + _claimRecords[i].span;
            hasFinalized = true;
        }

        if (hasFinalized) {
            ISyncedBlockManager(_config.syncedBlockManager).saveSyncedBlock(
                claimRecord.claim.endBlockNumber,
                claimRecord.claim.endBlockHash,
                claimRecord.claim.endStateRoot
            );
        }

        return _coreState;
    }
}

// ---------------------------------------------------------------
// Errors
// ---------------------------------------------------------------

error ClaimRecordHashMismatch();
error ClaimRecordNotProvided();
error DeadlineExceeded();
error EmptyProposals();
error ExceedsUnfinalizedProposalCapacity();
error ForkNotActive();
error InconsistentParams();
error InsufficientBond();
error InvalidForcedInclusion();
error InvalidState();
error NoBondToWithdraw();
error ProposalHashMismatch();
error ProposerBondInsufficient();
error RingBufferSizeZero();
error InvalidSpan();
error SpanOutOfBounds();
error Unauthorized();
