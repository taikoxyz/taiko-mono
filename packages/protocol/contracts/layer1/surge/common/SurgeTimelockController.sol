// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../verifiers/ISurgeVerifier.sol";
import "../verifiers/LibProofType.sol";
import "src/layer1/based/ITaikoInbox.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title SurgeTimelockController
/// @dev Satisfies stage-2 rollup requirements by blocking executions if a block
/// has not been verified in a while.
/// @custom:security-contact security@nethermind.io
contract SurgeTimelockController is TimelockController, Initializable, UUPSUpgradeable {
    // Slot 0 is assigned in base `Initializable`
    // Slot 1 is assigned in base `AccessControl`
    // Slot 2 and 3 are assigned in base `TimelockController`

    address public taikoInbox; // Slot 4
    address public verifier; // Slot 5

    /// @notice Minimum period for which the verification streak must not have been disrupted
    uint256 public minVerificationStreak; // Slot 6

    // Slots 0 through 6 are assigned
    uint256[43] private _gap;

    error VerificationStreakDisrupted();

    constructor() TimelockController(0, new address[](0), new address[](0), address(0)) {
        _disableInitializers();
    }

    // Initialization functions
    // --------------------------------------------------------------------------------------------

    function init(
        uint256 _minDelay,
        address[] memory _proposers,
        address[] memory _executors,
        address _taikoInbox,
        address _verifier,
        uint256 _minVerificationStreak
    )
        external
        initializer
    {
        __TimelockController_init(_minDelay, _proposers, _executors);

        taikoInbox = _taikoInbox;
        verifier = _verifier;
        minVerificationStreak = _minVerificationStreak;
    }

    function __TimelockController_init(
        uint256 _minDelay,
        address[] memory _proposers,
        address[] memory _executors
    )
        internal
        onlyInitializing
    {
        _setRoleAdmin(TIMELOCK_ADMIN_ROLE, TIMELOCK_ADMIN_ROLE);
        _setRoleAdmin(PROPOSER_ROLE, TIMELOCK_ADMIN_ROLE);
        _setRoleAdmin(EXECUTOR_ROLE, TIMELOCK_ADMIN_ROLE);
        _setRoleAdmin(CANCELLER_ROLE, TIMELOCK_ADMIN_ROLE);

        // self administration
        _setupRole(TIMELOCK_ADMIN_ROLE, address(this));

        // register proposers and cancellers
        for (uint256 i = 0; i < _proposers.length; ++i) {
            _setupRole(PROPOSER_ROLE, _proposers[i]);
            _setupRole(CANCELLER_ROLE, _proposers[i]);
        }

        // register executors
        for (uint256 i = 0; i < _executors.length; ++i) {
            _setupRole(EXECUTOR_ROLE, _executors[i]);
        }

        _minDelay = _minDelay;
    }

    // Timelocked overrides
    // --------------------------------------------------------------------------------------------

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
        onlyRoleOrOpenRole(EXECUTOR_ROLE)
    {
        if (_isVerificationStreakDisrupted()) {
            revert VerificationStreakDisrupted();
        }

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
        onlyRoleOrOpenRole(EXECUTOR_ROLE)
    {
        if (_isVerificationStreakDisrupted()) {
            revert VerificationStreakDisrupted();
        }

        super.executeBatch(_targets, _values, _payloads, _predecessor, _salt);
    }

    // Timelock bypass functions
    // --------------------------------------------------------------------------------------------

    /// @dev Can be used to bypass the timelock when the verifier needs an instant upgrade.
    /// @dev Only the proposer role can call this function, which in the case of Surge is the
    /// primary owner multisig.
    function executeVerifierUpgrade(
        LibProofType.ProofType _proofType,
        address _newVerifier
    )
        external
        onlyRole(PROPOSER_ROLE)
    {
        ISurgeVerifier(verifier).upgradeVerifier(_proofType, _newVerifier);
    }

    // Timelocked functions
    // --------------------------------------------------------------------------------------------

    function updateMinVerificationStreak(uint64 _minVerificationStreak)
        external
        onlyRole(TIMELOCK_ADMIN_ROLE)
    {
        minVerificationStreak = _minVerificationStreak;
    }

    function updateVerifierAddress(address _newVerifier) external onlyRole(TIMELOCK_ADMIN_ROLE) {
        verifier = _newVerifier;
    }

    function updateTaikoInboxAddress(address _newTaikoInbox)
        external
        onlyRole(TIMELOCK_ADMIN_ROLE)
    {
        taikoInbox = _newTaikoInbox;
    }

    // Internal functions
    // --------------------------------------------------------------------------------------------

    /// @dev Returns `true` if an L2 block has not been proposed & verified in a gap of greater
    ///      than `Config.maxVerificationDelay` seconds within the last `minVerificationStreak`
    function _isVerificationStreakDisrupted() internal view returns (bool) {
        uint256 verificationStreakStartedAt =
            ITaikoInbox(taikoInbox).getVerificationStreakStartedAt();
        return (block.timestamp - verificationStreakStartedAt) < minVerificationStreak;
    }

    /// @dev Only the SurgeTimelockController can upgrade itself via the timelock delay mechanism.
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(TIMELOCK_ADMIN_ROLE)
    { }
}
