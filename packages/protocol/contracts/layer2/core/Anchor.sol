// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IBondManager } from "./IBondManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

import "./Anchor_Layout.sol"; // DO NOT DELETE

/// @title Anchor
/// @notice Implements the Shasta fork's anchoring mechanism with advanced bond management,
/// prover designation and checkpoint management.
/// @dev IMPORTANT: This contract will be deployed behind the `AnchorRouter` contract, and that's why
/// it's not upgradable itself.
/// @dev This contract implements:
///      - Bond-based economic security for proposals and proofs
///      - Prover designation with signature authentication
///      - Cumulative bond instruction processing with integrity verification
///      - State tracking for multi-block proposals
/// @custom:security-contact security@taiko.xyz
contract Anchor is EssentialContract {
    using LibAddress for address;
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Authentication data for prover designation.
    /// @dev Used to allow a proposer to designate another address as the prover.
    struct ProverAuth {
        uint48 proposalId; // The proposal ID this auth is for
        address proposer; // The original proposer address
        uint256 provingFee; // Fee (Wei) that prover will receive
        bytes signature; // ECDSA signature from the designated prover
    }

    /// @notice Proposal-level data that applies to the entire batch of blocks.
    struct ProposalParams {
        uint48 proposalId; // Unique identifier of the proposal
        address proposer; // Address of the entity that proposed this batch
        bytes proverAuth; // Encoded ProverAuth for prover designation
        bytes32 bondInstructionsHash; // Expected hash of bond instructions
        LibBonds.BondInstruction[] bondInstructions; // Bond credit instructions to process
    }

    /// @notice Block-level data specific to a single block within a proposal.
    struct BlockParams {
        uint48 anchorBlockNumber; // L1 block number to anchor (0 to skip)
        bytes32 anchorBlockHash; // L1 block hash at anchorBlockNumber
        bytes32 anchorStateRoot; // L1 state root at anchorBlockNumber
    }

    /// @notice Stored proposal-level state for the ongoing batch.
    struct ProposalState {
        bytes32 bondInstructionsHash;
        address designatedProver;
        bool isLowBondProposal;
        uint48 proposalId;
    }

    /// @notice Stored block-level state for the latest anchor.
    /// @dev 2 slots
    struct BlockState {
        uint48 anchorBlockNumber;
        bytes32 ancestorsHash;
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice Golden touch address is the only address that can do the anchor transaction.
    address public constant GOLDEN_TOUCH_ADDRESS = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec;

    /// @notice Gas limit for anchor transactions (must be enforced).
    uint64 public constant ANCHOR_GAS_LIMIT = 1_000_000;

    /// @dev Minimum calldata length for decoding a `ProverAuth` payload safely.
    /// This equals the ABI-encoded size of:
    ///   - uint48 proposalId: 32 bytes (padded)
    ///   - address proposer: 32 bytes (padded)
    ///   - uint256 provingFee: 32 bytes (padded)
    ///   - bytes offset: 32 bytes
    ///   - bytes length: 32 bytes
    ///   - minimum signature data: 65 bytes (r, s, v for ECDSA)
    /// Total: 32 + 32 + 32 + 32 + 32 + 65 = 225 bytes
    uint256 private constant MIN_PROVER_AUTH_LENGTH = 225;

    /// @dev Length of a standard ECDSA signature (r: 32 bytes, s: 32 bytes, v: 1 byte).
    uint256 private constant ECDSA_SIGNATURE_LENGTH = 65;

    /// @dev EIP-712 domain/type hashes for prover authorization signatures.
    bytes32 private constant PROVER_AUTH_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 private constant PROVER_AUTH_TYPEHASH =
        keccak256("ProverAuth(uint48 proposalId,address proposer,uint256 provingFee)");
    bytes32 private constant PROVER_AUTH_DOMAIN_NAME_HASH = keccak256("TaikoAnchorProverAuth");
    bytes32 private constant PROVER_AUTH_DOMAIN_VERSION_HASH = keccak256("1");

    // ---------------------------------------------------------------
    // Immutables
    // ---------------------------------------------------------------

    /// @notice Contract managing bond deposits, withdrawals, and transfers.
    IBondManager public immutable bondManager;

    /// @notice Checkpoint store for storing L1 block data.
    ICheckpointStore public immutable checkpointStore;

    /// @notice Bond amount in Wei for liveness guarantees.
    uint256 public immutable livenessBond;

    /// @notice Bond amount in Wei for provability guarantees.
    uint256 public immutable provabilityBond;

    /// @notice The L1's chain ID.
    uint64 public immutable l1ChainId;

    // ---------------------------------------------------------------
    // State variables
    // ---------------------------------------------------------------

    /// @notice Mapping from block number to block hash.
    mapping(uint256 blockNumber => bytes32 blockHash) public blockHashes;

    /// @dev Slots used by the Pacaya anchor contract itself.
    /// slot1: publicInputHash
    /// slot2: parentGasExcess, lastSyncedBlock, parentTimestamp, parentGasTarget
    /// slot3: l1ChainId
    uint256[3] private _pacayaSlots;

    /// @notice Latest proposal-level state, updated only on the first block of a proposal.
    ProposalState internal _proposalState;

    /// @notice Latest block-level state, updated on every processed block.
    BlockState internal _blockState;

    /// @notice Storage gap for upgrade safety.
    uint256[41] private __gap;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event Anchored(
        bytes32 bondInstructionsHash,
        address designatedProver,
        bool isLowBondProposal,
        uint48 prevAnchorBlockNumber,
        uint48 anchorBlockNumber,
        bytes32 ancestorsHash
    );

    event Withdrawn(address token, address to, uint256 amount);

    // ---------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------

    modifier onlyValidSender() {
        require(msg.sender == GOLDEN_TOUCH_ADDRESS, InvalidSender());
        _;
    }

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes the Anchor contract.
    /// @param _checkpointStore The address of the checkpoint store.
    /// @param _bondManager The address of the bond manager.
    /// @param _livenessBond The liveness bond amount in Wei.
    /// @param _provabilityBond The provability bond amount in Wei.
    /// @param _l1ChainId The L1 chain ID.
    constructor(
        ICheckpointStore _checkpointStore,
        IBondManager _bondManager,
        uint256 _livenessBond,
        uint256 _provabilityBond,
        uint64 _l1ChainId,
        address _owner
    ) {
        // Validate addresses
        require(address(_checkpointStore) != address(0), InvalidAddress());
        require(address(_bondManager) != address(0), InvalidAddress());
        require(_owner != address(0), InvalidAddress());

        // Validate chain IDs
        require(_l1ChainId != 0 && _l1ChainId != block.chainid, InvalidL1ChainId());
        require(block.chainid > 1 && block.chainid <= type(uint64).max, InvalidL2ChainId());

        // Assign immutables
        checkpointStore = _checkpointStore;
        bondManager = _bondManager;
        livenessBond = _livenessBond;
        provabilityBond = _provabilityBond;
        l1ChainId = _l1ChainId;

        _transferOwnership(_owner);
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Processes a block within a proposal, handling bond instructions and L1 data
    /// anchoring.
    /// @dev Core function that processes blocks sequentially within a proposal:
    ///      1. Designates prover when a new proposal starts (i.e. the first block of a proposal)
    ///      2. Processes bond transfers with cumulative hash verification
    ///      3. Anchors L1 block data for cross-chain verification
    /// @param _proposalParams Proposal-level parameters that define the overall batch.
    /// @param _blockParams Block-level parameters specific to this block in the proposal.
    function anchorV4(
        ProposalParams calldata _proposalParams,
        BlockParams calldata _blockParams
    )
        external
        onlyValidSender
        nonReentrant
    {
        uint48 lastProposalId = _proposalState.proposalId;

        if (_proposalParams.proposalId < lastProposalId) {
            // Proposal ID cannot go backward
            revert ProposalIdMismatch();
        }

        // We do not need to account for proposalId = 0, since that's genesis
        if (_proposalParams.proposalId > lastProposalId) {
            _validateProposal(_proposalParams);
        }
        uint48 prevAnchorBlockNumber = _blockState.anchorBlockNumber;
        _validateBlock(_blockParams);

        uint256 parentNumber = block.number - 1;
        blockHashes[parentNumber] = blockhash(parentNumber);

        emit Anchored(
            _proposalState.bondInstructionsHash,
            _proposalState.designatedProver,
            _proposalState.isLowBondProposal,
            prevAnchorBlockNumber,
            _blockState.anchorBlockNumber,
            _blockState.ancestorsHash
        );
    }

    /// @notice Withdraw token or Ether from this address.
    /// Note: This contract receives a portion of L2 base fees, while the remainder is directed to
    /// L2 block's coinbase address.
    /// @param _token Token address or address(0) if Ether.
    /// @param _to Withdraw to address.
    function withdraw(address _token, address _to) external onlyOwner nonReentrant {
        require(_to != address(0), InvalidAddress());
        uint256 amount;
        if (_token == address(0)) {
            amount = address(this).balance;
            _to.sendEtherAndVerify(amount);
        } else {
            amount = IERC20(_token).balanceOf(address(this));
            IERC20(_token).safeTransfer(_to, amount);
        }
        emit Withdrawn(_token, _to, amount);
    }

    // ---------------------------------------------------------------
    // Public View Functions
    // ---------------------------------------------------------------

    /// @notice Returns the designated prover for a proposal.
    /// @param _proposalId The proposal ID.
    /// @param _proposer The proposer address.
    /// @param _proverAuth Encoded prover authentication data.
    /// @param _currentDesignatedProver The current designated prover from state.
    /// @return isLowBondProposal_ True if proposer has insufficient bonds.
    /// @return designatedProver_ The designated prover address.
    /// @return provingFeeToTransfer_ The proving fee (Wei) to transfer from the proposer to the
    /// designated prover.
    function getDesignatedProver(
        uint48 _proposalId,
        address _proposer,
        bytes calldata _proverAuth,
        address _currentDesignatedProver
    )
        public
        view
        returns (bool isLowBondProposal_, address designatedProver_, uint256 provingFeeToTransfer_)
    {
        (address candidate, uint256 provingFee) =
            validateProverAuth(_proposalId, _proposer, _proverAuth);

        bool proposerHasBond = bondManager.hasSufficientBond(_proposer, provingFee);

        if (!proposerHasBond) {
            return (true, _currentDesignatedProver, 0);
        }

        if (candidate == _proposer) {
            return (false, _proposer, 0);
        }

        if (!bondManager.hasSufficientBond(candidate, 0)) {
            return (false, _proposer, 0);
        }

        return (false, candidate, provingFee);
    }

    /// @notice Returns the current proposal-level state snapshot.
    function getProposalState() external view returns (ProposalState memory) {
        return _proposalState;
    }

    /// @notice Returns the current block-level state snapshot.
    function getBlockState() external view returns (BlockState memory) {
        return _blockState;
    }

    /// @dev Validates prover authentication and extracts signer.
    /// @param _proposalId The proposal ID to validate against.
    /// @param _proposer The proposer address to validate against.
    /// @param _proverAuth Encoded prover authentication data.
    /// @return signer_ The recovered signer address (proposer if validation fails).
    /// @return provingFee_ The proving fee in Wei (0 if validation fails).
    function validateProverAuth(
        uint48 _proposalId,
        address _proposer,
        bytes calldata _proverAuth
    )
        public
        view
        returns (address signer_, uint256 provingFee_)
    {
        if (_proverAuth.length < MIN_PROVER_AUTH_LENGTH) {
            return (_proposer, 0);
        }

        ProverAuth memory proverAuth = abi.decode(_proverAuth, (ProverAuth));

        if (!_isMatchingProverAuthContext(proverAuth, _proposalId, _proposer)) {
            return (_proposer, 0);
        }

        // Verify signature has correct length for ECDSA (r: 32 bytes, s: 32 bytes, v: 1 byte)
        if (proverAuth.signature.length != ECDSA_SIGNATURE_LENGTH) {
            return (_proposer, 0);
        }

        (address recovered, ECDSA.RecoverError error) =
            ECDSA.tryRecover(_hashProverAuthMessage(proverAuth), proverAuth.signature);

        if (error != ECDSA.RecoverError.NoError || recovered == address(0)) {
            return (_proposer, 0);
        }

        signer_ = recovered;
        if (signer_ != _proposer) {
            provingFee_ = proverAuth.provingFee;
        }
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Validates and processes proposal-level data on the first block.
    /// @param _proposalParams Proposal-level parameters containing all proposal data.
    function _validateProposal(ProposalParams calldata _proposalParams) private {
        uint256 proverFee;
        (_proposalState.isLowBondProposal, _proposalState.designatedProver, proverFee) =
            getDesignatedProver(
                _proposalParams.proposalId,
                _proposalParams.proposer,
                _proposalParams.proverAuth,
                _proposalState.designatedProver
            );

        if (proverFee > 0) {
            bondManager.debitBond(_proposalParams.proposer, proverFee);
            bondManager.creditBond(_proposalState.designatedProver, proverFee);
        }

        _proposalState.bondInstructionsHash = _processBondInstructions(
            _proposalState.bondInstructionsHash,
            _proposalParams.bondInstructions,
            _proposalParams.bondInstructionsHash
        );

        _proposalState.proposalId = _proposalParams.proposalId;
    }

    /// @dev Validates and processes block-level data.
    /// @param _blockParams Block-level parameters containing anchor data.
    function _validateBlock(BlockParams calldata _blockParams) private {
        // Verify and update ancestors hash
        (bytes32 oldAncestorsHash, bytes32 newAncestorsHash) = _calcAncestorsHash();
        if (_blockState.ancestorsHash != bytes32(0)) {
            require(_blockState.ancestorsHash == oldAncestorsHash, AncestorsHashMismatch());
        }
        _blockState.ancestorsHash = newAncestorsHash;

        // Anchor checkpoint data if a fresher L1 block is provided
        if (_blockParams.anchorBlockNumber > _blockState.anchorBlockNumber) {
            checkpointStore.saveCheckpoint(
                ICheckpointStore.Checkpoint({
                    blockNumber: _blockParams.anchorBlockNumber,
                    blockHash: _blockParams.anchorBlockHash,
                    stateRoot: _blockParams.anchorStateRoot
                })
            );
            _blockState.anchorBlockNumber = _blockParams.anchorBlockNumber;
        }
    }

    /// @dev Processes bond instructions with cumulative hash verification.
    /// @param _currentHash Current cumulative hash from storage.
    /// @param _bondInstructions Bond instructions to process.
    /// @param _expectedHash Expected cumulative hash after processing.
    /// @return newHash_ The new cumulative hash.
    function _processBondInstructions(
        bytes32 _currentHash,
        LibBonds.BondInstruction[] calldata _bondInstructions,
        bytes32 _expectedHash
    )
        private
        returns (bytes32 newHash_)
    {
        newHash_ = _currentHash;

        uint256 length = _bondInstructions.length;
        for (uint256 i; i < length; ++i) {
            LibBonds.BondInstruction calldata instruction = _bondInstructions[i];

            uint256 bondAmount = _bondAmountFor(instruction.bondType);
            if (bondAmount != 0) {
                uint256 bondDebited = bondManager.debitBond(instruction.payer, bondAmount);
                bondManager.creditBond(instruction.payee, bondDebited);
            }

            newHash_ = LibBonds.aggregateBondInstruction(newHash_, instruction);
        }

        require(newHash_ == _expectedHash, BondInstructionsHashMismatch());
    }

    /// @dev Maps a bond type to the configured bond amount in Wei.
    function _bondAmountFor(LibBonds.BondType _bondType) private view returns (uint256) {
        if (_bondType == LibBonds.BondType.LIVENESS) {
            return livenessBond;
        }
        if (_bondType == LibBonds.BondType.PROVABILITY) {
            return provabilityBond;
        }
        return 0;
    }

    /// @dev Calculates the aggregated ancestor block hash for the current block's parent.
    /// @dev This function computes two public input hashes: one for the previous state and one for
    /// the new state.
    /// It uses a ring buffer to store the previous 255 block hashes and the current chain ID.
    /// @return oldAncestorsHash_ The public input hash for the previous state.
    /// @return newAncestorsHash_ The public input hash for the new state.
    function _calcAncestorsHash()
        private
        view
        returns (bytes32 oldAncestorsHash_, bytes32 newAncestorsHash_)
    {
        uint256 parentId = block.number - 1;

        // 255 bytes32 ring buffer + 1 bytes32 for chainId
        bytes32[256] memory inputs;
        inputs[255] = bytes32(block.chainid);

        // Unchecked is safe because it cannot overflow.
        unchecked {
            // Put the previous 255 blockhashes (excluding the parent's) into a
            // ring buffer.
            for (uint256 i; i < 255 && parentId >= i + 1; ++i) {
                uint256 j = parentId - i - 1;
                inputs[j % 255] = blockhash(j);
            }
        }

        assembly {
            oldAncestorsHash_ := keccak256(
                inputs,
                8192 /*mul(256, 32)*/
            )
        }

        inputs[parentId % 255] = blockhash(parentId);
        assembly {
            newAncestorsHash_ := keccak256(
                inputs,
                8192 /*mul(256, 32)*/
            )
        }
    }

    /// @dev Checks whether a decoded `ProverAuth` payload targets the expected proposal context.
    function _isMatchingProverAuthContext(
        ProverAuth memory _auth,
        uint48 _proposalId,
        address _proposer
    )
        private
        pure
        returns (bool)
    {
        return _auth.proposalId == _proposalId && _auth.proposer == _proposer;
    }

    /// @dev Hashes a `ProverAuth` payload into the message that must be signed by the prover.
    /// @dev Uses EIP-712 structured data hashing for better security and wallet compatibility.
    function _hashProverAuthMessage(ProverAuth memory _auth) private view returns (bytes32) {
        bytes32 structHash = _hashProverAuthStruct(_auth);
        return ECDSA.toTypedDataHash(_proverAuthDomainSeparator(), structHash);
    }

    /// @dev Returns the EIP-712 struct hash for a `ProverAuth` payload.
    function _hashProverAuthStruct(ProverAuth memory _auth) private pure returns (bytes32) {
        return keccak256(
            abi.encode(PROVER_AUTH_TYPEHASH, _auth.proposalId, _auth.proposer, _auth.provingFee)
        );
    }

    /// @dev Builds the EIP-712 domain separator for prover authorization signatures.
    /// @dev Uses standard EIP-712 fields: name, version, chainId, and verifyingContract.
    function _proverAuthDomainSeparator() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                PROVER_AUTH_DOMAIN_TYPEHASH,
                PROVER_AUTH_DOMAIN_NAME_HASH,
                PROVER_AUTH_DOMAIN_VERSION_HASH,
                block.chainid,
                address(this)
            )
        );
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error AncestorsHashMismatch();
    error BondInstructionsHashMismatch();
    error InvalidAddress();
    error InvalidAnchorBlockNumber();
    error InvalidBlockIndex();
    error InvalidL1ChainId();
    error InvalidL2ChainId();
    error InvalidSender();
    error NonZeroAnchorBlockHash();
    error NonZeroAnchorStateRoot();
    error NonZeroBlockIndex();
    error ProposalIdMismatch();
    error ProposerMismatch();
    error ZeroBlockCount();
}
