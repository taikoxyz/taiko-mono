// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {LibAddress} from "../../libs/LibAddress.sol";
import {TaikoData} from "../TaikoData.sol";

library LibEthDepositing {
    using LibAddress for address;
    error L1_INVALID_ETH_DEPOSIT();
    error L1_TOO_MANY_ETH_DEPOSITS();

    event EthDepositRequested(uint64 id, TaikoData.EthDeposit deposit);
    event EthDepositCanceled(uint64 id, TaikoData.EthDeposit deposit);

    function depositEtherToL2(
        TaikoData.State storage state,
        uint48 fee
    ) internal {
        if (msg.value < fee || msg.value - fee > type(uint48).max)
            revert L1_INVALID_ETH_DEPOSIT();

        TaikoData.EthDeposit memory deposit = TaikoData.EthDeposit({
            recipient: msg.sender,
            amount: uint48(msg.value - fee),
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
    ) internal {
        TaikoData.EthDeposit memory deposit = state.ethDeposits[depositId];
        if (deposit.recipient == address(0)) revert L1_INVALID_ETH_DEPOSIT();

        deposit.recipient.sendEther(deposit.amount + deposit.fee);
        delete state.ethDeposits[depositId];

        emit EthDepositCanceled(depositId, deposit);
    }

    function calcDepositsRoot(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64[] memory ethDepositIds,
        address beneficiary
    ) internal returns (bytes32 root) {
        if (ethDepositIds.length == 0) return 0;

        if (ethDepositIds.length >= config.maxEthDepositPerBlock)
            revert L1_TOO_MANY_ETH_DEPOSITS();

        TaikoData.EthDeposit[] memory inputs = new TaikoData.EthDeposit[](
            config.maxEthDepositPerBlock
        );
        uint48 totalFee;
        uint j;

        unchecked {
            for (uint256 i; i < ethDepositIds.length; ++i) {
                uint256 id = ethDepositIds[i];
                TaikoData.EthDeposit storage deposit = state.ethDeposits[id];

                if (deposit.recipient == address(0)) continue;

                // Overflow will be fine
                totalFee += deposit.fee;

                inputs[j].recipient = deposit.recipient;
                inputs[j].amount = deposit.amount;

                ++j;
                delete state.ethDeposits[id];
            }

            inputs[j].recipient = beneficiary;
            inputs[j].amount = totalFee;
        }

        assembly {
            // Note that EthDeposit takes 32 bytes
            root := keccak256(inputs, mul(j, 32))
        }
    }
}
