// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { LibAddress } from "../../libs/LibAddress.sol";
import { LibMath } from "../../libs/LibMath.sol";
import { AddressResolver } from "../../common/AddressResolver.sol";
import { TaikoData } from "../TaikoData.sol";

/**
 * @title LibEthDepositing Library
 * @notice A library for handling Ethereum deposits in the Taiko system.
 */
library LibEthDepositing {
    using LibAddress for address;
    using LibMath for uint256;

    event EthDeposited(TaikoData.EthDeposit deposit);

    error L1_INVALID_ETH_DEPOSIT();

    /**
     * @notice Deposit Ethereum to Layer 2.
     * @param state The current state of the Taiko system.
     * @param config Configuration for deposits.
     * @param resolver The AddressResolver instance for address resolution.
     * @param recipient The address of the deposit recipient.
     */
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
        uint256 slot = state.numEthDeposits % config.ethDepositRingBufferSize;
        state.ethDeposits[slot] = _encodeEthDeposit(_recipient, msg.value);

        emit EthDeposited(
            TaikoData.EthDeposit({
                recipient: _recipient,
                amount: uint96(msg.value),
                id: state.numEthDeposits
            })
        );

        unchecked {
            state.numEthDeposits++;
        }
    }

    /**
     * @notice Process the ETH deposits in a batched manner.
     * @param state The current state of the Taiko system.
     * @param config Configuration for deposits.
     * @param feeRecipient Address to receive the deposit fee.
     * @return deposits The array of processed deposits.
     */
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
            state.numEthDeposits - state.nextEthDepositToProcess;

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
            uint64 j = state.nextEthDepositToProcess;
            uint96 totalFee;
            for (uint256 i; i < deposits.length;) {
                uint256 data =
                    state.ethDeposits[j % config.ethDepositRingBufferSize];
                deposits[i] = TaikoData.EthDeposit({
                    recipient: address(uint160(data >> 96)),
                    amount: uint96(data), // works
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
            state.nextEthDepositToProcess = j;
            // This is the fee deposit
            state.ethDeposits[state.numEthDeposits
                % config.ethDepositRingBufferSize] =
                _encodeEthDeposit(feeRecipient, totalFee);
            unchecked {
                state.numEthDeposits++;
            }
        }
    }

    /**
     * @notice Check if the given deposit amount is valid.
     * @param state The current state of the Taiko system.
     * @param config Configuration for deposits.
     * @param amount The amount to deposit.
     * @return true if the deposit is valid, false otherwise.
     */
    function canDepositEthToL2(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 amount
    )
        internal
        view
        returns (bool)
    {
        unchecked {
            return amount >= config.ethDepositMinAmount
                && amount <= config.ethDepositMaxAmount
                && state.numEthDeposits - state.nextEthDepositToProcess
                    < config.ethDepositRingBufferSize - 1;
        }
    }

    /**
     * @notice Compute the hash for a set of deposits.
     * @param deposits Array of EthDeposit to hash.
     * @return The computed hash.
     */
    function hashEthDeposits(TaikoData.EthDeposit[] memory deposits)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(deposits));
    }

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
