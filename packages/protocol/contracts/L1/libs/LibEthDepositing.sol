// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import { LibAddress } from "../../libs/LibAddress.sol";
import { LibMath } from "../../libs/LibMath.sol";
import { AddressResolver } from "../../common/AddressResolver.sol";
import { SafeCastUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import { TaikoData } from "../TaikoData.sol";

library LibEthDepositing {
    using LibAddress for address;
    using LibMath for uint256;
    using SafeCastUpgradeable for uint256;

    event EthDeposited(address addr, uint96 amount);

    error L1_INVALID_ETH_DEPOSIT();
    error L1_TOO_MANY_ETH_DEPOSITS();

    function depositEtherToL2(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver
    )
        internal
    {
        if (
            msg.value < config.minEthDepositAmount
                || msg.value > config.maxEthDepositAmount
        ) {
            revert L1_INVALID_ETH_DEPOSIT();
        }

        unchecked {
            uint256 numPending =
                state.numEthDeposits - state.nextEthDepositToProcess;

            // We need to make sure we always reverve one slot for the fee
            // deposit
            if (numPending >= config.ethDepositRingBufferSize - 1) {
                revert L1_TOO_MANY_ETH_DEPOSITS();
            }
        }

        address to = resolver.resolve("ether_vault", true);
        if (to == address(0)) {
            to = resolver.resolve("bridge", false);
        }
        to.sendEther(msg.value);

        // Put the deposit and the end of the queue.
        uint256 slot = state.numEthDeposits % config.ethDepositRingBufferSize;
        state.ethDeposits[slot] = uint256(uint160(msg.sender)) << 96 | msg.value;

        unchecked {
            state.numEthDeposits++;
        }
        emit EthDeposited(msg.sender, uint96(msg.value));
    }

    // When maxEthDepositsPerBlock is 32, the average gas cost per
    // EthDeposit is about 2700 gas. We use 21000 so the proposer
    // may earn a small profit if there are 32 deposits included
    // in the block; if there are less EthDeposit to process, the
    // proposer may suffer a loss so the proposer should simply wait
    // for more EthDeposit be become available.
    function processDeposits(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        address beneficiary
    )
        internal
        returns (TaikoData.EthDeposit[] memory deposits)
    {
        uint256 numPending =
            state.numEthDeposits - state.nextEthDepositToProcess;
        if (numPending < config.minEthDepositsPerBlock) {
            deposits = new TaikoData.EthDeposit[](0);
        } else {
            deposits = new TaikoData.EthDeposit[](
                numPending.min(config.maxEthDepositsPerBlock)
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
                uint256(uint160(beneficiary)) << 96 | totalFee;

            unchecked {
                state.numEthDeposits++;
            }
        }
    }

    function hashEthDeposits(TaikoData.EthDeposit[] memory deposits)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(deposits));
    }
}
