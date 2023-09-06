// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { LibAddress } from "../../libs/LibAddress.sol";
import { LibMath } from "../../libs/LibMath.sol";
import { TaikoData } from "../TaikoData.sol";

/// @title LibDepositing
/// @notice A library for handling Ether deposits in the Taiko protocol.
library LibDepositing {
    using LibAddress for address;
    using LibMath for uint256;

    event EthDeposited(TaikoData.EthDeposit deposit);

    error L1_INVALID_ETH_DEPOSIT();

    /// @dev Deposits Ether into Taiko.
    /// @param state The current state of the Taiko protocol.
    /// @param config The config of the Taiko protocol.
    /// @param resolver The {AddressResolver} instance for address resolution.
    /// @param recipient The address of the deposit recipient.
    function depositEtherToL2(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        address recipient
    )
        internal
    {
        if (!canDepositEthToL2(state, config, msg.value)) {
            revert L1_INVALID_ETH_DEPOSIT();
        }

        address to = resolver.resolve("ether_vault", true);
        if (to == address(0)) {
            to = resolver.resolve("bridge", false);
        }
        to.sendEther(msg.value);

        // Append the deposit to the queue.
        address _recipient = recipient == address(0) ? msg.sender : recipient;
        uint256 slot =
            state.slotA.numEthDeposits % config.ethDepositRingBufferSize;

        // range of msg.value is checked by next line.
        state.ethDeposits[slot] = _encodeEthDeposit(_recipient, msg.value);

        emit EthDeposited(
            TaikoData.EthDeposit({
                recipient: _recipient,
                amount: uint96(msg.value),
                id: state.slotA.numEthDeposits
            })
        );

        // Unchecked is safe:
        // - uint64 can store up to ~1.8 * 1e19, which can represent 584K years
        // if we are depositing at every second
        unchecked {
            state.slotA.numEthDeposits++;
        }
    }

    /// @dev Processes the ETH deposits in a batched manner.
    /// @param state The current state of the Taiko protocol.
    /// @param config The config of the Taiko protocol.
    /// @param feeRecipient Address to receive the deposit fee.
    /// @return deposits The array of processed deposits.
    function processDeposits(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        address feeRecipient
    )
        internal
        returns (TaikoData.EthDeposit[] memory deposits)
    {
        // Calculate the number of pending deposits.
        uint256 numPending =
            state.slotA.numEthDeposits - state.slotA.nextEthDepositToProcess;

        if (numPending < config.ethDepositMinCountPerBlock) {
            deposits = new TaikoData.EthDeposit[](0);
        } else {
            deposits = new TaikoData.EthDeposit[](
               numPending.min(config.ethDepositMaxCountPerBlock)
            );
            uint96 fee = uint96(
                config.ethDepositMaxFee.min(
                    block.basefee * config.ethDepositGas
                )
            );
            uint64 j = state.slotA.nextEthDepositToProcess;
            uint96 totalFee;
            for (uint256 i; i < deposits.length;) {
                uint256 data =
                    state.ethDeposits[j % config.ethDepositRingBufferSize];
                deposits[i] = TaikoData.EthDeposit({
                    recipient: address(uint160(data >> 96)),
                    amount: uint96(data),
                    id: j
                });
                uint96 _fee =
                    deposits[i].amount > fee ? fee : deposits[i].amount;

                // Unchecked is safe:
                // - _fee cannot be bigger than deposits[i].amount
                // - all values are in the same range (uint96) except loop
                // counter, which obviously cannot be bigger than uint95
                // otherwise the function would be gassing out.
                unchecked {
                    deposits[i].amount -= _fee;
                    totalFee += _fee;
                    ++i;
                    ++j;
                }
            }
            state.slotA.nextEthDepositToProcess = j;
            // This is the fee deposit
            state.ethDeposits[state.slotA.numEthDeposits
                % config.ethDepositRingBufferSize] =
                _encodeEthDeposit(feeRecipient, totalFee);

            // Unchecked is safe:
            // - uint64 can store up to ~1.8 * 1e19, which can represent 584K
            // years if we are depositing at every second
            unchecked {
                state.slotA.numEthDeposits++;
            }
        }
    }

    /// @dev Checks if the given deposit amount is valid.
    /// @param state The current state of the Taiko protocol.
    /// @param config The config of the Taiko protocol.
    /// @param amount The amount to deposit.
    /// @return true if the deposit is valid, false otherwise.
    function canDepositEthToL2(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 amount
    )
        internal
        view
        returns (bool)
    {
        // Unchecked is safe:
        // - both numEthDeposits and state.slotA.nextEthDepositToProcess are
        // indexes. One is tracking all deposits (numEthDeposits: unprocessed)
        // and the next to be processed, so nextEthDepositToProcess cannot be
        // bigger than numEthDeposits
        // - ethDepositRingBufferSize cannot be 0 by default (validity checked
        // in LibVerifying)
        unchecked {
            return amount >= config.ethDepositMinAmount
                && amount <= config.ethDepositMaxAmount
                && state.slotA.numEthDeposits - state.slotA.nextEthDepositToProcess
                    < config.ethDepositRingBufferSize - 1;
        }
    }

    /// @dev Computes the hash of the given deposits.
    /// @param deposits The deposits to hash.
    /// @return The computed hash.
    function hashEthDeposits(TaikoData.EthDeposit[] memory deposits)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(deposits));
    }

    /// @dev Encodes the given deposit into a uint256.
    /// @param addr The address of the deposit recipient.
    /// @param amount The amount of the deposit.
    /// @return The encoded deposit.
    function _encodeEthDeposit(
        address addr,
        uint256 amount
    )
        private
        pure
        returns (uint256)
    {
        if (amount >= type(uint96).max) revert L1_INVALID_ETH_DEPOSIT();
        return (uint256(uint160(addr)) << 96) | amount;
    }
}
