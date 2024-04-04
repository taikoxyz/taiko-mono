// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
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
contract TimelockTokenPool is EssentialContract, EIP712Upgradeable {
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

    bytes32 public constant TYPED_HASH = keccak256("Withdrawal(address to,uint256 nonce)");

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

    /// @notice Mapping of recipient address to the next withdrawal nonce.
    mapping(address recipient => uint256 withdrawalNonce) public withdrawalNonces;

    uint128[43] private __gap;

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
    error INVALID_NONCE();
    error INVALID_PARAM();
    error INVALID_SIGNATURE();
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
        if (_taikoToken == address(0) || _costToken == address(0) || _sharedVault == address(0)) {
            revert INVALID_PARAM();
        }

        __Essential_init(_owner);
        __EIP712_init("Taiko TimelockTokenPool", "1");

        taikoToken = _taikoToken;
        costToken = _costToken;
        sharedVault = _sharedVault;
    }

    /// @notice Gives a grant to a address with its own unlock schedule.
    /// This transaction should happen on a regular basis, e.g., quarterly.
    /// @param _recipient The grant recipient address.
    /// @param _grant The grant struct.
    function grant(address _recipient, Grant memory _grant) external onlyOwner nonReentrant {
        if (_recipient == address(0)) revert INVALID_PARAM();
        if (recipients[_recipient].grant.amount != 0) revert ALREADY_GRANTED();

        _validateGrant(_grant);

        totalAmountGranted += _grant.amount;
        recipients[_recipient].grant = _grant;
        emit Granted(_recipient, _grant);
    }

    /// @notice Puts a stop to all grants for a given recipient. Tokens already
    /// granted to the recipient will NOT be voided but are subject to the
    /// original unlock schedule.
    /// @param _recipient The grant recipient address.
    function void(address _recipient) external onlyOwner nonReentrant {
        Recipient storage r = recipients[_recipient];
        uint128 amountVoided = _voidGrant(r.grant);

        if (amountVoided == 0) revert NOTHING_TO_VOID();

        totalAmountVoided += amountVoided;
        emit Voided(_recipient, amountVoided);
    }

    /// @notice Withdraws all withdrawable tokens.
    function withdraw() external whenNotPaused nonReentrant {
        _withdraw(msg.sender, msg.sender);
    }

    /// @notice Withdraws all withdrawable tokens to a designated address.
    /// @param _to The address where the granted and unlocked tokens shall be sent to.
    /// @param _nonce The nonce to be used.
    /// @param _sig Signature provided by the grant recipient.
    function withdraw(
        address _to,
        uint256 _nonce,
        bytes calldata _sig
    )
        external
        whenNotPaused
        nonReentrant
    {
        if (_to == address(0)) revert INVALID_PARAM();

        address account = ECDSA.recover(getWithdrawalHash(_to, _nonce), _sig);
        if (account == address(0)) revert INVALID_SIGNATURE();
        if (withdrawalNonces[account] != _nonce) revert INVALID_NONCE();

        withdrawalNonces[account] += 1;
        _withdraw(account, _to);
    }

    /// @notice Gets the hash to be signed to authorize an withdrawal.
    /// @param _to The destination address.
    /// @param _nonce The withdrawal nonce.
    /// @return The hash to be signed.
    function getWithdrawalHash(address _to, uint256 _nonce) public view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(TYPED_HASH, _to, _nonce)));
    }

    /// @notice Returns the summary of the grant for a given recipient.
    function getMyGrantSummary(address _recipient)
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
        Recipient storage r = recipients[_recipient];

        amountOwned = _getAmountOwned(r.grant);
        amountUnlocked = _getAmountUnlocked(r.grant);

        amountWithdrawn = r.amountWithdrawn;
        amountToWithdraw = amountUnlocked - amountWithdrawn;

        // Note: precision is maintained at the token level rather than the wei level, otherwise,
        // `costPaid` must be a uint256. Therefore, please ignore
        // https://github.com/crytic/slither/wiki/Detector-Documentation#divide-before-multiply
        uint128 _amountUnlocked = amountUnlocked / 1e18; // divide first
        costToWithdraw = _amountUnlocked * r.grant.costPerToken - r.costPaid;
    }

    /// @notice Returns the grant for a given recipient.
    /// @param _recipient The grant recipient address.
    /// @return The grant.
    function getMyGrant(address _recipient) public view returns (Grant memory) {
        return recipients[_recipient].grant;
    }

    function _withdraw(address _recipient, address _to) private {
        Recipient storage r = recipients[_recipient];

        (,,, uint128 amountToWithdraw, uint128 costToWithdraw) = getMyGrantSummary(_recipient);

        r.amountWithdrawn += amountToWithdraw;
        r.costPaid += costToWithdraw;

        totalAmountWithdrawn += amountToWithdraw;
        totalCostPaid += costToWithdraw;

        IERC20(taikoToken).safeTransferFrom(sharedVault, _to, amountToWithdraw);
        IERC20(costToken).safeTransferFrom(_recipient, sharedVault, costToWithdraw);

        emit Withdrawn(_recipient, _to, amountToWithdraw, costToWithdraw);
    }

    function _voidGrant(Grant storage _grant) private returns (uint128 amountVoided) {
        uint128 amountOwned = _getAmountOwned(_grant);

        amountVoided = _grant.amount - amountOwned;
        _grant.amount = amountOwned;

        _grant.grantStart = 0;
        _grant.grantPeriod = 0;
    }

    function _getAmountOwned(Grant memory _grant) private view returns (uint128) {
        return _calcAmount(_grant.amount, _grant.grantStart, _grant.grantCliff, _grant.grantPeriod);
    }

    function _getAmountUnlocked(Grant memory _grant) private view returns (uint128) {
        return _calcAmount(
            _getAmountOwned(_grant), _grant.unlockStart, _grant.unlockCliff, _grant.unlockPeriod
        );
    }

    function _calcAmount(
        uint128 _amount,
        uint64 _start,
        uint64 _cliff,
        uint64 _period
    )
        private
        view
        returns (uint128)
    {
        if (_amount == 0) return 0;
        if (_start == 0) return _amount;
        if (block.timestamp <= _start) return 0;

        if (_period == 0) return _amount;
        if (block.timestamp >= _start + _period) return _amount;

        if (block.timestamp <= _cliff) return 0;

        return _amount * uint64(block.timestamp - _start) / _period;
    }

    function _validateGrant(Grant memory _grant) private pure {
        if (_grant.amount == 0) revert INVALID_GRANT();
        _validateCliff(_grant.grantStart, _grant.grantCliff, _grant.grantPeriod);
        _validateCliff(_grant.unlockStart, _grant.unlockCliff, _grant.unlockPeriod);
    }

    function _validateCliff(uint64 _start, uint64 _cliff, uint32 _period) private pure {
        if (_start == 0 || _period == 0) {
            if (_cliff != 0) revert INVALID_GRANT();
        } else {
            if (_cliff != 0 && _cliff <= _start) revert INVALID_GRANT();
            if (_cliff >= _start + _period) revert INVALID_GRANT();
        }
    }
}
