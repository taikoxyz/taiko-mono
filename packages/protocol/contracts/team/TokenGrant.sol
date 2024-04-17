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

    address public constant USTC_TOKEN = address(2);

    event GrantCreated(string memo);
    event GrantWithdrawn(uint256 amount, uint256 cost);

    error INVALID_PARAMS();
    error NOT_WITHDRAWABLE();
    error PERMISSION_DENIED();

    address public recipient;
    uint256 public grantAmount;
    uint256 public amountWithdrawn;
    uint64 public startedAt;
    uint64 public vestDuration;
    uint64 public unlockDuration;
    uint256 public costPerTko;

    function init(
        address _owner,
        address _addressManager,
        address _recipient,
        uint256 _grantAmount,
        uint64 _startedAt,
        uint64 _vestDuration,
        uint64 _unlockDuration,
        uint256 _costPerTko,
        string calldata memo
    )
        external
        initializer
    {
        __Essential_init(_owner, _addressManager);

        if (_recipient == address(0) || _grantAmount == 0 || _startedAt == 0) {
            revert INVALID_PARAMS();
        }

        // These two parameters cannot be both zero
        if (_vestDuration == 0 && _unlockDuration == 0) revert INVALID_PARAMS();

        recipient = _recipient;
        grantAmount = _grantAmount;
        startedAt = _startedAt;
        vestDuration = _vestDuration;
        unlockDuration = _unlockDuration;
        costPerTko = _costPerTko;

        emit GrantCreated(memo);
    }

    function withdraw() external whenNotPaused nonReentrant {
        if (msg.sender != recipient) revert PERMISSION_DENIED();

        uint256 amount = withdrawableAmount();
        if (amount == 0) revert NOT_WITHDRAWABLE();
        amountWithdrawn += amount;

        IERC20 tko = IERC20(resolve(LibStrings.B_TAIKO_TOKEN, false));
        tko.safeTransfer(recipient, amount);

        uint256 cost = amount * costPerTko / 1e18;
        if (cost != 0) {
            IERC20(USTC_TOKEN).safeTransferFrom(msg.sender, owner(), cost);
        }

        emit GrantWithdrawn(amount, cost);
    }

    function vestedAmount() public view returns (uint256) {
        if (block.timestamp <= startedAt) return 0;
        uint256 t = block.timestamp - startedAt;
        return LibTokenGrant.calcVestedAmount(grantAmount, vestDuration, t);
    }

    function unlockedAmount() public view returns (uint256) {
        if (block.timestamp <= startedAt) return 0;
        uint256 t = block.timestamp - startedAt;
        return LibTokenGrant.calcUnlockedAmount(grantAmount, vestDuration, unlockDuration, t);
    }

    function withdrawableAmount() public view returns (uint256) {
        uint256 x = amountWithdrawn;
        return unlockedAmount().max(x) - x;
    }
}
