// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { LibAddress } from "../../libs/LibAddress.sol";
import { LibMath } from "../../libs/LibMath.sol";
import { SafeCastUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import { TaikoData } from "../TaikoData.sol";
import { TaikoToken } from "../TaikoToken.sol";

/// @title LibDepositing
/// @notice A library for handling L2 fee token deposits in the Taiko protocol.
library LibDepositing {
    using LibAddress for address;
    using LibMath for uint256;
    using SafeCastUpgradeable for uint256;

    event FeeTokenDeposited(TaikoData.FeeTokenDeposit deposit);

    error L1_INVALID_ETH_DEPOSIT();

    /// @dev Deposits Ether or Taiko to Taiko L2 as fee token
    /// @param state The current state of the Taiko protocol.
    /// @param config The config of the Taiko protocol.
    /// @param resolver The {AddressResolver} instance for address resolution.
    /// @param recipient The address of the deposit recipient.
    function depositL2FeeToken(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        address recipient,
        uint96 amount
    )
        internal
    {
        require(amount > 0, "");
        if (!canDepositFeeToken(state, config, amount)) {
            revert L1_INVALID_ETH_DEPOSIT();
        }

        address to = resolver.resolve("ether_vault", true);
        if (to == address(0)) {
            to = resolver.resolve("bridge", false);
        }

        if (config.feeTokenIsEther) {
            require(msg.value == amount, "");
            to.sendEther(amount);
        } else {
            require(msg.value == 0, "");
            TaikoToken tt = TaikoToken(resolver.resolve("taiko_token", false));
            tt.transferFrom(msg.sender, to, amount);
        }

        // Append the deposit to the queue.
        address _recipient = recipient == address(0) ? msg.sender : recipient;
        uint256 slot = state.slotA.numFeeTokenDeposits
            % config.feeTokenDepositRingBufferSize;
        state.feeTokenDeposits[slot] =
            _encodeFeeTokenDeposit(_recipient, amount);

        emit FeeTokenDeposited(
            TaikoData.FeeTokenDeposit({
                recipient: _recipient,
                amount: amount,
                id: state.slotA.numFeeTokenDeposits
            })
        );

        unchecked {
            state.slotA.numFeeTokenDeposits++;
        }
    }

    /// @dev Processes the L2 fee token deposits in a batched manner.
    /// @param state The current state of the Taiko protocol.
    /// @param config The config of the Taiko protocol.
    /// @param feeRecipient Address to receive the deposit fee.
    /// @return deposits The array of processed deposits.
    function processFeeTokenDeposits(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        address feeRecipient
    )
        internal
        returns (TaikoData.FeeTokenDeposit[] memory deposits)
    {
        // Calculate the number of pending deposits.
        uint256 numPending = state.slotA.numFeeTokenDeposits
            - state.slotA.nextFeeTokenDepositToProcess;

        if (numPending < config.feeTokenDepositMinCountPerBlock) {
            deposits = new TaikoData.FeeTokenDeposit[](0);
        } else {
            deposits = new TaikoData.FeeTokenDeposit[](
               numPending.min(config.feeTokenDepositMaxCountPerBlock)
            );
            uint96 fee = uint96(
                config.feeTokenDepositMaxFee.min(
                    block.basefee * config.feeTokenDepositGas
                )
            );
            uint64 j = state.slotA.nextFeeTokenDepositToProcess;
            uint96 totalFee;
            for (uint256 i; i < deposits.length;) {
                uint256 data = state.feeTokenDeposits[j
                    % config.feeTokenDepositRingBufferSize];
                deposits[i] = TaikoData.FeeTokenDeposit({
                    recipient: address(uint160(data >> 96)),
                    amount: uint96(data),
                    id: j
                });
                uint96 _fee =
                    deposits[i].amount > fee ? fee : deposits[i].amount;
                unchecked {
                    deposits[i].amount -= _fee;
                    totalFee += _fee;
                    ++i;
                    ++j;
                }
            }
            state.slotA.nextFeeTokenDepositToProcess = j;
            // This is the fee deposit
            state.feeTokenDeposits[state.slotA.numFeeTokenDeposits
                % config.feeTokenDepositRingBufferSize] =
                _encodeFeeTokenDeposit(feeRecipient, totalFee);
            unchecked {
                state.slotA.numFeeTokenDeposits++;
            }
        }
    }

    /// @dev Checks if the given deposit amount is valid.
    /// @param state The current state of the Taiko protocol.
    /// @param config The config of the Taiko protocol.
    /// @param amount The amount to deposit.
    /// @return true if the deposit is valid, false otherwise.
    function canDepositFeeToken(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 amount
    )
        internal
        view
        returns (bool)
    {
        unchecked {
            return amount >= config.feeTokenDepositMinAmount
                && amount <= config.feeTokenDepositMaxAmount
                && state.slotA.numFeeTokenDeposits
                    - state.slotA.nextFeeTokenDepositToProcess
                    < config.feeTokenDepositRingBufferSize - 1;
        }
    }

    /// @dev Computes the hash of the given deposits.
    /// @param deposits The deposits to hash.
    /// @return The computed hash.
    function hashFeeTokenDeposits(TaikoData.FeeTokenDeposit[] memory deposits)
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
    function _encodeFeeTokenDeposit(
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
