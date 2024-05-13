// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title TokenUnlocking
/// @notice Manages the linear unlocking of Taiko tokens over a four-year period.
/// Tokens purchased off-chain are deposited into this contract directly from the `msg.sender`
/// address. Token withdrawals are permitted linearly over four years starting from the Token
/// Generation Event (TGE), with no withdrawals allowed during the first year.
/// A separate instance of this contract is deployed for each recipient.
/// @custom:security-contact security@taiko.xyz
contract TokenUnlocking is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    uint256 public constant ONE_YEAR = 365 days;
    uint256 public constant FOUR_YEARS = 4 * ONE_YEAR;

    uint256 public amountVested;
    uint256 public amountWithdrawn;
    address public recipient;
    address public taikoToken;
    uint64 public tgeTimestamp;

    uint256[46] private __gap;

    /// @notice Emitted when token is vested.
    /// @param amount The newly vested amount.
    event TokenVested(uint256 amount);

    /// @notice Emitted when tokens are withdrawn.
    /// @param to The address tokens will be sent to.
    /// @param amount The amount of tokens withdrawn.
    event TokenWithdrawn(address to, uint256 amount);

    error INVALID_PARAM();
    error NOT_WITHDRAWABLE();
    error PERMISSION_DENIED();

    modifier onlyRecipient() {
        if (msg.sender != recipient) revert PERMISSION_DENIED();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract.
    /// @param _owner The contract owner address.
    /// @param _taikoToken The Taiko token address.
    /// @param _recipient Who will be the grantee for this contract.
    /// @param _tgeTimestamp The token generation event timestamp.
    function init(
        address _owner,
        address _taikoToken,
        address _recipient,
        uint64 _tgeTimestamp
    )
        external
        initializer
    {
        if (
            _owner == _recipient || _owner == address(0) || _recipient == address(0)
                || _taikoToken == address(0) || _tgeTimestamp == 0
        ) {
            revert INVALID_PARAM();
        }

        _transferOwnership(_owner);

        recipient = _recipient;
        taikoToken = _taikoToken;
        tgeTimestamp = _tgeTimestamp;
    }

    /// @notice Deposits certain tokens to this contract.
    /// @param _amount The newly vested amount
    function deposit(uint128 _amount) external nonReentrant {
        if (_amount == 0) revert INVALID_PARAM();

        amountVested += _amount;
        emit TokenVested(_amount);

        IERC20(taikoToken).safeTransferFrom(msg.sender, address(this), _amount);
    }

    /// @notice Withdraws all withdrawable tokens.
    /// @param _to The address the token will be sent to.
    function withdraw(address _to) external onlyRecipient nonReentrant {
        uint256 amount = amountWithdrawable();
        if (amount == 0) revert NOT_WITHDRAWABLE();

        amountWithdrawn += amount;
        address to = _to == address(0) ? recipient : _to;
        emit TokenWithdrawn(to, amount);

        IERC20(taikoToken).safeTransfer(to, amount);
    }

    /// @notice Delegates token voting right to a delegatee.
    /// @param _delegatee The delegatee to receive the voting right.
    function delegate(address _delegatee) external onlyRecipient nonReentrant {
        ERC20VotesUpgradeable(taikoToken).delegate(_delegatee);
    }

    /// @notice Returns the amount of token withdrawable.
    /// @return The amount of token withdrawable.
    function amountWithdrawable() public view returns (uint256) {
        return _getAmountUnlocked() - amountWithdrawn;
    }

    function _getAmountUnlocked() private view returns (uint256) {
        uint256 _amountVested = amountVested;
        if (_amountVested == 0) return 0;

        uint256 _tgeTimestamp = tgeTimestamp;

        if (block.timestamp < _tgeTimestamp + ONE_YEAR) return 0;
        if (block.timestamp >= _tgeTimestamp + FOUR_YEARS) return _amountVested;
        return _amountVested * (block.timestamp - _tgeTimestamp) / FOUR_YEARS;
    }
}
