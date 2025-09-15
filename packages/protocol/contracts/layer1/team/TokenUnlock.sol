// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibNames.sol";
import "src/shared/libs/LibMath.sol";
import "../provers/ProverSet.sol";

/// @title TokenUnlock
/// @notice Manages the linear unlocking of Taiko tokens over a four-year period.
/// Tokens purchased off-chain are deposited into this contract directly from the `msg.sender`
/// address. Token withdrawals are permitted linearly over four years starting from the Token
/// Generation Event (TGE), with no withdrawals allowed during the first year.
/// A separate instance of this contract is deployed for each recipient.
/// @custom:security-contact security@taiko.xyz
contract TokenUnlock is EssentialContract {
    using SafeERC20 for IERC20;
    using LibMath for uint256;

    uint256 public constant ONE_YEAR = 365 days;
    uint256 public constant FOUR_YEARS = 4 * ONE_YEAR;
    uint256 public constant TGE_TIMESTAMP = 1_717_588_800;

    address public immutable taikoToken;
    address public immutable proverSetImpl;

    uint256 public amountVested; // slot 1
    address public recipient; // slot 2
    uint64 public startTime;

    mapping(address proverSet => bool valid) public isProverSet; // slot 3

    uint256[47] private __gap;

    /// @notice Emitted when token is vested.
    /// @param amount The newly vested amount.
    event TokenVested(uint256 amount);

    /// @notice Emitted when tokens are withdrawn.
    /// @param to The address tokens will be sent to.
    /// @param amount The amount of tokens withdrawn.
    event TokenWithdrawn(address indexed to, uint256 amount);

    /// @notice Emitted when the recipient changed.
    /// @param oldRecipient The old recipient address.
    /// @param newRecipient The new recipient address.
    event RecipientChanged(address indexed oldRecipient, address indexed newRecipient);

    /// @notice Emitted when a new prover set is created.
    /// @param proverSet The new prover set.
    event ProverSetCreated(address indexed proverSet);

    /// @notice Emitted when TKO are deposited to a prover set.
    /// @param proverSet The prover set.
    /// @param amount The amount of TKO deposited.
    event DepositToProverSet(address indexed proverSet, uint256 amount);

    /// @notice Emitted when the start time is changed.
    /// @param startTime The new start time.
    event StartTimeChanged(uint64 startTime);

    error INVALID_PARAM();
    error NOT_WITHDRAWABLE();
    error NOT_PROVER_SET();
    error PERMISSION_DENIED();
    error TAIKO_TOKEN_NOT_USED_AS_BOND_TOKEN();

    modifier onlyRecipient() {
        if (msg.sender != recipient) revert PERMISSION_DENIED();
        _;
    }

    modifier onlyRecipientOrOwner() {
        if (msg.sender != recipient && msg.sender != owner()) revert PERMISSION_DENIED();
        _;
    }

    constructor(address _taikoToken, address _proverSetImpl) {
        taikoToken = _taikoToken;
        proverSetImpl = _proverSetImpl;
    }

    /// @notice Initializes the contract.
    /// @param _owner The contract owner address.
    /// @param _recipient Who will be the grantee for this contract.
    /// @param _startTime The token generation event timestamp.
    function init(
        address _owner,
        address _recipient,
        uint64 _startTime
    )
        external
        nonZeroAddr(_recipient)
        nonZeroValue(_startTime)
        initializer
    {
        _checkStartTime(_startTime);
        if (_owner == _recipient) revert INVALID_PARAM();

        __Essential_init(_owner);

        recipient = _recipient;
        startTime = _startTime;

        // Bydefault, always delegate to the recipient
        ERC20VotesUpgradeable(taikoToken).delegate(_recipient);
    }

    function setStartTime(uint64 _startTime) external onlyOwner {
        _checkStartTime(_startTime);
        startTime = _startTime;
        emit StartTimeChanged(_startTime);
    }

    /// @notice Vests certain tokens to this contract.
    /// @param _amount The newly vested amount
    function vest(uint128 _amount) external nonReentrant {
        if (_amount == 0) revert INVALID_PARAM();

        amountVested += _amount;
        emit TokenVested(_amount);

        IERC20(taikoToken).safeTransferFrom(msg.sender, address(this), _amount);
    }

    /// @notice Create a new prover set.
    function createProverSet() external onlyRecipient returns (address proverSet_) {
        bytes memory data = abi.encodeCall(ProverSetBase.init, (owner(), address(this)));
        proverSet_ = address(new ERC1967Proxy(proverSetImpl, data));

        isProverSet[proverSet_] = true;
        emit ProverSetCreated(proverSet_);
    }

    function depositToProverSet(
        address _proverSet,
        uint256 _amount
    )
        external
        nonZeroValue(_amount)
        onlyRecipient
    {
        if (!isProverSet[_proverSet]) revert NOT_PROVER_SET();

        emit DepositToProverSet(_proverSet, _amount);
        IERC20(taikoToken).safeTransfer(_proverSet, _amount);
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
        IERC20(taikoToken).safeTransfer(_to, _amount);
    }

    /// @notice Withdraws all tokens to the recipient address.
    function withdraw() external nonReentrant {
        uint256 amount = amountWithdrawable();
        emit TokenWithdrawn(recipient, amount);
        IERC20(taikoToken).safeTransfer(recipient, amount);
    }

    function changeRecipient(address _newRecipient) external onlyRecipientOrOwner {
        if (_newRecipient == address(0) || _newRecipient == recipient) {
            revert INVALID_PARAM();
        }

        emit RecipientChanged(recipient, _newRecipient);
        recipient = _newRecipient;
        ERC20VotesUpgradeable(taikoToken).delegate(_newRecipient);
    }

    /// @notice Delegates token voting right to a delegatee.
    /// @param _delegatee The delegatee to receive the voting right.
    function delegate(address _delegatee) external onlyRecipient nonReentrant {
        ERC20VotesUpgradeable(taikoToken).delegate(_delegatee);
    }

    /// @notice Returns the amount of token withdrawable.
    /// @return The amount of token withdrawable.
    function amountWithdrawable() public view returns (uint256) {
        uint256 balance = IERC20(taikoToken).balanceOf(address(this));
        uint256 locked = _getAmountLocked();

        return balance.max(locked) - locked;
    }

    function _getAmountLocked() private view returns (uint256) {
        uint256 _amountVested = amountVested;
        if (_amountVested == 0) return 0;

        uint256 _startTime = startTime;

        if (block.timestamp < _startTime + ONE_YEAR) return _amountVested;
        if (block.timestamp >= _startTime + FOUR_YEARS) return 0;
        return _amountVested * (_startTime + FOUR_YEARS - block.timestamp) / FOUR_YEARS;
    }

    function _checkStartTime(uint64 _startTime) private view {
        if (block.chainid == 1 || block.chainid == 167_000) {
            require(_startTime >= TGE_TIMESTAMP, INVALID_PARAM());
        }
    }
}
