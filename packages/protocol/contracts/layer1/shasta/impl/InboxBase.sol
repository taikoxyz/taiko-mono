// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EssentialContract } from "contracts/shared/common/EssentialContract.sol";
import { IBondManager } from "contracts/shared/based/iface/IBondManager.sol";
import { ISyncedBlockManager } from "contracts/shared/based/iface/ISyncedBlockManager.sol";
import { IForcedInclusionStore } from "../iface/IForcedInclusionStore.sol";
import { IInbox } from "../iface/IInbox.sol";
import { IProofVerifier } from "../iface/IProofVerifier.sol";
import { IProposerChecker } from "../iface/IProposerChecker.sol";
import { LibBlobs } from "../libs/LibBlobs.sol";
import { LibBondOperation } from "contracts/shared/based/libs/LibBondOperation.sol";
import { LibDecoder } from "../libs/LibDecoder.sol";

/// @title InboxBase
/// @notice Base implementation for managing L2 proposals, proofs, and verification
/// @dev Provides a simpler baseline implementation without slot optimization
/// @custom:security-contact security@taiko.xyz
///
/// Gas Analysis (assuming ring buffer reuse, 1 claim per proposal, bonds on L2, no forced
/// inclusion):
/// ┌─────────────────────────────────────────────────────────────────────────────┐
/// │ Operation: propose() with n finalizations                                   │
/// ├─────────────────────────────────────────────────────────────────────────────┤
/// │ SLOAD Operations:                                                           │
/// │ - Read coreStateHash: 1                                                     │
/// │ - Per finalization (n times):                                               │
/// │   - Read claim record hash from mapping: 1                                  │
/// │ Total SLOADs: 1 + n*1                                                       │
/// ├─────────────────────────────────────────────────────────────────────────────┤
/// │ SSTORE Operations:                                                          │
/// │ - Update coreStateHash (non-zero->non-zero): 1                              │
/// │ - Store proposal hash (non-zero->non-zero): 1                               │
/// │ Total SSTOREs: 2                                                            │
/// └─────────────────────────────────────────────────────────────────────────────┘
/// ┌─────────────────────────────────────────────────────────────────────────────┐
/// │ Operation: prove() for 1 proposal                                           │
/// ├─────────────────────────────────────────────────────────────────────────────┤
/// │ SLOAD Operations:                                                           │
/// │ - Read proposal hash for verification: 1                                    │
/// │ Total SLOADs: 1                                                             │
/// ├─────────────────────────────────────────────────────────────────────────────┤
/// │ SSTORE Operations:                                                          │
/// │ - Store claim record hash (0->non-zero): 1                                  │
/// │ Total SSTOREs: 1                                                            │
/// └─────────────────────────────────────────────────────────────────────────────┘
///
abstract contract InboxBase is EssentialContract, IInbox {
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

    /// @notice Stores proposal data and associated claim records.
    /// @dev Each proposal can have multiple claims associated with it, indexed by parent claim
    /// hash.
    struct ProposalRecord {
        /// @dev Hash of the proposal data
        bytes32 proposalHash;
        /// @dev Maps parent claim hashes to their corresponding claim record hashes
        mapping(bytes32 parentClaimHash => bytes32 claimRecordHash) claimHashLookup;
    }

    struct PacayaStats2 {
        uint64 numBatches;
        uint64 lastVerifiedBatchId;
        bool paused;
        uint56 lastProposedIn;
        uint64 lastUnpausedAt;
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    uint256 public constant REWARD_FRACTION = 2;

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

    PacayaStats2 private _pacayaStats2;

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
    // External Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IInbox
    function propose(bytes calldata, /*_lookahead*/ bytes calldata _data) external nonReentrant {
        Config memory config = getConfig();
        require(_isForkActive(config), ForkNotActive());
        IProposerChecker(config.proposerChecker).checkProposer(msg.sender);
        require(
            IBondManager(config.bondManager).hasSufficientBond(msg.sender, 0),
            ProposerBondInsufficient()
        );

        (
            CoreState memory coreState,
            LibBlobs.BlobReference memory blobReference,
            ClaimRecord[] memory claimRecords
        ) = _data.decodeProposeData();

        require(keccak256(abi.encode(coreState)) == coreStateHash, InvalidState());

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
        }

        // Create regular proposal
        LibBlobs.BlobSlice memory blobSlice = LibBlobs.validateBlobReference(blobReference);
        (coreState, proposal) = _propose(config, coreState, blobSlice, false);
        // Finalize proved proposals
        coreState = _finalize(config, coreState, claimRecords);
        emit Proposed(proposal, coreState);

        _setCoreStateHash(keccak256(abi.encode(coreState)));
    }

    /// @inheritdoc IInbox
    function prove(bytes calldata _data, bytes calldata _proof) external nonReentrant {
        Config memory config = getConfig();
        (Proposal[] memory proposals, Claim[] memory claims) = _data.decodeProveData();

        require(proposals.length == claims.length, InconsistentParams());
        require(proposals.length != 0, EmptyProposals());

        uint48[] memory proposalIds = new uint48[](proposals.length);
        ClaimRecord[] memory claimRecords = new ClaimRecord[](proposals.length);

        for (uint256 i; i < proposals.length; ++i) {
            proposalIds[i] = proposals[i].id;
            claimRecords[i] = _buildClaimRecord(config, proposals[i], claims[i]);
        }

        // Aggregate claim records to reduce SSTORE operations.
        (proposalIds, claimRecords) = _aggregateClaimRecords(proposalIds, claimRecords);

        for (uint256 i; i < claimRecords.length; ++i) {
            _setClaimRecordHash(
                config,
                proposalIds[i],
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

    // ---------------------------------------------------------------
    // Public Functions
    // ---------------------------------------------------------------

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

    /// @dev Sets the hash of the core state.
    function _setCoreStateHash(bytes32 _coreStateHash) internal {
        coreStateHash = _coreStateHash;
    }

    /// @dev Sets the proposal hash for a given proposal ID.
    /// @dev This is a virtual function that can be overridden for optimization
    function _setProposalHash(
        Config memory _config,
        uint48 _proposalId,
        bytes32 _proposalHash
    )
        internal
        virtual
    {
        uint256 bufferSlot = _proposalId % _config.ringBufferSize;
        proposalRingBuffer[bufferSlot].proposalHash = _proposalHash;
    }

    /// @dev Sets the claim record hash for a given proposal and parent claim.
    /// @dev This is a virtual function that can be overridden for optimization
    function _setClaimRecordHash(
        Config memory _config,
        uint48 _proposalId,
        bytes32 _parentClaimHash,
        bytes32 _claimRecordHash
    )
        internal
        virtual
    {
        ProposalRecord storage proposalRecord =
            proposalRingBuffer[_proposalId % _config.ringBufferSize];
        proposalRecord.claimHashLookup[_parentClaimHash] = _claimRecordHash;
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
    /// @dev This is a virtual function that can be overridden for optimization
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
        ProposalRecord storage proposalRecord =
            proposalRingBuffer[_proposalId % _config.ringBufferSize];
        return proposalRecord.claimHashLookup[_parentClaimHash];
    }

    /// @dev Aggregates claim records into a smaller list to reduce SSTORE operations.
    /// The default implementation returns the original list.
    /// @param _proposalIds The proposal IDs to aggregate.
    /// @param _claimRecords The claim records to aggregate.
    /// @return proposalIds_  The list contains the proposal IDs of the aggregated claim records.
    /// @return claimRecords_ The list contains the aggregated claim records.
    function _aggregateClaimRecords(
        uint48[] memory _proposalIds,
        ClaimRecord[] memory _claimRecords
    )
        internal
        pure
        virtual
        returns (uint48[] memory proposalIds_, ClaimRecord[] memory claimRecords_)
    {
        return (_proposalIds, _claimRecords);
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
            provabilityBondGwei: _config.provabilityBondGwei,
            livenessBondGwei: _config.livenessBondGwei,
            blobSlice: _blobSlice
        });

        bytes32 proposalHash = keccak256(abi.encode(proposal_));

        _setProposalHash(_config, proposalId, proposalHash);

        return (_coreState, proposal_);
    }

    /// @dev Builds a claim record for a single proposal.
    /// @param _config The configuration parameters.
    /// @param _proposal The proposal to prove.
    /// @param _claim The claim containing the proof details.
    function _buildClaimRecord(
        Config memory _config,
        Proposal memory _proposal,
        Claim memory _claim
    )
        private
        view
        returns (ClaimRecord memory claimRecord_)
    {
        bytes32 proposalHash = keccak256(abi.encode(_proposal));
        if (proposalHash != _claim.proposalHash) revert ProposalHashMismatch();
        uint256 bufferSlot = _proposal.id % _config.ringBufferSize;
        if (proposalHash != proposalRingBuffer[bufferSlot].proposalHash) {
            revert ProposalHashMismatch();
        }

        BondDecision bondDecision = _calculateBondDecision(_config, _claim, _proposal);

        uint48 livenessBond = bondDecision == BondDecision.L1SlashLivenessRewardProver
            || bondDecision == BondDecision.L2SlashLivenessRewardProver ? _proposal.livenessBondGwei : 0;

        uint48 provabilityBond = bondDecision == BondDecision.L1SlashProvabilityRewardProver
            ? _proposal.provabilityBondGwei
            : 0;

        claimRecord_ = ClaimRecord({
            claim: _claim,
            proposer: _proposal.proposer,
            livenessBondGwei: livenessBond,
            provabilityBondGwei: provabilityBond,
            bondDecision: bondDecision,
            nextProposalId: _proposal.id + 1
        });
    }

    /// @dev Calculates the bond decision based on proof timing and prover identity
    /// @notice Bond decisions determine how provability and liveness bonds are handled:
    /// - On-time proofs: Bonds may be refunded or remain unchanged
    /// - Late proofs: Liveness bonds may be slashed and redistributed
    /// - Very late proofs: Provability bonds may also be slashed
    /// The decision affects whether claim records can be aggregated
    /// @param _config The configuration parameters.
    /// @param _claim The claim containing prover information
    /// @param _proposal The proposal containing timing and proposer information
    /// @return bondDecision_ The bond decision that affects aggregation eligibility
    function _calculateBondDecision(
        Config memory _config,
        Claim memory _claim,
        Proposal memory _proposal
    )
        private
        view
        returns (BondDecision bondDecision_)
    {
        unchecked {
            if (block.timestamp <= _proposal.originTimestamp + _config.provingWindow) {
                // Proof submitted within the designated proving window (on-time proof)
                return BondDecision.NoOp;
            }

            if (block.timestamp <= _proposal.originTimestamp + _config.extendedProvingWindow) {
                // Proof submitted during extended window (late but acceptable proof)
                return _claim.designatedProver == _proposal.proposer
                    ? BondDecision.L1SlashLivenessRewardProver
                    : BondDecision.L2SlashLivenessRewardProver;
            }

            // Proof submitted after extended window (very late proof)
            return BondDecision.L1SlashProvabilityRewardProver;
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
            _coreState.bondOperationsHash =
                _processBonds(_config, proposalId, claimRecord, _coreState.bondOperationsHash);

            proposalId = _claimRecords[i].nextProposalId;
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

    /// @dev Handles bond refunds and penalties based on the bond decision
    /// @notice Processes bonds for potentially aggregated claim records. When a claim
    /// record represents multiple aggregated proposals, liveness bonds are summed
    /// and processed together, reducing the number of bond operations
    /// @param _config The configuration parameters.
    /// @param _proposalId The first proposal ID in the aggregated record
    /// @param _claimRecord The claim record (may represent multiple proposals)
    /// @param _bondOperationsHash The current hash of bond operations
    /// @return _ The updated hash including this operation
    function _processBonds(
        Config memory _config,
        uint48 _proposalId,
        ClaimRecord memory _claimRecord,
        bytes32 _bondOperationsHash
    )
        private
        returns (bytes32)
    {
        LibBondOperation.BondOperation memory bondOperation;

        Claim memory claim = _claimRecord.claim;

        if (_claimRecord.bondDecision == BondDecision.L2SlashLivenessRewardProver) {
            bondOperation = LibBondOperation.BondOperation({
                proposalId: _proposalId,
                creditAmountGwei: uint48(_claimRecord.livenessBondGwei / REWARD_FRACTION),
                creditTo: claim.actualProver,
                debitAmountGwei: _claimRecord.livenessBondGwei,
                debitFrom: claim.designatedProver
            });
            emit BondRequest(bondOperation);
            return LibBondOperation.aggregateBondOperation(_bondOperationsHash, bondOperation);
        }

        IBondManager bondManager = IBondManager(_config.bondManager);

        if (_claimRecord.bondDecision == BondDecision.L1SlashLivenessRewardProver) {
            bondManager.debitBond(_claimRecord.proposer, uint96(_claimRecord.livenessBondGwei));
            bondManager.creditBond(
                claim.actualProver, uint96(_claimRecord.livenessBondGwei / REWARD_FRACTION)
            );
        } else if (_claimRecord.bondDecision == BondDecision.L1SlashProvabilityRewardProver) {
            bondManager.debitBond(_claimRecord.proposer, uint96(_claimRecord.provabilityBondGwei));
            bondManager.creditBond(
                claim.actualProver, uint96(_claimRecord.provabilityBondGwei / REWARD_FRACTION)
            );
        }
        return _bondOperationsHash;
    }

    function _isForkActive(Config memory _cfg) internal view returns (bool) {
        return _cfg.forkActivationHeight == 0
            || _pacayaStats2.numBatches + 1 == _cfg.forkActivationHeight;
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error ClaimRecordHashMismatch();
    error ClaimRecordNotProvided();
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
    error Unauthorized();
}
