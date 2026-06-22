//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract FeeManagerBase {
    uint16 constant MAX_BP = 10_000;

    uint16 _feeBP; // the percentage of gas fee in basis point;

    // 1356a63b
    error BP_Not_Valid();
    // 9bb42d4b
    error Insufficient_Funds();
    // c40a532b
    error Withdrawal_Failed();

    /// @dev access-controlled
    function setBp(uint16 _newBp) public virtual {
        if (_newBp > MAX_BP) {
            revert BP_Not_Valid();
        }
        _feeBP = _newBp;
    }

    function getBp() public view returns (uint16) {
        return _feeBP;
    }

    function withdraw(address beneficiary, uint256 amount) public virtual {
        if (amount > address(this).balance) {
            revert Insufficient_Funds();
        }

        _refund(beneficiary, amount);
    }

    modifier collectFee() {
        uint256 txFee;
        if (_feeBP > 0) {
            uint256 gasBefore = gasleft();
            _;
            uint256 gasAfter = gasleft();
            txFee = ((gasBefore - gasAfter) * tx.gasprice * _feeBP) / MAX_BP;
            if (msg.value < txFee) {
                revert Insufficient_Funds();
            }
        } else {
            _;
        }

        // refund excess
        if (msg.value > 0) {
            uint256 excess = msg.value - txFee;
            if (excess > 0) {
                // refund the sender, rather than the caller
                // @dev may fail subsequent call(s), if the caller were a contract
                // that might need to make subsequent calls requiring ETh transfers
                _refund(tx.origin, excess);
            }
        }
    }

    function _refund(address recipient, uint256 amount) private {
        (bool success,) = recipient.call{value: amount}("");
        if (!success) {
            revert Withdrawal_Failed();
        }
    }
}
