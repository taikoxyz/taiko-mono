// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "./MerkleWhitelist.sol";
import "./AirdropVault.sol";

/// @title ERC20Airdrop
/// @notice Contract for managing Taiko token airdrop for eligible users.
/// @custom:security-contact security@taiko.xyz
contract ERC20Airdrop is MerkleWhitelist {
    using SafeERC20 for IERC20;

    error REENTRANT_CALL();
    error CLAIM_NOT_ONGOING();
    /// @notice The address of the Taiko token contract.

    IERC20 public token;

    AirdropVault public vault;

    uint256 public claimStart;
    uint256 public claimEnd;

    uint256[48] private __gap;

    modifier isClaimPeriod() {
        if (
            claimStart > block.timestamp /*||
            claimEnd > block.timestamp*/
        ) revert CLAIM_NOT_ONGOING();
        _;
    }

    modifier isProofValid(address _user, bytes32[] calldata _proof, uint256 _amount) {
        if (!canClaim(_user, _amount)) revert MINTS_EXCEEDED();
        bytes32 _leaf = leaf(_user, _amount);
        if (!MerkleProof.verify(_proof, root, _leaf)) revert INVALID_PROOF();

        _;
    }

    /// @notice Initializes the contract.
    /// @param _claimStart The start time of the claim period.
    /// @param _claimEnd The end time of the claim period.
    /// @param _merkleRoot The merkle root.
    /// @param _token The address of the token contract.
    function initialize(
        uint256 _claimStart,
        uint256 _claimEnd,
        bytes32 _merkleRoot,
        IERC20 _token,
        IMinimalBlacklist _blacklistAddress,
        AirdropVault _vault
    )
        external
        initializer
    {
        __Context_init();
        __MerkleWhitelist_init(_msgSender(), _merkleRoot, _blacklistAddress);
        _transferOwnership(_msgSender());

        token = _token;
        claimStart = _claimStart;
        claimEnd = _claimEnd;
        vault = _vault;
    }

    /// @notice Claims the airdrop for the user.
    /// @param amount The amount of tokens to claim.
    /// @param proof The merkle proof.
    function claim(
        uint256 amount,
        bytes32[] calldata proof
    )
        external
        isClaimPeriod
        isProofValid(_msgSender(), proof, amount)
    {
        // Register the proof as claimed
        _consumeMint(proof, amount);
        // Transfer the tokens from contract
        IERC20(token).safeTransferFrom(address(vault), _msgSender(), amount);
    }

    /// @notice Withdraw ERC20 tokens from the Vault
    /// @param _token The ERC20 token address to withdraw
    /// @dev Only the owner can execute this function
    function withdrawERC20(IERC20 _token) external onlyOwner {
        // If token address is address(0), use token
        if (address(_token) == address(0)) {
            _token = token;
        }
        // Transfer the tokens to owner
        _token.transfer(owner(), _token.balanceOf(address(this)));
    }
}
