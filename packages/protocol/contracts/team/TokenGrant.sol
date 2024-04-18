// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";
import "../libs/LibMath.sol";
import "./LibTokenGrant.sol";

/// @title TokenGrant
/// @notice Contract for managing Taiko tokens allocated to different roles and
/// individuals.
/// @custom:security-contact security@taiko.xyz
contract TokenGrant is EssentialContract {
    using SafeERC20 for IERC20;
    using LibMath for uint256;

    event GrantCreated(string memo);
    event GrantWithdrawn(uint256 amount, uint256 cost);
    event GrantTerminated(uint256 amount);

    error INVALID_PARAMS();
    error NONE_WITHDRAWABLE();
    error PERMISSION_DENIED();

    uint256 public grantAmount;
    uint256 public amountWithdrawn;
    address public feeToken;
    uint64 public startedAt;
    address public recipient;
    uint64 public vestDuration;
    uint64 public vestCliffDuration;
    uint64 public unlockDuration;
    uint128 public costPerTko;

    function init(
        address _owner,
        address _addressManager,
        address _feeToken,
        address _recipient,
        uint256 _grantAmount,
        uint64 _startedAt,
        uint64 _vestDuration,
        uint64 _vestCliffDuration,
        uint64 _unlockDuration,
        uint128 _costPerTko,
        string calldata memo
    )
        external
        initializer
    {
        __Essential_init(_owner, _addressManager);

        if (_recipient == address(0) || _grantAmount == 0 || _startedAt == 0) {
            revert INVALID_PARAMS();
        }

        if (_costPerTko != 0 && _feeToken == address(0)) revert INVALID_PARAMS();

        // These two parameters cannot be both zero
        if (_vestDuration == 0 && _unlockDuration == 0) revert INVALID_PARAMS();

        feeToken = _feeToken;
        recipient = _recipient;
        grantAmount = _grantAmount;
        startedAt = _startedAt;
        vestDuration = _vestDuration;
        vestCliffDuration = _vestCliffDuration;
        unlockDuration = _unlockDuration;
        costPerTko = _costPerTko;

        emit GrantCreated(memo);
    }

    function withdraw(uint256 amount) external whenNotPaused nonReentrant {
        if (msg.sender != recipient) revert PERMISSION_DENIED();

        IERC20 tko = IERC20(resolve(LibStrings.B_TAIKO_TOKEN, false));
        uint256 amountToWithdraw =
            withdrawableAmount().min(tko.balanceOf(address(this))).min(amount);

        if (amountToWithdraw == 0) revert NONE_WITHDRAWABLE();

        amountWithdrawn += amountToWithdraw;
        tko.safeTransfer(recipient, amountToWithdraw);

        uint256 cost = amountToWithdraw * costPerTko / 1e18;
        if (cost != 0) {
            IERC20(feeToken).safeTransferFrom(msg.sender, owner(), cost);
        }

        emit GrantWithdrawn(amountToWithdraw, cost);
    }

    function terminate() external onlyOwner {
        grantAmount = 0;

        IERC20 tko = IERC20(resolve(LibStrings.B_TAIKO_TOKEN, false));
        uint256 balance = tko.balanceOf(address(this));
        tko.safeTransfer(owner(), balance);

        emit GrantTerminated(balance);
    }

    function vestedAmount() public view returns (uint256) {
        if (block.timestamp <= startedAt + vestCliffDuration) return 0;
        uint256 t = block.timestamp - startedAt;
        return LibTokenGrant.calcVestedAmount(grantAmount, vestDuration, t);
    }

    function unlockedAmount() public view returns (uint256) {
        if (block.timestamp <= startedAt + vestCliffDuration) return 0;
        uint256 t = block.timestamp - startedAt;
        return LibTokenGrant.calcUnlockedAmount(grantAmount, vestDuration, unlockDuration, t);
    }

    function withdrawableAmount() public view returns (uint256) {
        uint256 x = amountWithdrawn;
        return unlockedAmount().max(x) - x;
    }
}
