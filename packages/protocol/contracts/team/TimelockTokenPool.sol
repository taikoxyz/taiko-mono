// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../common/EssentialContract.sol";

/// @title TimelockTokenPool
/// @notice Contract for managing Taiko tokens allocated to different roles and
/// individuals.
///
/// Manages Taiko tokens through a three-state lifecycle: "allocated" to
/// "granted, owned, and locked," and finally to "granted, owned, and unlocked."
/// Allocation doesn't transfer ownership unless specified by grant settings.
/// Conditional allocated tokens can be canceled by invoking `void()`, making
/// them available for other uses. Once granted and owned, tokens are
/// irreversible and their unlock schedules are immutable.
///
/// We should deploy multiple instances of this contract for different roles:
/// - investors
/// - team members, advisors, etc.
/// - grant program grantees
/// @custom:security-contact security@taiko.xyz
contract TimelockTokenPool is EssentialContract {
    using SafeERC20 for IERC20;

    struct Grant {
        uint128 amount;
        // If non-zero, each TKO (1E18) will need some USD stable to purchase.
        uint128 costPerToken;
        // If non-zero, indicates the start time for the recipient to receive
        // tokens, subject to an unlocking schedule.
        uint64 grantStart;
        // If non-zero, indicates the time after which the token to be received
        // will be actually non-zero
        uint64 grantCliff;
        // If non-zero, specifies the total seconds required for the recipient
        // to fully own all granted tokens.
        uint32 grantPeriod;
        // If non-zero, indicates the start time for the recipient to unlock
        // tokens.
        uint64 unlockStart;
        // If non-zero, indicates the time after which the unlock will be
        // actually non-zero
        uint64 unlockCliff;
        // If non-zero, specifies the total seconds required for the recipient
        // to fully unlock all owned tokens.
        uint32 unlockPeriod;
    }

    struct Recipient {
        uint128 amountWithdrawn;
        uint128 costPaid;
        Grant grant;
    }

    /// @notice The Taiko token address.
    address public taikoToken;

    /// @notice The cost token address.
    address public costToken;

    /// @notice The shared vault address.
    address public sharedVault;

    /// @notice The total amount of tokens granted.
    uint128 public totalAmountGranted;

    /// @notice The total amount of tokens voided.
    uint128 public totalAmountVoided;

    /// @notice The total amount of tokens withdrawn.
    uint128 public totalAmountWithdrawn;

    /// @notice The total cost paid.
    uint128 public totalCostPaid;

    /// @notice Mapping of recipient address to grant information.
    mapping(address recipient => Recipient receipt) public recipients;

    uint128[44] private __gap;

    /// @notice Emitted when a grant is made.
    /// @param recipient The grant recipient address.
    /// @param grant The grant.
    event Granted(address indexed recipient, Grant grant);

    /// @notice Emitted when a grant is voided.
    /// @param recipient The grant recipient address.
    /// @param amount The amount of tokens voided.
    event Voided(address indexed recipient, uint128 amount);

    /// @notice Emitted when tokens are withdrawn.
    /// @param recipient The grant recipient address.
    /// @param to The address where the granted and unlocked tokens shall be sent to.
    /// @param amount The amount of tokens withdrawn.
    /// @param cost The cost.
    event Withdrawn(address indexed recipient, address to, uint128 amount, uint128 cost);

    error ALREADY_GRANTED();
    error INVALID_GRANT();
    error INVALID_PARAM();
    error NOTHING_TO_VOID();

    /// @notice Initializes the contract.
    /// @param _owner The owner address.
    /// @param _taikoToken The Taiko token address.
    /// @param _costToken The cost token address.
    /// @param _sharedVault The shared vault address.
    function init(
        address _owner,
        address _taikoToken,
        address _costToken,
        address _sharedVault
    )
        external
        initializer
    {
        __Essential_init(_owner);
        if (_taikoToken == address(0)) revert INVALID_PARAM();
        taikoToken = _taikoToken;

        if (_costToken == address(0)) revert INVALID_PARAM();
        costToken = _costToken;

        if (_sharedVault == address(0)) revert INVALID_PARAM();
        sharedVault = _sharedVault;
    }

    /// @notice Gives a grant to a address with its own unlock schedule.
    /// This transaction should happen on a regular basis, e.g., quarterly.
    /// @param recipient The grant recipient address.
    /// @param g The grant struct.
    function grant(address recipient, Grant memory g) external onlyOwner {
        if (recipient == address(0)) revert INVALID_PARAM();
        if (recipients[recipient].grant.amount != 0) revert ALREADY_GRANTED();

        _validateGrant(g);

        totalAmountGranted += g.amount;
        recipients[recipient].grant = g;
        emit Granted(recipient, g);
    }

    /// @notice Puts a stop to all grants for a given recipient.Tokens already
    /// granted to the recipient will NOT be voided but are subject to the
    /// original unlock schedule.
    /// @param recipient The grant recipient address.
    function void(address recipient) external onlyOwner {
        Recipient storage r = recipients[recipient];
        uint128 amountVoided = _voidGrant(r.grant);

        if (amountVoided == 0) revert NOTHING_TO_VOID();

        totalAmountVoided += amountVoided;
        emit Voided(recipient, amountVoided);
    }

    /// @notice Withdraws all withdrawable tokens.
    function withdraw() external {
        _withdraw(msg.sender, msg.sender);
    }

    /// @notice Withdraws all withdrawable tokens.
    /// @param to The address where the granted and unlocked tokens shall be sent to.
    /// @param sig Signature provided by the grant recipient.
    function withdraw(address to, bytes memory sig) external {
        if (to == address(0)) revert INVALID_PARAM();
        bytes32 hash = keccak256(abi.encodePacked("Withdraw unlocked Taiko token to: ", to));
        address recipient = ECDSA.recover(hash, sig);
        _withdraw(recipient, to);
    }

    /// @notice Returns the summary of the grant for a given recipient.
    /// @param recipient The grant recipient address.
    /// @return amountOwned The amount of tokens owned.
    /// @return amountUnlocked The amount of tokens unlocked.
    /// @return amountWithdrawn The amount of tokens withdrawn.
    /// @return amountToWithdraw The amount of tokens to withdraw.
    /// @return costToWithdraw The cost to withdraw.
    function getMyGrantSummary(address recipient)
        public
        view
        returns (
            uint128 amountOwned,
            uint128 amountUnlocked,
            uint128 amountWithdrawn,
            uint128 amountToWithdraw,
            uint128 costToWithdraw
        )
    {
        Recipient storage r = recipients[recipient];

        amountOwned = _getAmountOwned(r.grant);
        amountUnlocked = _getAmountUnlocked(r.grant);

        amountWithdrawn = r.amountWithdrawn;
        amountToWithdraw = amountUnlocked - amountWithdrawn;

        // Note: precision is maintained at the token level rather than the wei level, otherwise,
        // `costPaid` must be a uint256.
        uint128 _amountUnlocked = amountUnlocked / 1e18; // divide first
        costToWithdraw = _amountUnlocked * r.grant.costPerToken - r.costPaid;
    }

    /// @notice Returns the grant for a given recipient.
    /// @param recipient The grant recipient address.
    /// @return The grant.
    function getMyGrant(address recipient) public view returns (Grant memory) {
        return recipients[recipient].grant;
    }

    function _withdraw(address recipient, address to) private {
        Recipient storage r = recipients[recipient];

        (,,, uint128 amountToWithdraw, uint128 costToWithdraw) = getMyGrantSummary(recipient);

        r.amountWithdrawn += amountToWithdraw;
        r.costPaid += costToWithdraw;

        totalAmountWithdrawn += amountToWithdraw;
        totalCostPaid += costToWithdraw;

        IERC20(taikoToken).transferFrom(sharedVault, to, amountToWithdraw);
        IERC20(costToken).safeTransferFrom(recipient, sharedVault, costToWithdraw);

        emit Withdrawn(recipient, to, amountToWithdraw, costToWithdraw);
    }

    function _voidGrant(Grant storage g) private returns (uint128 amountVoided) {
        uint128 amountOwned = _getAmountOwned(g);

        amountVoided = g.amount - amountOwned;
        g.amount = amountOwned;

        g.grantStart = 0;
        g.grantPeriod = 0;
    }

    function _getAmountOwned(Grant memory g) private view returns (uint128) {
        return _calcAmount(g.amount, g.grantStart, g.grantCliff, g.grantPeriod);
    }

    function _getAmountUnlocked(Grant memory g) private view returns (uint128) {
        return _calcAmount(_getAmountOwned(g), g.unlockStart, g.unlockCliff, g.unlockPeriod);
    }

    function _calcAmount(
        uint128 amount,
        uint64 start,
        uint64 cliff,
        uint64 period
    )
        private
        view
        returns (uint128)
    {
        if (amount == 0) return 0;
        if (start == 0) return amount;
        if (block.timestamp <= start) return 0;

        if (period == 0) return amount;
        if (block.timestamp >= start + period) return amount;

        if (block.timestamp <= cliff) return 0;

        return amount * uint64(block.timestamp - start) / period;
    }

    function _validateGrant(Grant memory g) private pure {
        if (g.amount == 0) revert INVALID_GRANT();
        _validateCliff(g.grantStart, g.grantCliff, g.grantPeriod);
        _validateCliff(g.unlockStart, g.unlockCliff, g.unlockPeriod);
    }

    function _validateCliff(uint64 start, uint64 cliff, uint32 period) private pure {
        if (start == 0 || period == 0) {
            if (cliff > 0) revert INVALID_GRANT();
        } else {
            if (cliff > 0 && cliff <= start) revert INVALID_GRANT();
            if (cliff >= start + period) revert INVALID_GRANT();
        }
    }
}
