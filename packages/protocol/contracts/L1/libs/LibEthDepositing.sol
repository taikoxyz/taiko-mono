// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {LibAddress} from "../../libs/LibAddress.sol";
import {AddressResolver} from "../../common/AddressResolver.sol";
import {TaikoData} from "../TaikoData.sol";

library LibEthDepositing {
    using LibAddress for address;

    error L1_INVALID_ETH_DEPOSIT();
    error L1_TOO_MANY_ETH_DEPOSITS();

    event EthDepositRequested(uint64 id, TaikoData.EthDeposit deposit);
    event EthDepositCanceled(uint64 id, TaikoData.EthDeposit deposit);

    function depositEtherToL2(
        TaikoData.State storage state,
        uint128 fee
    ) public {
        if (msg.value < fee || msg.value - fee > type(uint128).max)
            revert L1_INVALID_ETH_DEPOSIT();

        TaikoData.EthDeposit memory deposit = TaikoData.EthDeposit({
            recipient: msg.sender,
            amount: uint128(msg.value - fee),
            fee: fee
        });

        state.ethDeposits[state.nextEthDepositId] = deposit;
        emit EthDepositRequested(state.nextEthDepositId, deposit);

        unchecked {
            ++state.nextEthDepositId;
        }
    }

    function cancelEtherDepositToL2(
        TaikoData.State storage state,
        uint64 depositId
    ) public {
        TaikoData.EthDeposit memory deposit = state.ethDeposits[depositId];
        if (deposit.recipient == address(0)) revert L1_INVALID_ETH_DEPOSIT();

        deposit.recipient.sendEther(deposit.amount + deposit.fee);
        delete state.ethDeposits[depositId];

        emit EthDepositCanceled(depositId, deposit);
    }

    function calcDepositsRoot(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint64[] memory ethDepositIds,
        address beneficiary
    )
        internal
        returns (bytes32 root, TaikoData.EthDeposit[] memory depositsProcessed)
    {
        if (ethDepositIds.length == 0)
            return (0, new TaikoData.EthDeposit[](0));

        if (ethDepositIds.length >= config.maxEthDepositPerBlock)
            revert L1_TOO_MANY_ETH_DEPOSITS();

        depositsProcessed = new TaikoData.EthDeposit[](ethDepositIds.length);
        uint128 totalFee;
        uint256 totalEther;
        uint j;

        unchecked {
            for (uint256 i; i < ethDepositIds.length; ++i) {
                uint256 id = ethDepositIds[i];
                TaikoData.EthDeposit storage deposit = state.ethDeposits[id];

                if (deposit.recipient == address(0)) continue;

                // Overflow will be fine
                totalFee += deposit.fee;
                totalEther += deposit.fee + deposit.amount;

                depositsProcessed[j].recipient = deposit.recipient;
                depositsProcessed[j].amount = deposit.amount;

                ++j;
                delete state.ethDeposits[id];
            }

            depositsProcessed[j].recipient = beneficiary;
            depositsProcessed[j].amount = totalFee;
        }

        assembly {
            // Change the length of depositsProcessed
            sstore(depositsProcessed, j)
            // Note that EthDeposit takes 64 bytes
            root := keccak256(depositsProcessed, mul(j, 64))
        }

        if (totalEther > 0) {
            address to = resolver.resolve("ether_vault", true);
            if (to == address(0)) {
                to = resolver.resolve("bridge", false);
            }
            to.sendEther(totalEther);
        }
    }
}
