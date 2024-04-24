// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../common/LibStrings.sol";
import "../../verifiers/IVerifier.sol";
import "../tiers/ITierProvider.sol";
import "../ITaikoL1.sol";
import "./Guardians.sol";

/// @title GuardianProver
/// This prover uses itself as the verifier.
/// @custom:security-contact security@taiko.xyz
contract GuardianProver is IVerifier, Guardians {
    using SafeERC20 for IERC20;

    error GV_PERMISSION_DENIED();
    error GV_ZERO_ADDRESS();

    uint256[50] private __gap;

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

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    function init(address _owner, address _addressManager) external initializer {
        __Essential_init(_owner, _addressManager);
    }

    /// @notice Enables unlimited allowance for Taiko L1 contract.
    /// param _enable true if unlimited allowance is approved, false to set the allowance to 0.
    function enableTaikoTokenAllowance(bool _enable) external onlyOwner {
        address tko = resolve(LibStrings.B_TAIKO_TOKEN, false);
        address taiko = resolve(LibStrings.B_TAIKO, false);
        IERC20(tko).safeApprove(taiko, _enable ? type(uint256).max : 0);
    }

    /// @dev Withdraws Taiko Token to a given address.
    /// @param _to The recipient address.
    /// @param _amount The amount of Taiko token to withdraw. Use 0 for all balance.
    function withdrawTaikoToken(address _to, uint256 _amount) external onlyOwner {
        if (_to == address(0)) revert GV_ZERO_ADDRESS();

        IERC20 tko = IERC20(resolve(LibStrings.B_TAIKO_TOKEN, false));
        uint256 amount = _amount == 0 ? tko.balanceOf(address(this)) : _amount;
        tko.safeTransfer(_to, amount);
    }

    /// @dev Called by guardians to approve a guardian proof
    /// @param _meta The block's metadata.
    /// @param _tran The valid transition.
    /// @param _proof The tier proof.
    /// @return approved_ True if the minimum number of approval is acquired, false otherwise.
    function approve(
        TaikoData.BlockMetadata calldata _meta,
        TaikoData.Transition calldata _tran,
        TaikoData.TierProof calldata _proof
    )
        external
        whenNotPaused
        nonReentrant
        returns (bool approved_)
    {
        if (_proof.tier != LibTiers.TIER_GUARDIAN) {
            revert INVALID_PROOF();
        }

        bytes32 hash = keccak256(abi.encode(_meta, _tran, _proof.data));
        approved_ = approve(_meta.id, hash);

        emit GuardianApproval(msg.sender, _meta.id, _tran.blockHash, approved_, _proof.data);

        if (approved_) {
            deleteApproval(hash);
            ITaikoL1(resolve(LibStrings.B_TAIKO, false)).proveBlock(
                _meta.id, abi.encode(_meta, _tran, _proof)
            );
        }
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        Context calldata _ctx,
        TaikoData.Transition calldata,
        TaikoData.TierProof calldata
    )
        external
        view
    {
        if (_ctx.msgSender != address(this)) revert GV_PERMISSION_DENIED();
    }
}
