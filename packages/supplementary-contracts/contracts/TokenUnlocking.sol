// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "../lib/openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/// @title TokenUnlocking
/// @notice Contract for managing Taiko token unlocking.
///
/// It manages only unlocking and vested tokens will be deposited into this contract (through
/// 'depositToGrantee()' function) when the purchase notice sent out by Taiko, is paid. Unlocking
/// will be a 4-year immutable period, with a 1-year cliff, counting from TGE.
///
/// Vesting will be a regular (quarterly / twice a year, TBD) 'off-chain' legal payment action,
/// where those purschase notices can be exercised (still todo question: is it paid up-front or on
/// withdrawal?). Once tokens are deposited into this contract it cannot be forfeited anymore. If an
/// employment is ended, the company (Taiko) simply does not send out purchase notices anymore, so
/// that more tokens would not be deposited, beside the eligible proportion of that same vesting
/// release period (e.g.: if Bob spent 1 month at Taiko out of that quarterly/half-yearly vesting,
/// those will be deposited after purchased).
///
/// We should deploy multiple instances of this contract per grantee and per grant. So each person
/// should have the same amount of contract deployed as grants granted. (Due to different cost per
/// token / grant).
/// @custom:security-contact security@taiko.xyz
contract TokenUnlocking is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    // Variables, which shall be same for everybody, it is part of the GrantInfo struct.
    struct UnlockTiming {
        /// @notice Shall be TGE date.
        uint64 unlockStartDate;
        /// @notice The end date of cliff period. Shall be 1 year post TGE (date).
        uint64 unlockCliffDate;
        /// @notice Shall be 4 years (period)
        uint32 unlockPeriod;
    }

    // Variables, which shall be unique per grantee
    struct GrantInfo {
        // This variable has to be set, before we handle any withdrawals
        UnlockTiming unlockTiming;
        /// @notice If non-zero, each TKO (1E18) will need some USD stable to purchase.
        uint128 costPerToken;
        /// @notice It is basically the same as "amount deposited" or "total amount vested" (so
        /// far).
        uint128 amountVested;
        /// @notice Represents how many tokens withdrawn already and helps with 2 variables:
        // - The overall "total cost paid" can be also determined by this (costPerToken *
        // amountWithdrawn)
        // - The current "withdrawable amount" is determined by the help of this variable =
        // (amountVested *(% of unlocked) ) - amountWithdrawn
        uint128 amountWithdrawn;
        /// @notice The address of the recipient.
        address grantRecipient;
    }

    // Holding any grant information
    GrantInfo public grantInfo;

    /// todo: still decide if payment if upfront and then the depositToGrantee() is
    /// @notice The Taiko token address.
    address public taikoToken;

    /// @notice The cost token address.
    address public costToken;

    /// @notice The shared vault address, from which tko token deposits will be triggered by the
    /// depositToGrantee() function
    address public sharedVault;

    /// @notice Mapping of recipient address to the next withdrawal nonce.
    mapping(address recipient => uint256 withdrawalNonce) public withdrawalNonces;

    uint256[50] private __gap;

    /// @notice Emitted when unlock period is set.
    /// @param unlockStartDate The TGE date.
    /// @param unlockCliffDate The end date of cliff period.
    /// @param unlockPeriod The unlock period.
    /// @param costPerToken The cost per 1 TKO (1e18).
    event GrantInfoInitialized(
        uint64 unlockStartDate, uint64 unlockCliffDate, uint32 unlockPeriod, uint128 costPerToken
    );

    /// @notice Emitted when a grant is made.
    /// @param recipient The grant recipient address.
    /// @param currentDeposit The current deposited tko amount.
    /// @param totalVestedAmount The total vested amount so far.
    event DepositTriggered(
        address indexed recipient, uint128 currentDeposit, uint128 totalVestedAmount
    );

    /// @notice Emitted when tokens are withdrawn.
    /// @param recipient The grant recipient address.
    /// @param to The address where the granted and unlocked tokens shall be sent to.
    /// @param amount The amount of tokens withdrawn.
    /// @param cost The cost.
    event Withdrawn(address indexed recipient, address to, uint128 amount, uint128 cost);

    error GRANT_NOT_INITIALIZED();
    error INVALID_GRANTEE();
    error INVALID_NONCE();
    error INVALID_PARAM();
    error INVALID_SIGNATURE();
    error WRONG_GRANTEE_RECIPIENT();

    /// @notice Initializes the contract.
    /// @param _owner The owner address.
    /// @param _taikoToken The Taiko token address.
    /// @param _costToken The cost token address.
    /// @param _sharedVault The shared vault address.
    /// @param _grantRecipient Who will be the grantee for this contract.
    function init(
        address _owner,
        address _taikoToken,
        address _costToken,
        address _sharedVault,
        address _grantRecipient
    )
        external
        initializer
    {
        if (
            _taikoToken == address(0) || _costToken == address(0) || _sharedVault == address(0)
                || _grantRecipient == address(0)
        ) {
            revert INVALID_PARAM();
        }

        __Ownable_init(_owner);

        taikoToken = _taikoToken;
        costToken = _costToken;
        sharedVault = _sharedVault;

        // Initializing here, that this contract belongs to this grant recipient
        grantInfo.grantRecipient = _grantRecipient;
    }

    /// @notice Set correct unlocking dates (TGE, cliff, duration) and the
    /// @param _unlockStartDate TGE date.
    /// @param _unlockCliffDate The end date of cliff period.
    /// @param _unlockPeriod The unlock period (4 years acc. to current token grant letter).
    /// @param _costPerToken The price per 1 TKO (1e18).
    function initializeGrant(
        uint64 _unlockStartDate,
        uint64 _unlockCliffDate,
        uint32 _unlockPeriod,
        uint128 _costPerToken
    )
        external
        onlyOwner
    {
        // Theoretically the rest can be 0, if we want no cliff or no unlock period.
        if (_unlockStartDate == 0) revert INVALID_PARAM();

        // Timing related data
        grantInfo.unlockTiming.unlockStartDate = _unlockStartDate;
        grantInfo.unlockTiming.unlockCliffDate = _unlockCliffDate;
        grantInfo.unlockTiming.unlockPeriod = _unlockPeriod;

        //Price data (as the rest(amount of vested and withdrawn are 0 at this time ))
        grantInfo.costPerToken = _costPerToken;

        emit GrantInfoInitialized(_unlockStartDate, _unlockCliffDate, _unlockPeriod, _costPerToken);
    }

    /// @notice Triggers a deposits through the vault to this contract.
    /// This transaction should happen on a regular basis, e.g., quarterly.
    /// @param _recipient The grant recipient address.
    /// @param _currentDeposit The current deposit.
    function depositToGrantee(
        address _recipient,
        uint128 _currentDeposit
    )
        external
        onlyOwner
        nonReentrant
    {
        if (_recipient != grantInfo.grantRecipient) revert INVALID_GRANTEE();
        if (grantInfo.unlockTiming.unlockStartDate == 0) revert GRANT_NOT_INITIALIZED();

        // This contract shall be appproved() on the sharedVault for the given _currentDeposit
        // amount
        IERC20(taikoToken).safeTransferFrom(sharedVault, address(this), _currentDeposit);

        grantInfo.amountVested += _currentDeposit;

        emit DepositTriggered(_recipient, _currentDeposit, grantInfo.amountVested);
    }

    /// @notice Withdraws all withdrawable tokens.
    function withdraw() external nonReentrant {
        _withdraw(msg.sender, msg.sender);
    }

    /// @notice Withdraws all withdrawable tokens to a designated address.
    /// @param _to The address where the granted and unlocked tokens shall be sent to.
    /// @param _nonce The nonce to be used.
    /// @param _sig Signature provided by the grant recipient.
    function withdraw(address _to, uint256 _nonce, bytes calldata _sig) external nonReentrant {
        if (_to == address(0)) revert INVALID_PARAM();

        address account =
            ECDSA.recover(getWithdrawalHash(grantInfo.grantRecipient, _to, _nonce), _sig);
        if (account == address(0)) revert INVALID_SIGNATURE();
        if (withdrawalNonces[account] != _nonce) revert INVALID_NONCE();

        withdrawalNonces[account] += 1;
        _withdraw(account, _to);
    }

    /// @notice Gets the hash to be signed to authorize an withdrawal.
    /// @param _grantOwner The owner of the grant.
    /// @param _to The destination address.
    /// @param _nonce The withdrawal nonce.
    /// @return The hash to be signed.
    function getWithdrawalHash(
        address _grantOwner,
        address _to,
        uint256 _nonce
    )
        public
        view
        returns (bytes32)
    {
        return keccak256(abi.encode("WITHDRAW_GRANT", _grantOwner, address(this), _to, _nonce));
    }

    /// @notice Returns the summary of the grant for a given recipient. Does not reverts if this
    /// contract does not belong to _recipient, but returns all 0.
    function getMyGrantSummary(address _recipient)
        public
        view
        returns (
            uint128 amountVested,
            uint128 amountUnlocked,
            uint128 amountWithdrawn,
            uint128 amountToWithdraw,
            uint128 costToWithdraw
        )
    {
        if (_recipient != grantInfo.grantRecipient) {
            // This unlocking contract is not for the supplied _recipient, so obviously 0
            // everywhere.
            return (0, 0, 0, 0, 0);
        }

        amountVested = grantInfo.amountVested;
        /// @notice Amount unlocked obviously represents the all unlocked per vested tokens so:
        /// (amountUnlocked >= amountToWithdraw) && (amountUnlocked >= amountWithdrawn) -> Always
        /// true. Because there might be some amount already withdrawn, but amountUnlocked does not
        /// take into account that amount (!).
        amountUnlocked = _calcAmountUnlocked(
            grantInfo.amountVested,
            grantInfo.unlockTiming.unlockStartDate,
            grantInfo.unlockTiming.unlockCliffDate,
            grantInfo.unlockTiming.unlockPeriod
        );

        amountWithdrawn = grantInfo.amountWithdrawn;
        amountToWithdraw = amountUnlocked - amountWithdrawn;

        // Note: precision is maintained at the token level rather than the wei level, otherwise,
        // `costToWithdraw` must be a uint256. Therefore, please ignore
        // https://github.com/crytic/slither/wiki/Detector-Documentation#divide-before-multiply
        costToWithdraw = (amountToWithdraw / 1e18) * grantInfo.costPerToken;
    }

    /// @notice Returns the grant for a given recipient. Reverts if this contract does not belong to
    /// _recipient.
    /// @param _recipient The grant recipient address.
    /// @return The grant.
    function getGrantInfo(address _recipient) public view returns (GrantInfo memory) {
        if (_recipient != grantInfo.grantRecipient) {
            // This unlocking contract is not for the supplied _recipient, so revert.
            revert WRONG_GRANTEE_RECIPIENT();
        }

        return grantInfo;
    }

    function _withdraw(address _recipient, address _to) private {
        if (_recipient != grantInfo.grantRecipient) {
            // This unlocking contract is not for the supplied _recipient, so revert.
            revert WRONG_GRANTEE_RECIPIENT();
        }

        (,,, uint128 amountToWithdraw, uint128 costToWithdraw) = getMyGrantSummary(_recipient);

        grantInfo.amountWithdrawn = amountToWithdraw;

        // _recipient pays the price -> todo: still validate if there is a need for that, OR the
        // purchase notice actually also means we need to pay up-front to get our tokens deposited
        // here. If so, there is no need to maintain the costToken and the pricePerToken variables,
        // since they are paid already.
        IERC20(costToken).safeTransferFrom(_recipient, sharedVault, costToWithdraw);
        // _to address get's the tokens
        IERC20(taikoToken).safeTransferFrom(sharedVault, _to, amountToWithdraw);

        emit Withdrawn(_recipient, _to, amountToWithdraw, costToWithdraw);
    }

    function _calcAmountUnlocked(
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
        // Remember! Cliff can be (theoretically) 0
        if (_cliff != 0 && block.timestamp <= _cliff) return 0;
        // Remember! Period can also be theoretically 0
        if (_period == 0) return _amount;
        if (block.timestamp >= _start + _period) return _amount;
        // Else, calculate the proportion
        return _amount * uint64(block.timestamp - _start) / _period;
    }
}
