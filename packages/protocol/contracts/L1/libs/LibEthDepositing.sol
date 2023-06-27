// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

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

    event EthDeposited(TaikoData.EthDeposit deposit);

    error L1_INVALID_ETH_DEPOSIT();

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

        // Put the deposit and the end of the queue.
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

    // When ethDepositMaxCountPerBlock is 32, the average gas cost per
    // EthDeposit is about 2700 gas. We use 21000 so the proposer
    // may earn a small profit if there are 32 deposits included
    // in the block; if there are less EthDeposit to process, the
    // proposer may suffer a loss so the proposer should simply wait
    // for more EthDeposit be become available.
    function processDeposits(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        address feeRecipient
    )
        internal
        returns (TaikoData.EthDeposit[] memory deposits)
    {
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

    function canDepositEthToL2(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 amount
    )
        internal
        view
        returns (bool)
    {
        if (
            amount < config.ethDepositMinAmount
                || amount > config.ethDepositMaxAmount
        ) {
            return false;
        }

        unchecked {
            uint256 numPending =
                state.numEthDeposits - state.nextEthDepositToProcess;

            // We need to make sure we always reverve one slot for the fee
            // deposit
            if (numPending >= config.ethDepositRingBufferSize - 1) {
                return false;
            }
        }

        return true;
    }

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
        return uint256(uint160(addr)) << 96 | amount;
    }
}
