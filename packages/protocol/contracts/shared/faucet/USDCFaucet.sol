// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ICircleFiatToken } from "../thirdparty/ICircleFiatToken.sol";

/// @title USDCFaucet
/// @notice Simple cooldown-based faucet for Circle-compatible USDC deployments.
/// @custom:security-contact security@taiko.xyz
contract USDCFaucet is Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant CLAIM_COOLDOWN = 1 days;

    /// @notice Address of the USDC token this faucet mints from.
    address public immutable token;

    /// @notice Amount minted per successful claim.
    uint256 public claimAmount;

    mapping(address account => uint256 timestamp) private _nextClaimAt;

    event Claimed(address indexed account, uint256 amount, uint256 nextClaimAt);
    event ClaimAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event USDCWithdrawn(address indexed to, uint256 amount);

    error FAUCET_INVALID_TOKEN();
    error FAUCET_INVALID_OWNER();
    error FAUCET_INVALID_CLAIM_AMOUNT();
    error FAUCET_INVALID_RECIPIENT();
    error FAUCET_COOLDOWN_ACTIVE(uint256 nextClaimAt);

    constructor(address _token, address _owner, uint256 _claimAmount) {
        if (_token == address(0)) revert FAUCET_INVALID_TOKEN();
        if (_owner == address(0)) revert FAUCET_INVALID_OWNER();
        if (_claimAmount == 0) revert FAUCET_INVALID_CLAIM_AMOUNT();

        token = _token;
        claimAmount = _claimAmount;
        _transferOwnership(_owner);
    }

    /// @notice Returns the next timestamp at which an account may claim.
    /// @param _account The account to check.
    /// @return nextClaimAt_ The next eligible claim time.
    function nextClaimAt(address _account) external view returns (uint256 nextClaimAt_) {
        nextClaimAt_ = _nextClaimAt[_account];
    }

    /// @notice Mints USDC to the caller if the cooldown has elapsed.
    function claim() external {
        uint256 nextClaimAt_ = _nextClaimAt[msg.sender];
        if (block.timestamp < nextClaimAt_) revert FAUCET_COOLDOWN_ACTIVE(nextClaimAt_);

        uint256 nextClaimTimestamp = block.timestamp + CLAIM_COOLDOWN;
        _nextClaimAt[msg.sender] = nextClaimTimestamp;
        ICircleFiatToken(token).mint(msg.sender, claimAmount);

        emit Claimed(msg.sender, claimAmount, nextClaimTimestamp);
    }

    /// @notice Updates the per-claim USDC amount.
    /// @param _claimAmount The new claim amount.
    function setClaimAmount(uint256 _claimAmount) external onlyOwner {
        if (_claimAmount == 0) revert FAUCET_INVALID_CLAIM_AMOUNT();

        uint256 oldClaimAmount = claimAmount;
        claimAmount = _claimAmount;

        emit ClaimAmountUpdated(oldClaimAmount, _claimAmount);
    }

    /// @notice Withdraws USDC held by this faucet.
    /// @param _to The recipient of the withdrawal.
    /// @param _amount The amount to transfer.
    function withdrawUSDC(address _to, uint256 _amount) external onlyOwner {
        if (_to == address(0)) revert FAUCET_INVALID_RECIPIENT();
        IERC20(token).safeTransfer(_to, _amount);

        emit USDCWithdrawn(_to, _amount);
    }
}
