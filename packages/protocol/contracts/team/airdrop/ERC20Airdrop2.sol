// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../libs/LibMath.sol";
import "./MerkleClaimable.sol";

/// @title ERC20Airdrop2
/// @notice Contract for managing Taiko token airdrop for eligible users, but the
/// withdrawal is not immediate and is subject to a withdrawal window.
/// @custom:security-contact security@taiko.xyz
contract ERC20Airdrop2 is MerkleClaimable {
    using LibMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant WITHDRAWAL_GRACE_PERIOD = 30 days;

    /// @notice The address of the token contract.
    address public token;

    /// @notice The address of the vault contract.
    address public vault;

    /// @notice Length of the withdrawal window.
    uint64 public withdrawalWindow;

    /// @notice Represents the token amount for which the user has claimed.
    mapping(address addr => uint256 amountClaimed) public claimedAmount;

    /// @notice Represents the already withdrawn amount.
    mapping(address addr => uint256 amountWithdrawn) public withdrawnAmount;

    uint256[46] private __gap;

    /// @notice Event emitted when a user withdraws their tokens.
    /// @param user The address of the user.
    /// @param amount The amount of tokens withdrawn.
    event Withdrawn(address user, uint256 amount);

    error WITHDRAWALS_NOT_ONGOING();

    modifier ongoingWithdrawals() {
        if (
            claimEnd > block.timestamp
                || claimEnd + withdrawalWindow + WITHDRAWAL_GRACE_PERIOD < block.timestamp
        ) {
            revert WITHDRAWALS_NOT_ONGOING();
        }
        _;
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract.
    /// @param _claimStart The start time of the claim period.
    /// @param _claimEnd The end time of the claim period.
    /// @param _merkleRoot The merkle root.
    /// @param _token The address of the token contract.
    /// @param _vault The address of the vault contract.
    /// @param _withdrawalWindow The length of the withdrawal window.
    function init(
        address _owner,
        uint64 _claimStart,
        uint64 _claimEnd,
        bytes32 _merkleRoot,
        address _token,
        address _vault,
        uint64 _withdrawalWindow
    )
        external
        initializer
    {
        __Essential_init(_owner);
        __MerkleClaimable_init(_claimStart, _claimEnd, _merkleRoot);

        token = _token;
        vault = _vault;
        withdrawalWindow = _withdrawalWindow;
    }

    /// @notice Claims the airdrop for the user.
    /// @param user The address of the user.
    /// @param amount The amount of tokens to claim.
    /// @param proof The merkle proof.
    function claim(address user, uint256 amount, bytes32[] calldata proof) external nonReentrant {
        // Check if this can be claimed
        _verifyClaim(abi.encode(user, amount), proof);

        // Assign the tokens
        claimedAmount[user] += amount;
    }

    /// @notice External withdraw function
    /// @param user User address
    function withdraw(address user) external ongoingWithdrawals nonReentrant {
        (, uint256 amount) = getBalance(user);
        withdrawnAmount[user] += amount;
        IERC20(token).safeTransferFrom(vault, user, amount);

        emit Withdrawn(user, amount);
    }

    /// @notice Getter for the balance and withdrawal amount per given user
    /// The 2nd airdrop is subject to an unlock period. User has to claim his
    /// tokens (within claimStart and claimEnd), but not immediately
    /// withdrawable. With a time of X (withdrawalWindow) it becomes fully
    /// withdrawable - and unlocks linearly.
    /// @param user User address
    /// @return balance The balance the user successfully claimed
    /// @return withdrawableAmount The amount available to withdraw
    function getBalance(address user)
        public
        view
        returns (uint256 balance, uint256 withdrawableAmount)
    {
        balance = claimedAmount[user];
        // If balance is 0 then there is no balance and withdrawable amount
        if (balance == 0) return (0, 0);
        // Balance might be positive before end of claiming (claimEnd - if claimed already) but
        // withdrawable is 0.
        if (block.timestamp < claimEnd) return (balance, 0);

        // Hard cap timestamp - so range cannot go over - to get more allocation over time.
        uint256 timeBasedAllowance = balance
            * (block.timestamp.min(claimEnd + withdrawalWindow) - claimEnd) / withdrawalWindow;

        withdrawableAmount = timeBasedAllowance - withdrawnAmount[user];
    }
}
