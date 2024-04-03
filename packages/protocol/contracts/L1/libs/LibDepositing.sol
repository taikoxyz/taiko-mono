// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../common/IAddressResolver.sol";
import "../../libs/LibAddress.sol";
import "../../libs/LibMath.sol";
import "../TaikoData.sol";

/// @title LibDepositing
/// @notice A library for handling Ether deposits in the Taiko protocol.
/// @custom:security-contact security@taiko.xyz
library LibDepositing {
    using LibAddress for address;
    using LibAddress for address payable;
    using LibMath for uint256;

    /// @notice Emitted when Ether is deposited.
    /// @dev Any events defined here must also be defined in TaikoEvents.sol.
    event EthDeposited(TaikoData.EthDeposit deposit);

    /// @dev Any errors defined here must also be defined in TaikoErrors.sol.
    error L1_INVALID_ETH_DEPOSIT();

    /// @dev Deposits Ether to Layer 2.
    /// @param _state Current TaikoData.State.
    /// @param _config Actual TaikoData.Config.
    /// @param _resolver Address resolver interface.
    /// @param _recipient The recipient address.
    function depositEtherToL2(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        IAddressResolver _resolver,
        address _recipient
    )
        internal
    {
        if (!canDepositEthToL2(_state, _config, msg.value)) {
            revert L1_INVALID_ETH_DEPOSIT();
        }

        _resolver.resolve("bridge", false).sendEtherAndVerify(msg.value);

        // Append the deposit to the queue.
        address recipient_ = _recipient == address(0) ? msg.sender : _recipient;
        uint64 n = _state.slotA.numEthDeposits;

        // range of msg.value is checked by next line.
        _state.ethDeposits[n % _config.ethDepositRingBufferSize] =
            _encodeEthDeposit(recipient_, msg.value);

        emit EthDeposited(TaikoData.EthDeposit(recipient_, uint96(msg.value), n));

        // Unchecked is safe:
        // - uint64 can store up to ~1.8 * 1e19, which can represent 584K years
        // if we are depositing at every second
        unchecked {
            _state.slotA.numEthDeposits = n + 1;
        }
    }

    /// @dev Processes the ETH deposits in a batched manner.
    function processDeposits(
        TaikoData.State storage _state,
        TaikoData.Config memory _config
    )
        internal
        returns (TaikoData.EthDeposit[] memory deposits_)
    {
        uint64 n = _state.slotA.nextEthDepositToProcess;
        uint256 count;
        unchecked {
            count = uint256(_state.slotA.numEthDeposits - n).min(_config.ethDepositsPerBlock);
        }

        deposits_ = new TaikoData.EthDeposit[](count);

        for (uint256 i; i < count; ++i) {
            uint256 depositEncoded = _state.ethDeposits[n % _config.ethDepositRingBufferSize];

            deposits_[i] = TaikoData.EthDeposit(
                address(uint160(depositEncoded >> 96)), uint96(depositEncoded), n
            );
            unchecked {
                ++n;
            }
        }

        _state.slotA.nextEthDepositToProcess = n;
    }

    /// @dev Checks if Ether deposit is allowed for Layer 2.
    function canDepositEthToL2(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        uint256 _amount
    )
        internal
        view
        returns (bool)
    {
        // Unchecked is safe:
        // - both numEthDeposits and _state.slotA.nextEthDepositToProcess are
        // indexes. One is tracking all deposits (numEthDeposits: unprocessed)
        // and the next to be processed, so nextEthDepositToProcess cannot be
        // bigger than numEthDeposits
        // - ethDepositRingBufferSize cannot be 0 by default (validity checked
        // in LibVerifying)
        unchecked {
            return _amount >= _config.ethDepositMinAmount && _amount <= type(uint96).max
                && _state.slotA.numEthDeposits - _state.slotA.nextEthDepositToProcess
                    < _config.ethDepositRingBufferSize - 1;
        }
    }

    /// @dev Encodes the given deposit into a uint256.
    /// @param _addr The address of the deposit recipient.
    /// @param _amount The amount of the deposit.
    /// @return The encoded deposit.
    function _encodeEthDeposit(address _addr, uint256 _amount) private pure returns (uint256) {
        if (_amount > type(uint96).max) revert L1_INVALID_ETH_DEPOSIT();
        return (uint256(uint160(_addr)) << 96) | _amount;
    }
}
