// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Slot Chain native-value custody accounting
/// @dev Maintains the common reserve-plus-pull-credit conservation boundary. Every external
/// mutator in a consumer must call `requireNotEntered` before making component-specific changes.
/// @custom:security-contact security@taiko.xyz
library LibCustodyAccounting {
    struct State {
        uint256 reserves;
        uint256 totalPullCredits;
        mapping(address owner => uint256 amount) pullCredits;
        bool entered;
    }

    /// @dev Rejects a mutation while a native-value callback is in progress.
    /// @param _self The custody state.
    function requireNotEntered(State storage _self) internal view {
        if (_self.entered) revert ReentrantCall();
    }

    /// @dev Returns reserves plus the authoritative aggregate pull-credit liability.
    /// @param _self The custody state.
    /// @return accounted_ The total accounted native value.
    function accounted(State storage _self) internal view returns (uint256 accounted_) {
        return _self.reserves + _self.totalPullCredits;
    }

    /// @dev Returns the caller-independent credit balance for one owner.
    /// @param _self The custody state.
    /// @param _owner The credit owner.
    /// @return amount_ The owner's credit.
    function pullCreditOf(
        State storage _self,
        address _owner
    )
        internal
        view
        returns (uint256 amount_)
    {
        return _self.pullCredits[_owner];
    }

    /// @dev Returns actual balance above all accounted reserves and pull credits.
    /// @param _self The custody state.
    /// @return surplus_ The currently unaccounted native value.
    function surplus(State storage _self) internal view returns (uint256 surplus_) {
        uint256 liabilities = accounted(_self);
        uint256 balance = address(this).balance;
        if (balance < liabilities) revert Insolvent(balance, liabilities);
        return balance - liabilities;
    }

    /// @dev Adds value already held by the consuming contract to its reserve liability.
    /// @param _self The custody state.
    /// @param _amount The amount to reserve.
    function increaseReserve(State storage _self, uint256 _amount) internal {
        requireNotEntered(_self);
        _self.reserves += _amount;
        _assertSolvent(_self);
    }

    /// @dev Removes reserve liability without transferring value, making the amount surplus.
    /// @param _self The custody state.
    /// @param _amount The amount to release.
    function releaseReserve(State storage _self, uint256 _amount) internal {
        requireNotEntered(_self);
        uint256 reserves = _self.reserves;
        if (_amount > reserves) revert InsufficientReserve(reserves, _amount);
        unchecked {
            _self.reserves = reserves - _amount;
        }
    }

    /// @dev Reclassifies reserved value to a beneficiary's pull credit without changing total
    /// accounted value.
    /// @param _self The custody state.
    /// @param _beneficiary The nonzero credit owner.
    /// @param _amount The amount to reclassify.
    function reserveToPullCredit(
        State storage _self,
        address _beneficiary,
        uint256 _amount
    )
        internal
    {
        requireNotEntered(_self);
        if (_beneficiary == address(0)) revert InvalidBeneficiary();
        uint256 reserves = _self.reserves;
        if (_amount > reserves) revert InsufficientReserve(reserves, _amount);
        unchecked {
            _self.reserves = reserves - _amount;
        }
        _self.pullCredits[_beneficiary] += _amount;
        _self.totalPullCredits += _amount;
        _assertSolvent(_self);
    }

    /// @dev Creates a new pull credit backed by already-held, previously unaccounted value.
    /// @param _self The custody state.
    /// @param _beneficiary The nonzero credit owner.
    /// @param _amount The amount to credit.
    function increasePullCredit(
        State storage _self,
        address _beneficiary,
        uint256 _amount
    )
        internal
    {
        requireNotEntered(_self);
        if (_beneficiary == address(0)) revert InvalidBeneficiary();
        _self.pullCredits[_beneficiary] += _amount;
        _self.totalPullCredits += _amount;
        _assertSolvent(_self);
    }

    /// @dev Pays and clears `msg.sender`'s complete pull credit using checks-effects-interactions.
    /// The consuming entry point must derive the owner from the current transaction frame.
    /// @param _self The custody state.
    /// @param _recipient The nonzero claimant-selected recipient.
    /// @return paid_ The transferred amount.
    function claimPullCredit(
        State storage _self,
        address payable _recipient
    )
        internal
        returns (uint256 paid_)
    {
        requireNotEntered(_self);
        if (_recipient == address(0)) revert InvalidRecipient();
        paid_ = _self.pullCredits[msg.sender];
        if (paid_ == 0) revert NoPullCredit();

        _self.entered = true;
        delete _self.pullCredits[msg.sender];
        _self.totalPullCredits -= paid_;
        (bool success,) = _recipient.call{ value: paid_ }("");
        if (!success) revert NativeTransferFailed();
        _self.entered = false;
        _assertSolvent(_self);
    }

    /// @dev Pays an already-authorized amount directly from reserves. The consuming contract is
    /// responsible for authenticating the entitlement before calling this function.
    /// @param _self The custody state.
    /// @param _recipient The nonzero recipient.
    /// @param _amount The reserve amount to pay. Zero succeeds without making a CALL.
    function payReserve(
        State storage _self,
        address payable _recipient,
        uint256 _amount
    )
        internal
    {
        requireNotEntered(_self);
        if (_recipient == address(0)) revert InvalidRecipient();
        uint256 reserves = _self.reserves;
        if (_amount > reserves) revert InsufficientReserve(reserves, _amount);
        if (_amount == 0) return;

        _self.entered = true;
        unchecked {
            _self.reserves = reserves - _amount;
        }
        (bool success,) = _recipient.call{ value: _amount }("");
        if (!success) revert NativeTransferFailed();
        _self.entered = false;
        _assertSolvent(_self);
    }

    /// @dev Sends exactly the current unaccounted balance to a nonzero external sink. A zero
    /// surplus succeeds without making a CALL.
    /// @param _self The custody state.
    /// @param _sink The immutable sink, which must differ from the consuming contract.
    /// @return swept_ The transferred surplus.
    function sweepSurplus(
        State storage _self,
        address payable _sink
    )
        internal
        returns (uint256 swept_)
    {
        requireNotEntered(_self);
        if (_sink == address(0) || _sink == address(this)) revert InvalidSink();
        swept_ = surplus(_self);
        if (swept_ == 0) return 0;

        _self.entered = true;
        (bool success,) = _sink.call{ value: swept_ }("");
        if (!success) revert NativeTransferFailed();
        _self.entered = false;
        _assertSolvent(_self);
    }

    /// @dev Reverts unless the contract balance covers every accounted bucket.
    /// @param _self The custody state.
    function assertSolvent(State storage _self) internal view {
        _assertSolvent(_self);
    }

    /// @dev Checks the common native-value solvency invariant.
    function _assertSolvent(State storage _self) private view {
        uint256 liabilities = accounted(_self);
        uint256 balance = address(this).balance;
        if (balance < liabilities) revert Insolvent(balance, liabilities);
    }

    error ReentrantCall();
    error InvalidBeneficiary();
    error InvalidRecipient();
    error InvalidSink();
    error NoPullCredit();
    error InsufficientReserve(uint256 available, uint256 required);
    error Insolvent(uint256 balance, uint256 liabilities);
    error NativeTransferFailed();
}
