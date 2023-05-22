// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {LibAddress} from "../../libs/LibAddress.sol";
import {LibMath} from "../../libs/LibMath.sol";
import {AddressResolver} from "../../common/AddressResolver.sol";
import {SafeCastUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../TaikoData.sol";

library LibEthDepositing {
    using LibAddress for address;
    using LibMath for uint256;
    using SafeCastUpgradeable for uint256;

    event EthDeposited(TaikoData.EthDeposit deposit);

    error L1_INVALID_ETH_DEPOSIT();

    function depositEtherToL2(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver
    ) internal {
        if (msg.value < config.minEthDepositAmount || msg.value > config.maxEthDepositAmount) {
            revert L1_INVALID_ETH_DEPOSIT();
        }

        TaikoData.EthDeposit memory deposit =
            TaikoData.EthDeposit({recipient: msg.sender, amount: uint96(msg.value)});

        address to = resolver.resolve("ether_vault", true);
        if (to == address(0)) {
            to = resolver.resolve("bridge", false);
        }
        to.sendEther(msg.value);

        state.ethDeposits.push(deposit);
        emit EthDeposited(deposit);
    }

    function processDeposits(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        address beneficiary
    ) internal returns (bytes32 depositsRoot, TaikoData.EthDeposit[] memory depositsProcessed) {
        // Allocate one extra slot for collecting fees on L2
        depositsProcessed = new TaikoData.EthDeposit[](
            config.maxEthDepositsPerBlock + 1
        );

        uint256 j; // number of deposits to process on L2
        if (
            state.ethDeposits.length
                >= state.nextEthDepositToProcess + config.minEthDepositsPerBlock
        ) {
            unchecked {
                // When maxEthDepositsPerBlock is 32, the average gas cost per
                // EthDeposit is about 2700 gas. We use 21000 so the proposer may
                // earn a small profit if there are 32 deposits included
                // in the block; if there are less EthDeposit to process, the
                // proposer may suffer a loss so the proposer should simply wait
                // for more EthDeposit be become available.
                uint96 feePerDeposit =
                    uint96(config.ethDepositMaxFee.min(block.basefee * config.ethDepositGas));
                uint96 totalFee;
                uint64 i = state.nextEthDepositToProcess;
                while (
                    i < state.ethDeposits.length
                        && i < state.nextEthDepositToProcess + config.maxEthDepositsPerBlock
                ) {
                    TaikoData.EthDeposit storage deposit = state.ethDeposits[i];
                    if (deposit.amount > feePerDeposit) {
                        totalFee += feePerDeposit;
                        depositsProcessed[j].recipient = deposit.recipient;
                        depositsProcessed[j].amount = deposit.amount - feePerDeposit;
                        ++j;
                    } else {
                        totalFee += deposit.amount;
                    }

                    // delete the deposit
                    deposit.recipient = address(0);
                    deposit.amount = 0;
                    ++i;
                }

                // Fee collecting deposit
                if (totalFee > 0) {
                    depositsProcessed[j].recipient = beneficiary;
                    depositsProcessed[j].amount = totalFee;
                    ++j;
                }
                // Advance cursor
                state.nextEthDepositToProcess = i;
            }
        }

        assembly {
            mstore(depositsProcessed, j)
        }

        depositsRoot = _hashEthDeposits(depositsProcessed);
    }

    function _hashEthDeposits(TaikoData.EthDeposit[] memory deposits)
        private
        pure
        returns (bytes32)
    {
        bytes memory buffer = new bytes(32 * deposits.length);

        for (uint256 i; i < deposits.length;) {
            uint256 encoded =
                uint256(uint160(deposits[i].recipient)) << 96 | uint256(deposits[i].amount);
            assembly {
                mstore(add(buffer, mul(32, add(1, i))), encoded)
            }
            unchecked {
                ++i;
            }
        }

        return keccak256(buffer);
    }
}
