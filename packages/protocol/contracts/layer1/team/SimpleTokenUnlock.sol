// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibStrings.sol";
import "src/shared/libs/LibMath.sol";

/// @title TokenUnlock
/// @notice Manages the unlocking of Taiko tokens after 6 months.
/// Tokens granted off-chain are deposited into this contract directly from the `msg.sender`
/// address. Token withdrawals are permitted only at the 6 month mark.
/// A separate instance of this contract is deployed for each recipient.
/// @custom:security-contact security@taiko.xyz
contract SimpleTokenUnlock is EssentialContract {
    using SafeERC20 for IERC20;
    using LibMath for uint256;

    uint256 public constant SIX_MONTHS = 182.5 days;

    uint256 public amountGranted; // slot 1
    address public recipient; // 20 bytes
    uint64 public grantTimestamp; // 1764460800 for 30 Nov 2025, 00:00:00 UTC. 8 bytes

    uint256[48] private __gap;

    /// @notice Emitted when token is granted.
    /// @param amount The newly granted amount.
    event TokenGranted(uint256 amount);

    /// @notice Emitted when tokens are withdrawn.
    /// @param to The address tokens will be sent to.
    /// @param amount The amount of tokens withdrawn.
    event TokenWithdrawn(address indexed to, uint256 amount);

    /// @notice Emitted when the recipient changed.
    /// @param oldRecipient The old recipient address.
    /// @param newRecipient The new recipient address.
    event RecipientChanged(address indexed oldRecipient, address indexed newRecipient);

    error INVALID_PARAM();
    error NOT_WITHDRAWABLE();
    error PERMISSION_DENIED();

    modifier onlyRecipient() {
        if (msg.sender != recipient) revert PERMISSION_DENIED();
        _;
    }

    modifier onlyRecipientOrOwner() {
        if (msg.sender != recipient && msg.sender != owner()) revert PERMISSION_DENIED();
        _;
    }

    constructor(address _resolver) EssentialContract(_resolver) { }


    /// @notice Initializes the contract.
    /// @param _owner The contract owner address.
    /// @param _recipient Who will be the grantee for this contract.
    /// @param _grantTimestamp The token generation event timestamp.
    function init(
        address _owner,
        address _recipient,
        uint64 _grantTimestamp
    )
        external
        nonZeroAddr(_recipient)
        nonZeroValue(_grantTimestamp)
        initializer
    {
        if (_owner == _recipient) revert INVALID_PARAM();

        __Essential_init(_owner);

        recipient = _recipient;
        grantTimestamp = _grantTimestamp;
    }

    /// @notice Grants certain tokens to this contract.
    /// @param _amount The newly granted amount
    function grant(uint128 _amount) external nonReentrant {
        if (_amount == 0) revert INVALID_PARAM();

        amountGranted += _amount;
        emit TokenGranted(_amount);

        IERC20(resolve(LibStrings.B_TAIKO_TOKEN, false)).safeTransferFrom(
            msg.sender, address(this), _amount
        );
    }

    /// @notice Withdraws tokens by the recipient.
    /// @param _to The address the token will be sent to.
    /// @param _amount The amount of tokens to withdraw.
    function withdraw(
        address _to,
        uint256 _amount
    )
        external
        nonZeroAddr(_to)
        nonZeroValue(_amount)
        onlyRecipient
        nonReentrant
    {
        if (_amount > amountWithdrawable()) revert NOT_WITHDRAWABLE();
        emit TokenWithdrawn(_to, _amount);
        IERC20(resolve(LibStrings.B_TAIKO_TOKEN, false)).safeTransfer(_to, _amount);
    }

    /// @notice Withdraws all tokens to the recipient address.
    function withdraw() external nonReentrant {
        uint256 amount = amountWithdrawable();
        emit TokenWithdrawn(recipient, amount);
        IERC20(resolve(LibStrings.B_TAIKO_TOKEN, false)).safeTransfer(recipient, amount);
    }

    function changeRecipient(address _newRecipient) external onlyRecipientOrOwner {
        if (_newRecipient == address(0) || _newRecipient == recipient) {
            revert INVALID_PARAM();
        }

        emit RecipientChanged(recipient, _newRecipient);
        recipient = _newRecipient;
    }

    /// @notice Delegates token voting right to a delegatee.
    /// @param _delegatee The delegatee to receive the voting right.
    function delegate(address _delegatee) external onlyRecipient nonReentrant {
        ERC20VotesUpgradeable(resolve(LibStrings.B_TAIKO_TOKEN, false)).delegate(_delegatee);
    }

    /// @notice Returns the amount of token withdrawable.
    /// @return The amount of token withdrawable.
    function amountWithdrawable() public view returns (uint256) {
        IERC20 tko = IERC20(resolve(LibStrings.B_TAIKO_TOKEN, false));
        uint256 balance = tko.balanceOf(address(this));
        if (block.timestamp < grantTimestamp + SIX_MONTHS){
            return 0;
        } else { return balance.min(amountGranted); }
    }
}
