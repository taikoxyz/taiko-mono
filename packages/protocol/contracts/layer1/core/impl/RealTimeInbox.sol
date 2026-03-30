// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { IRealTimeInbox } from "../iface/IRealTimeInbox.sol";
import { LibBlobs } from "../libs/LibBlobs.sol";
import { SurgeVerifier } from "src/layer1/surge/SurgeVerifier.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { ISignalService } from "src/shared/signal/ISignalService.sol";

/// @title RealTimeInbox
/// @notice Inbox contract that combines proposal and proof verification into a single atomic
/// operation. Each call to `propose()` submits a proposal, verifies a ZK proof, and finalizes
/// the state in one transaction.
/// @dev Proposer checks (lookahead, PreconfWhitelist), bond logic, forced inclusions, ring buffer
///      storage, and prover whitelist are all scrapped for this real-time proving POC.
/// @dev WARNING: This contract is vulnerable to proposal frontrunning. A malicious actor can observe
///      a pending `propose()` transaction in the mempool and submit the same proposal with their own
///      address to steal credit. In production, an `actualProver` field (msg.sender) should be included
///      in the Commitment hash so that the proof is bound to a specific sender and cannot be replayed.
/// @custom:security-contact security@nethermind.io
contract RealTimeInbox is IRealTimeInbox, EssentialContract {
    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @notice The proof verifier contract.
    SurgeVerifier internal immutable _proofVerifier;

    /// @notice Signal service responsible for checkpoints and signal relay.
    ISignalService internal immutable _signalService;

    /// @notice The percentage of basefee paid to coinbase.
    uint8 internal immutable _basefeeSharingPctg;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice Block hash of the last finalized L2 block. Serves as the chain head.
    bytes32 public lastFinalizedBlockHash;

    uint256[49] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @dev Initializes immutable configuration.
    /// @param _config Configuration struct.
    constructor(Config memory _config) {
        require(_config.proofVerifier != address(0), "config: proofVerifier");
        require(_config.signalService != address(0), "config: signalService");
        require(_config.basefeeSharingPctg <= 100, "config: basefeeSharingPctg");

        _proofVerifier = SurgeVerifier(_config.proofVerifier);
        _signalService = ISignalService(_config.signalService);
        _basefeeSharingPctg = _config.basefeeSharingPctg;
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the owner of the inbox.
    /// @param _owner The owner of this contract.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IRealTimeInbox
    function activate(bytes32 _genesisBlockHash) external onlyOwner {
        require(lastFinalizedBlockHash == bytes32(0), AlreadyActivated());
        require(_genesisBlockHash != bytes32(0), InvalidGenesisBlockHash());

        lastFinalizedBlockHash = _genesisBlockHash;
        emit Activated(_genesisBlockHash);
    }

    /// @inheritdoc IRealTimeInbox
    function propose(
        bytes calldata _data,
        ICheckpointStore.Checkpoint calldata _checkpoint,
        bytes calldata _proof
    )
        external
        nonReentrant
    {
        require(lastFinalizedBlockHash != bytes32(0), NotActivated());

        // Capture current chain head before it is updated
        bytes32 prevFinalizedBlockHash = lastFinalizedBlockHash;

        // Build proposal from input and get its hash
        (bytes32 proposalHash, Proposal memory proposal, bytes32[] memory signalSlots) =
            _buildProposal(_data);

        // Verify proof and finalize (updates lastFinalizedBlockHash)
        _verifyAndFinalize(proposalHash, prevFinalizedBlockHash, _checkpoint, _proof);

        // Emit event with raw signal slots for driver derivation
        emit ProposedAndProved(
            proposalHash,
            prevFinalizedBlockHash,
            proposal.maxAnchorBlockNumber,
            proposal.basefeeSharingPctg,
            proposal.sources,
            signalSlots,
            _checkpoint
        );
    }

    // ---------------------------------------------------------------
    // Encoding / Decoding / Hashing Functions
    // ---------------------------------------------------------------

    /// @notice Encodes a ProposeInput struct into bytes.
    /// @param _input The ProposeInput to encode.
    /// @return encoded_ The ABI-encoded bytes.
    function encodeProposeInput(ProposeInput calldata _input)
        public
        pure
        returns (bytes memory encoded_)
    {
        return abi.encode(_input);
    }

    /// @notice Decodes bytes into a ProposeInput struct.
    /// @param _data The ABI-encoded ProposeInput.
    /// @return input_ The decoded ProposeInput.
    function decodeProposeInput(bytes calldata _data)
        public
        pure
        returns (ProposeInput memory input_)
    {
        return abi.decode(_data, (ProposeInput));
    }

    /// @notice Hashes a Proposal struct.
    /// @param _proposal The Proposal to hash.
    /// @return The keccak256 hash.
    function hashProposal(Proposal memory _proposal) public pure returns (bytes32) {
        return keccak256(abi.encode(_proposal));
    }

    /// @notice Hashes a Commitment struct.
    /// @param _commitment The Commitment to hash.
    /// @return The keccak256 hash.
    function hashCommitment(Commitment memory _commitment) public pure returns (bytes32) {
        return keccak256(abi.encode(_commitment));
    }

    /// @notice Hashes an array of signal slots.
    /// @param _signalSlots The signal slots to hash.
    /// @return The keccak256 hash (bytes32(0) if empty).
    function hashSignalSlots(bytes32[] memory _signalSlots) public pure returns (bytes32) {
        if (_signalSlots.length == 0) return bytes32(0);
        return keccak256(abi.encode(_signalSlots));
    }

    // ---------------------------------------------------------------
    // External View Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IRealTimeInbox
    function getLastFinalizedBlockHash() external view returns (bytes32) {
        return lastFinalizedBlockHash;
    }

    /// @inheritdoc IRealTimeInbox
    function getConfig() external view returns (Config memory config_) {
        config_ = Config({
            proofVerifier: address(_proofVerifier),
            signalService: address(_signalService),
            basefeeSharingPctg: _basefeeSharingPctg
        });
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Decodes input, validates it, and builds the transient proposal.
    /// @param _data The encoded ProposeInput.
    /// @return proposalHash_ The hash of the proposal.
    /// @return proposal_ The built proposal struct.
    /// @return signalSlots_ The raw signal slots from the input.
    function _buildProposal(bytes calldata _data)
        internal
        view
        returns (bytes32 proposalHash_, Proposal memory proposal_, bytes32[] memory signalSlots_)
    {
        ProposeInput memory input = decodeProposeInput(_data);
        signalSlots_ = input.signalSlots;

        // Validate anchor block - blockhash returns 0 for blocks older than 256
        bytes32 anchorHash = blockhash(input.maxAnchorBlockNumber);
        require(anchorHash != bytes32(0), MaxAnchorBlockTooOld());

        // Verify signal slots and compute hash
        bytes32 signalSlotsHash = _verifySignalSlots(input.signalSlots);

        // Validate blob reference
        LibBlobs.BlobSlice memory blobSlice = LibBlobs.validateBlobReference(input.blobReference);
        // Zero timestamp so it doesn't become part of the proposal hash that must be proven.
        // The driver can derive the blob timestamp from the L1 block that contains the event.
        blobSlice.timestamp = 0;

        // Build derivation sources
        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource(false, blobSlice);

        // Build proposal (standalone — no parent linkage)
        proposal_ = Proposal({
            maxAnchorBlockNumber: input.maxAnchorBlockNumber,
            maxAnchorBlockHash: anchorHash,
            basefeeSharingPctg: _basefeeSharingPctg,
            sources: sources,
            signalSlotsHash: signalSlotsHash
        });

        proposalHash_ = hashProposal(proposal_);
    }

    /// @dev Verifies the proof, saves checkpoint, and updates chain head.
    /// @param _proposalHash The proposal hash.
    /// @param _lastFinalizedBlockHash The block hash of the last finalized L2 block.
    /// @param _checkpoint The checkpoint to save.
    /// @param _proof The ZK proof bytes.
    function _verifyAndFinalize(
        bytes32 _proposalHash,
        bytes32 _lastFinalizedBlockHash,
        ICheckpointStore.Checkpoint calldata _checkpoint,
        bytes calldata _proof
    )
        internal
    {
        // Build commitment and hash it
        bytes32 commitmentHash = hashCommitment(
            Commitment({
                proposalHash: _proposalHash,
                lastFinalizedBlockHash: _lastFinalizedBlockHash,
                checkpoint: _checkpoint
            })
        );

        // Verify proof via SurgeVerifier
        _proofVerifier.verifyProof(true, commitmentHash, _proof);

        // Save checkpoint to signal service
        _signalService.saveCheckpoint(_checkpoint);

        // Update chain head to the new finalized block hash
        lastFinalizedBlockHash = _checkpoint.blockHash;
    }

    /// @dev Verifies signal slots exist on L1 and returns their hash.
    /// @param _signalSlots The signal slots to verify.
    /// @return signalSlotsHash_ The keccak256 hash of slots (bytes32(0) if empty).
    function _verifySignalSlots(bytes32[] memory _signalSlots)
        internal
        view
        returns (bytes32 signalSlotsHash_)
    {
        if (_signalSlots.length == 0) return bytes32(0);

        for (uint256 i; i < _signalSlots.length; ++i) {
            require(
                _signalService.isSignalSent(_signalSlots[i]), SignalSlotNotSent(_signalSlots[i])
            );
        }
        signalSlotsHash_ = hashSignalSlots(_signalSlots);
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error AlreadyActivated();
    error MaxAnchorBlockTooOld();
    error InvalidGenesisBlockHash();
    error NotActivated();
    error SignalSlotNotSent(bytes32 slot);
}
