// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@taiko/blacklist/IMinimalBlacklist.sol";

import "./MerkleClaimable.sol";

/// @title ERC20Airdrop
/// @notice Contract for managing Taiko token airdrop for eligible users.
/// @custom:security-contact security@taiko.xyz
contract ERC20Airdrop is MerkleClaimable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;

    /// @notice The address of the Taiko token contract.
    IERC20 public token;
    /// @notice Blackist address
    IMinimalBlacklist public blacklist;

    /// @notice Event emitted when the blacklist is updated.
    event BlacklistUpdated(address _blacklist);

    /// @notice Errors
    error ADDRESS_BLACKLISTED();

    uint256[48] private __gap;

    /// @notice Modifier to check if the address is not blacklisted.
    /// @param _address The address to check.
    modifier isNotBlacklisted(address _address) {
        if (blacklist.isBlacklisted(_address)) revert ADDRESS_BLACKLISTED();
        _;
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract.
    /// @param _claimStart The start time of the claim period.
    /// @param _claimEnd The end time of the claim period.
    /// @param _merkleRoot The merkle root.
    /// @param _token The address of the token contract.
    function init(
        address _owner,
        uint64 _claimStart,
        uint64 _claimEnd,
        bytes32 _merkleRoot,
        IERC20 _token,
        address _blacklist
    )
        external
        initializer
    {
        __ReentrancyGuard_init();
        __Pausable_init();
        __MerkleClaimable_init(_claimStart, _claimEnd, _merkleRoot);
        _transferOwnership(_owner == address(0) ? _msgSender() : _owner);
        blacklist = IMinimalBlacklist(_blacklist);
        token = _token;
    }

    /// @notice Claims the airdrop for the user.
    /// @param user The address of the user.
    /// @param amount The amount of tokens to claim.
    /// @param proof The merkle proof.
    function claim(
        address user,
        uint256 amount,
        bytes32[] calldata proof
    )
        external
        nonReentrant
        isNotBlacklisted(user)
    {
        // Check if this can be claimed
        _verifyClaim(abi.encode(user, amount), proof);

        // Transfer the tokens from contract
        IERC20(token).transfer(user, amount);
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

    /// @notice Update blacklist contract
    /// @param _blacklist The new blacklist contract address
    /// @dev Only the owner can execute this function
    function updateBlacklist(address _blacklist) external onlyOwner {
        blacklist = IMinimalBlacklist(_blacklist);
        emit BlacklistUpdated(_blacklist);
    }

    /// @notice Internal method to authorize an upgrade
    function _authorizeUpgrade(address) internal virtual override onlyOwner { }
}
