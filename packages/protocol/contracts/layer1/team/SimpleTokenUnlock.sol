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

/// @title SimpleTokenUnlock
/// @notice Fully unlocks granted Taiko tokens 6 months after GRANT_TIMESTAMP.
/// Tokens granted off-chain are deposited into this contract directly from the `msg.sender`
/// address. Token withdrawals from the grant bucket are permitted only at the 6 month mark.
/// A separate instance of this contract is deployed for each recipient.
/// @custom:security-contact security@taiko.xyz
contract SimpleTokenUnlock is EssentialContract {
    using SafeERC20 for IERC20;
    using LibMath for uint256;

    uint256 public constant SIX_MONTHS = 183 days;
    address public constant TAIKO_TOKEN = 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
    uint64 public constant GRANT_TIMESTAMP = 1_764_460_800; // 30 Nov 2025, 00:00:00 UTC

    uint256 public amountGranted; // slot 1
    address public recipient; // 20 bytes

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
        require(msg.sender == recipient, PERMISSION_DENIED());
        _;
    }

    modifier onlyRecipientOrOwner() {
        require((msg.sender == recipient || msg.sender == owner()), PERMISSION_DENIED());
        _;
    }

    constructor(address _resolver) EssentialContract(_resolver) { }

    /// @notice Initializes the contract.
    /// @param _owner The contract owner address.
    /// @param _recipient Who will be the grantee for this contract.
    function init(
        address _owner,
        address _recipient
    )
        external
        nonZeroAddr(_owner)
        nonZeroAddr(_recipient)
        initializer
    {
        require(_owner != _recipient, INVALID_PARAM());

        __Essential_init(_owner);

        recipient = _recipient;
        ERC20VotesUpgradeable(TAIKO_TOKEN).delegate(_recipient);
    }

    /// @notice Grants certain tokens to this contract.
    /// @param _amount The newly granted amount
    function grant(uint128 _amount) external nonReentrant {
        require(_amount != 0, INVALID_PARAM());

        amountGranted += _amount;
        emit TokenGranted(_amount);

        IERC20(TAIKO_TOKEN).safeTransferFrom(msg.sender, address(this), _amount);
    }

    /// @notice Withdraws tokens to an address or recipient.
    /// @param _to The address the token will be sent to.
    function withdraw(address _to) external onlyRecipient nonReentrant {
        if (_to == address(0)) _to = recipient;
        uint256 withdrawable = canWithdraw();
        require(withdrawable > 0, NOT_WITHDRAWABLE());

        IERC20 tko = IERC20(TAIKO_TOKEN);
        emit TokenWithdrawn(_to, withdrawable);
        tko.safeTransfer(_to, withdrawable);
    }

    /// @notice Changes the recipient address.
    /// @param _newRecipient The new recipient address.
    function changeRecipient(address _newRecipient) external onlyRecipientOrOwner nonReentrant {
        require(_newRecipient != address(0) && _newRecipient != recipient, INVALID_PARAM());
        ERC20VotesUpgradeable(TAIKO_TOKEN).delegate(_newRecipient);
        emit RecipientChanged(recipient, _newRecipient);
        recipient = _newRecipient;
    }

    /// @notice Delegates token voting right to a delegatee.
    /// @param _delegatee The delegatee to receive the voting right.
    function delegate(address _delegatee) external onlyRecipient nonReentrant {
        ERC20VotesUpgradeable(TAIKO_TOKEN).delegate(_delegatee);
    }

    /// @notice Returns the amount of token withdrawable.
    /// @return The amount of token withdrawable.
    function canWithdraw() public view returns (uint256) {
        // pre-cliff: can't withdraw any
        if (block.timestamp < GRANT_TIMESTAMP + SIX_MONTHS) {
            return 0;
        }
        // post-cliff: all tokens in the contract are withdrawable
        return amountGranted;
    }
}
