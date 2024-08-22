// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../common/EssentialContract.sol";
import "../../common/LibStrings.sol";
import "../../verifiers/IVerifier.sol";
import "../ITaikoL1.sol";

/// @title GuardianProver
/// @notice This prover uses itself as the verifier.
/// @custom:security-contact security@taiko.xyz
contract GuardianProver is IVerifier, EssentialContract {
    /// @notice Contains the index of the guardian in `guardians` plus one (zero means not a
    /// guardian)
    /// @dev Slot 1
    mapping(address => uint256) public guardianIds;

    /// @notice Mapping to store the approvals for a given hash, for a given version
    mapping(uint256 => mapping(bytes32 => uint256)) public approvals;

    /// @notice The set of guardians
    /// @dev Slot 3
    address[] public guardians;

    /// @notice The version of the guardians
    /// @dev Slot 4
    uint32 public version;

    /// @notice The minimum number of guardians required to approve
    uint32 public minGuardians;

    /// @notice True to enable pausing Taiko proving upon conflicting proofs
    bool public provingAutoPauseEnabled;

    /// @notice Mapping from blockId to its latest proof hash
    /// @dev Slot 5
    mapping(uint256 => mapping(uint256 => bytes32)) public latestProofHash;

    uint256[45] private __gap;

    /// @notice Emitted when a guardian proof is approved.
    /// @param addr The address of the guardian.
    /// @param blockId The block ID.
    /// @param blockHash The block hash.
    /// @param approved If the proof is approved.
    /// @param proofData The proof data.
    event GuardianApproval(
        address indexed addr,
        uint256 indexed blockId,
        bytes32 indexed blockHash,
        bool approved,
        bytes proofData
    );

    /// @notice Emitted when the set of guardians is updated.
    /// @param version The new version.
    /// @param guardians The new set of guardians.
    event GuardiansUpdated(uint32 version, address[] guardians);

    /// @notice Emitted when an approval is made.
    /// @param operationId The operation ID.
    /// @param approvalBits The new approval bits.
    /// @param minGuardiansReached If the proof was submitted.
    event Approved(uint256 indexed operationId, uint256 approvalBits, bool minGuardiansReached);

    /// @notice Emitted when a guardian prover submits a different proof for the same block.
    /// @param blockId The block ID.
    /// @param guardian The guardian prover address.
    /// @param currentProofHash The existing proof hash.
    /// @param newProofHash The new and different proof hash.
    /// @param provingPaused True if TaikoL1's proving is paused.
    event ConflictingProofs(
        uint256 indexed blockId,
        address indexed guardian,
        bytes32 currentProofHash,
        bytes32 newProofHash,
        bool provingPaused
    );

    /// @notice Emitted when auto pausing is enabled.
    /// @param enabled True if TaikoL1 proving auto-pause is enabled.
    event ProvingAutoPauseEnabled(bool indexed enabled);

    error GP_INVALID_GUARDIAN();
    error GP_INVALID_GUARDIAN_SET();
    error GP_INVALID_MIN_GUARDIANS();
    error GP_INVALID_STATUS();
    error GV_PERMISSION_DENIED();
    error GV_ZERO_ADDRESS();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _rollupAddressManager The address of the {AddressManager} contract.
    function init(address _owner, address _rollupAddressManager) external initializer {
        __Essential_init(_owner, _rollupAddressManager);
    }

    /// @notice Sets the set of guardians.
    /// @param _newGuardians The new set of guardians.
    /// @param _minGuardians The minimum required to sign.
    /// @param _clearData True to invalidate all existing data.
    function setGuardians(
        address[] memory _newGuardians,
        uint8 _minGuardians,
        bool _clearData
    )
        external
        onlyOwner
    {
        // We need at most 255 guardians (so the approval bits fit in a uint256)
        if (_newGuardians.length == 0 || _newGuardians.length > type(uint8).max) {
            revert GP_INVALID_GUARDIAN_SET();
        }
        // Minimum number of guardians to approve is at least equal or greater than half the
        // guardians (rounded up) and less or equal than the total number of guardians
        if (_minGuardians == 0 || _minGuardians > _newGuardians.length) {
            revert GP_INVALID_MIN_GUARDIANS();
        }

        // Delete the current guardians
        for (uint256 i; i < guardians.length; ++i) {
            delete guardianIds[guardians[i]];
        }
        delete guardians;

        // Set the new guardians
        for (uint256 i; i < _newGuardians.length; ++i) {
            address guardian = _newGuardians[i];
            if (guardian == address(0)) revert GP_INVALID_GUARDIAN();
            // This makes sure there are no duplicate addresses
            if (guardianIds[guardian] != 0) revert GP_INVALID_GUARDIAN_SET();

            // Save and index the guardian
            guardians.push(guardian);
            guardianIds[guardian] = guardians.length;
        }

        // Bump the version so previous approvals get invalidated
        if (_clearData) ++version;

        minGuardians = _minGuardians;
        emit GuardiansUpdated(version, _newGuardians);
    }

    /// @notice Enables or disables proving auto pause.
    /// @param _enable True to enable, false to disable.
    function enableProvingAutoPause(bool _enable) external onlyOwner {
        if (provingAutoPauseEnabled == _enable) revert GP_INVALID_STATUS();
        provingAutoPauseEnabled = _enable;

        emit ProvingAutoPauseEnabled(_enable);
    }

    /// @notice Enables unlimited allowance for Taiko L1 contract.
    /// @param _enable True if unlimited allowance is approved, false to set the allowance to 0.
    function enableTaikoTokenAllowance(bool _enable) external onlyOwner {
        address tko = resolve(LibStrings.B_TAIKO_TOKEN, false);
        address taiko = resolve(LibStrings.B_TAIKO, false);
        IERC20(tko).approve(taiko, _enable ? type(uint256).max : 0);
    }

    /// @notice Withdraws Taiko Token to a given address.
    /// @param _to The recipient address.
    /// @param _amount The amount of Taiko token to withdraw. Use 0 for all balance.
    function withdrawTaikoToken(address _to, uint256 _amount) external onlyOwner {
        if (_to == address(0)) revert GV_ZERO_ADDRESS();

        IERC20 tko = IERC20(resolve(LibStrings.B_TAIKO_TOKEN, false));
        uint256 amount = _amount == 0 ? tko.balanceOf(address(this)) : _amount;
        tko.transfer(_to, amount);
    }

    /// @notice Called by guardians to approve a guardian proof (version 2).
    /// @param _metaV2 The block's metadata (version 2).
    /// @param _tran The valid transition.
    /// @param _proof The tier proof.
    /// @return approved_ True if the minimum number of approvals is acquired, false otherwise.
    function approveV2(
        TaikoData.BlockMetadataV2 calldata _metaV2,
        TaikoData.Transition calldata _tran,
        TaikoData.TierProof calldata _proof
    )
        external
        whenNotPaused
        nonReentrant
        returns (bool)
    {
        return _approve({
            _blockId: _metaV2.id,
            _proofHash: keccak256(abi.encode(_metaV2, _tran, _proof.data)),
            _blockHash: _tran.blockHash,
            _data: abi.encode(_metaV2, _tran, _proof),
            _proofData: _proof.data
        });
    }

    /// @notice Pauses chain proving and verification.
    function pauseTaikoProving() external whenNotPaused {
        if (guardianIds[msg.sender] == 0) revert GP_INVALID_GUARDIAN();

        if (address(this) != resolve(LibStrings.B_CHAIN_WATCHDOG, true)) {
            revert GV_PERMISSION_DENIED();
        }

        ITaikoL1(resolve(LibStrings.B_TAIKO, false)).pauseProving(true);
    }

    /// @inheritdoc IVerifier
    function verifyProof(Context[] calldata _ctxs, TaikoData.TierProof calldata) external view {
        for (uint256 i; i < _ctxs.length; ++i) {
            if (_ctxs[0].msgSender != address(this)) revert GV_PERMISSION_DENIED();
        }
    }

    /// @notice Returns the number of guardians.
    /// @return The number of guardians.
    function numGuardians() public view returns (uint256) {
        return guardians.length;
    }

    /// @notice Internal function to handle the approval process.
    /// @param _blockId The block ID.
    /// @param _proofHash The proof hash.
    /// @param _blockHash The block hash.
    /// @param _data The encoded data.
    /// @param _proofData The proof data.
    /// @return approved_ True if the minimum number of approvals is acquired, false otherwise.
    function _approve(
        uint64 _blockId,
        bytes32 _proofHash,
        bytes32 _blockHash,
        bytes memory _data,
        bytes memory _proofData
    )
        internal
        returns (bool approved_)
    {
        uint256 _version = version;
        bytes32 currProofHash = latestProofHash[_version][_blockId];

        if (currProofHash == 0) {
            latestProofHash[_version][_blockId] = _proofHash;
            currProofHash = _proofHash;
        }

        bool conflicting = currProofHash != _proofHash;
        bool pauseProving = conflicting && provingAutoPauseEnabled
            && address(this) == resolve(LibStrings.B_CHAIN_WATCHDOG, true);

        if (conflicting) {
            latestProofHash[_version][_blockId] = _proofHash;
            emit ConflictingProofs(_blockId, msg.sender, currProofHash, _proofHash, pauseProving);
        }

        if (pauseProving) {
            ITaikoL1(resolve(LibStrings.B_TAIKO, false)).pauseProving(true);
        } else {
            approved_ = _saveApproval(_blockId, _proofHash);
            emit GuardianApproval(msg.sender, _blockId, _blockHash, approved_, _proofData);

            if (approved_) {
                delete approvals[_version][_proofHash];
                delete latestProofHash[_version][_blockId];

                ITaikoL1(resolve(LibStrings.B_TAIKO, false)).proveBlocks(_blockId, _data);
            }
        }
    }

    /// @notice Internal function to save the approval.
    /// @param _blockId The block ID.
    /// @param _proofHash The proof hash.
    /// @return approved_ True if the minimum number of approvals is acquired, false otherwise.
    function _saveApproval(
        uint256 _blockId,
        bytes32 _proofHash
    )
        internal
        returns (bool approved_)
    {
        uint256 id = guardianIds[msg.sender];
        if (id == 0) revert GP_INVALID_GUARDIAN();

        uint256 _version = version;

        unchecked {
            approvals[_version][_proofHash] |= 1 << (id - 1);
        }

        uint256 _approval = approvals[_version][_proofHash];
        approved_ = _isApproved(_approval);
        emit Approved(_blockId, _approval, approved_);
    }

    /// @notice Internal function to check if the minimum number of approvals is reached.
    /// @param _approvalBits The approval bits.
    /// @return True if the minimum number of approvals is reached, false otherwise.
    function _isApproved(uint256 _approvalBits) private view returns (bool) {
        uint256 count;
        uint256 bits = _approvalBits;
        uint256 guardiansLength = guardians.length;
        unchecked {
            for (uint256 i; i < guardiansLength; ++i) {
                if (bits & 1 == 1) ++count;
                if (count == minGuardians) return true;
                bits >>= 1;
            }
        }
        return false;
    }
}
