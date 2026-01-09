// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IProofVerifier } from "../verifiers/IProofVerifier.sol";
import { LibProofBitmap } from "./libs/LibProofBitmap.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title SurgeVerifier
/// @notice Routes proof verification to internal verifiers
/// @custom:security-contact security@nethermind.io
contract SurgeVerifier is Ownable2Step {
    using LibProofBitmap for LibProofBitmap.ProofBitmap;

    // ---------------------------------------------------------------
    // Proof bitflags for LibProofBitmap
    // ---------------------------------------------------------------

    uint8 public constant RISC0_RETH = 1; // 0b00000001
    uint8 public constant SP1_RETH = 1 << 1; // 0b00000010
    uint8 public constant ZISK_RETH = 1 << 2; // 0b00000100

    // ---------------------------------------------------------------
    // Types and storage
    // ---------------------------------------------------------------

    address public immutable inbox;

    /// @dev Number of proof types required for the transition/commitment to be deemed finalising
    uint8 public immutable numProofsThreshold;

    struct InternalVerifier {
        /// @dev Address of the proof specific verifier, eg: SP1, RISC0, etc.
        address addr;
        /// @dev When `true` the timelock on the security council can be bypassed
        /// to allow for instantly upgrading this verifier's address
        bool allowInstantUpgrade;
    }

    struct SubProof {
        /// @dev The bit flag of the proof type that can be resolved from `LibProofBitmap.sol`
        LibProofBitmap.ProofBitmap proofBitFlag;
        /// @dev The cryptographic proof
        bytes data;
    }

    /// @notice Mapping from bit flag to an internal verifier contract that implements IProofVerifier
    mapping(LibProofBitmap.ProofBitmap proofBitFlag => InternalVerifier verifier) internal
        _verifiers;

    /// @notice Mapping from bit flag and a proposal id to a boolean that represents if the verifier for
    /// the proof type has been marked for upgrade due to conflicts at the given proposal id
    mapping(
        LibProofBitmap.ProofBitmap proofBitFlag
            => mapping(uint48 proposalId => bool markedForUpgrade)
    ) internal _historicalMarkings;

    /// @dev Emitted when a verifier is updated
    /// @param proofBitFlag The proof bit flag of the verifier
    /// @param oldVerifier The previous verifier address
    /// @param newVerifier The new verifier address
    event VerifierUpdated(
        LibProofBitmap.ProofBitmap indexed proofBitFlag, address oldVerifier, address newVerifier
    );

    // ---------------------------------------------------------------
    // Functions
    // ---------------------------------------------------------------

    /// @param _owner The initial owner
    constructor(address _inbox, uint8 _numProofsThreshold, address _owner) {
        inbox = _inbox;
        numProofsThreshold = _numProofsThreshold;
        _transferOwnership(_owner);
    }

    /// @notice Sets or updates the verifier for a given proof bit flag
    /// @param _proofBitFlag The proof bit flag used to route proofs
    /// @param _verifierAddr The verifier contract address (must implement IProofVerifier)
    function setVerifier(
        LibProofBitmap.ProofBitmap _proofBitFlag,
        address _verifierAddr
    )
        external
        onlyOwner
    {
        address oldVerifierAddr = _verifiers[_proofBitFlag].addr;
        _verifiers[_proofBitFlag] = InternalVerifier(_verifierAddr, false);
        emit VerifierUpdated(_proofBitFlag, oldVerifierAddr, _verifierAddr);
    }

    /// @notice Instantly upgrades the address of the internal verifier for a given proof bit flag,
    ///         bypassing the timelock if `allowInstantUpgrade` is true for that verifier.
    /// @dev Only callable by the contract owner and only if the old verifier allows instant upgrade.
    /// @param _proofBitFlag The proof bit flag of the internal verifier to upgrade.
    /// @param _verifierAddr The new verifier contract address (must implement IProofVerifier).
    function setVerifierInstant(
        LibProofBitmap.ProofBitmap _proofBitFlag,
        address _verifierAddr
    )
        external
        onlyOwner
    {
        InternalVerifier memory oldVerifier = _verifiers[_proofBitFlag];
        require(oldVerifier.addr != address(0), Surge_InvalidProofBitFlag());
        require(oldVerifier.allowInstantUpgrade, Surge_InstantUpgradeNotAllowed());
        _verifiers[_proofBitFlag] = InternalVerifier(_verifierAddr, false);
        emit VerifierUpdated(_proofBitFlag, oldVerifier.addr, _verifierAddr);
    }

    /// @notice Marks verifiers as upgradeable (allows instant upgrade) or not, according
    /// to bits set in the provided bitmap.
    /// @param _proposalId The proposal that led to conflicting proofs
    /// @param _proofBitmap The full bitmap indicating which verifiers to update.
    /// @param _allowInstantUpgrade Whether instant upgrade should be allowed for these verifiers.
    function markVerifiersUpgradeable(
        uint48 _proposalId,
        LibProofBitmap.ProofBitmap _proofBitmap,
        bool _allowInstantUpgrade
    )
        external
    {
        require(msg.sender == inbox, Surge_CallerIsNotInbox());

        uint8 flags = _proofBitmap.toUint8();
        for (uint8 i = 0; i < 8; ++i) {
            if ((flags & (1 << i)) != 0) {
                LibProofBitmap.ProofBitmap proofBitFlag =
                    LibProofBitmap.ProofBitmap.wrap(uint8(1 << i));
                require(
                    !_historicalMarkings[proofBitFlag][_proposalId],
                    Surge_AlreadyMarkedForProposalId()
                );

                InternalVerifier storage verifier = _verifiers[proofBitFlag];
                require(verifier.addr != address(0), Surge_InvalidProofBitFlag());

                verifier.allowInstantUpgrade = _allowInstantUpgrade;
                _historicalMarkings[proofBitFlag][_proposalId] = true;
            }
        }
    }

    /// @notice Verifies a validity proof for a state transition
    /// @dev This function must revert if the proof is invalid
    /// @param _requiresThreshold `true` if a proof threshold check is needed
    /// @param _transitionsHash The hash of the transitions to verify
    /// @param _proof The proof data containing an array of sub proofs
    function verifyProof(
        bool _requiresThreshold,
        bytes32 _transitionsHash,
        bytes calldata _proof
    )
        external
        view
        returns (LibProofBitmap.ProofBitmap mergedBitmap_)
    {
        SubProof[] memory subProofs = abi.decode(_proof, (SubProof[]));

        for (uint256 i; i < subProofs.length; ++i) {
            LibProofBitmap.ProofBitmap proofBitFlag = subProofs[i].proofBitFlag;
            address verifierAddr = _verifiers[proofBitFlag].addr;
            if (verifierAddr == address(0)) revert Surge_InvalidProofBitFlag();

            // `_proposalAge` is skipped
            IProofVerifier(verifierAddr).verifyProof(0, _transitionsHash, subProofs[i].data);

            mergedBitmap_ = mergedBitmap_.merge(proofBitFlag);
        }

        require(
            !_requiresThreshold || mergedBitmap_.numProofs() >= numProofsThreshold,
            Surge_NumProofsThresholdNotMet()
        );
    }

    // ---------------------------------------------------------------
    // External views
    // ---------------------------------------------------------------

    /// @notice Returns the internal verifier for a given proof bit flag
    /// @param _proofBitFlag The proof bit flag to look up
    /// @return verifier_ The InternalVerifier struct containing address and instant upgrade flag
    function getInternalVerifier(LibProofBitmap.ProofBitmap _proofBitFlag)
        external
        view
        returns (InternalVerifier memory verifier_)
    {
        verifier_ = _verifiers[_proofBitFlag];
        require(verifier_.addr != address(0), Surge_InvalidProofBitFlag());
    }

    /// @notice Returns whether a verifier has been marked for upgrade at a given proposal id
    /// @param _proofBitFlag The proof bit flag to look up
    /// @param _proposalId The proposal id to check
    /// @return markedForUpgrade_ Whether the verifier was marked for upgrade
    function getHistoricalMarking(
        LibProofBitmap.ProofBitmap _proofBitFlag,
        uint48 _proposalId
    )
        external
        view
        returns (bool markedForUpgrade_)
    {
        markedForUpgrade_ = _historicalMarkings[_proofBitFlag][_proposalId];
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error Surge_AlreadyMarkedForProposalId();
    error Surge_CallerIsNotInbox();
    error Surge_InstantUpgradeNotAllowed();
    error Surge_InvalidProofBitFlag();
    error Surge_NumProofsThresholdNotMet();
}
