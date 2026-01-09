// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SurgeVerifier } from "./SurgeVerifier.sol";
import { FinalizationStreakInbox } from "./features/FinalizationStreakInbox.sol";
import { LibProofBitmap } from "./libs/LibProofBitmap.sol";
import {
    Ownable2StepUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title SurgeTimelockController
/// @notice Serves as the admin of all protocol contracts
/// @dev Besides timelocking every proposal, this contract blocks execution if chain finalization has
/// been disrupted.
/// @dev This timelock is only relevant if the inbox is using the `FinalizationStreakInbox` feature.
/// @dev Finalization is disrupted when the finalization streak has not been maintained for at least
/// `minFinalizationStreak`seconds.
/// @custom:security-contact security@nethermind.io
contract SurgeTimelockController is TimelockController {
    address public immutable inbox;
    address public immutable proofVerifier;
    uint48 public immutable minFinalizationStreak;

    constructor(
        address _inbox,
        address _proofVerifier,
        uint48 _minFinalizationStreak,
        uint256 _minDelay,
        address[] memory _proposers,
        address[] memory _executors
    )
        TimelockController(_minDelay, _proposers, _executors, address(0))
    {
        inbox = _inbox;
        proofVerifier = _proofVerifier;
        minFinalizationStreak = _minFinalizationStreak;
    }

    // ---------------------------------------------------------------
    // Timelock overrides
    // ---------------------------------------------------------------

    function execute(
        address _target,
        uint256 _value,
        bytes calldata _payload,
        bytes32 _predecessor,
        bytes32 _salt
    )
        public
        payable
        override
    {
        require(!_isFinalizationDisrupted(), FinalizationStreakDisrupted());
        super.execute(_target, _value, _payload, _predecessor, _salt);
    }

    function executeBatch(
        address[] calldata _targets,
        uint256[] calldata _values,
        bytes[] calldata _payloads,
        bytes32 _predecessor,
        bytes32 _salt
    )
        public
        payable
        override
    {
        require(!_isFinalizationDisrupted(), FinalizationStreakDisrupted());
        super.executeBatch(_targets, _values, _payloads, _predecessor, _salt);
    }

    // ---------------------------------------------------------------
    // Timelock bypass
    // ---------------------------------------------------------------

    /// @notice Instantly sets a new verifier contract for a specific proof type, bypassing the timelock.
    /// @dev Only callable by addresses with the PROPOSER_ROLE.
    ///      This function calls the `setVerifierInstant` method on the SurgeVerifier contract to instantly
    ///      upgrade the verifier for a given proof bit flag.
    /// @param _proofBitFlag The bit flag representing the proof type whose verifier is to be updated.
    /// @param _newVerifier The address of the new verifier contract.
    function executeSetVerifierInstant(
        LibProofBitmap.ProofBitmap _proofBitFlag,
        address _newVerifier
    )
        external
        onlyRole(PROPOSER_ROLE)
    {
        SurgeVerifier(proofVerifier).setVerifierInstant(_proofBitFlag, _newVerifier);
    }

    /// @dev This bypasses the timelock and may be called permissionlessly to accept ownership of
    /// the target contracts.
    /// @param _contracts The 2-step ownable contracts for which the timelock controller
    /// is the pending owner.
    function acceptOwnership(address[] memory _contracts) external {
        for (uint256 i; i < _contracts.length; ++i) {
            Ownable2StepUpgradeable(_contracts[i]).acceptOwnership();
        }
    }

    // ---------------------------------------------------------------
    // Internal functions
    // ---------------------------------------------------------------

    /// @dev Returns `true` if the chain finalization has been disrupted.
    function _isFinalizationDisrupted() internal view returns (bool) {
        return FinalizationStreakInbox(inbox).getFinalizationStreak() < minFinalizationStreak;
    }

    // ---------------------------------------------------------------
    // Custom errors
    // ---------------------------------------------------------------

    error FinalizationStreakDisrupted();
}
