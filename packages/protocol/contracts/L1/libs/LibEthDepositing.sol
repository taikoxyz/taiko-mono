// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {LibAddress} from "../../libs/LibAddress.sol";
import {AddressResolver} from "../../common/AddressResolver.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../TaikoData.sol";

library LibEthDepositing {
    using LibAddress for address;
    using SafeCastUpgradeable for uint256;

    uint256 public constant GWEI_TO_WEI = 1000000000;

    error L1_INVALID_ETH_DEPOSIT();
    error L1_TOO_MANY_ETH_DEPOSITS();

    event EthDepositRequested(uint64 id, TaikoData.EthDeposit deposit);
    event EthDepositCanceled(uint64 id, TaikoData.EthDeposit deposit);

    /// @dev Each EthDeposit can carry  18,446.74 Ether. It will take forever
    // for someone to overflow Ether balance on L2 if we limit the number of
    // EthDeposits per L2 block.
    function depositEtherToL2(
        TaikoData.State storage state,
        uint256 fee
    ) public {
        uint256 feeGwei = fee / GWEI_TO_WEI;

        TaikoData.EthDeposit memory deposit = TaikoData.EthDeposit({
            recipient: msg.sender,
            amountGwei: ((msg.value - GWEI_TO_WEI * feeGwei) / GWEI_TO_WEI)
                .toUint48(),
            feeGwei: feeGwei.toUint48()
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

        uint256 amount = GWEI_TO_WEI *
            (uint256(deposit.amountGwei) + deposit.feeGwei);
        deposit.recipient.sendEther(amount);
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
        uint48 totalFeeGwei;
        uint256 totalEtherGwei;
        uint j;

        unchecked {
            for (uint256 i; i < ethDepositIds.length; ++i) {
                uint256 id = ethDepositIds[i];
                TaikoData.EthDeposit storage deposit = state.ethDeposits[id];

                if (deposit.recipient == address(0)) continue;

                depositsProcessed[j].recipient = deposit.recipient;
                depositsProcessed[j].amountGwei = deposit.amountGwei;

                // sum up
                totalFeeGwei += deposit.feeGwei; // may overflow then throw
                totalEtherGwei += uint256(deposit.amountGwei) + deposit.feeGwei;

                // delete this record
                state.ethDeposits[id].recipient = address(0);
                state.ethDeposits[id].amountGwei = 0;
                state.ethDeposits[id].feeGwei = 0;
                ++j;
            }

            depositsProcessed[j].recipient = beneficiary;
            depositsProcessed[j].amountGwei = totalFeeGwei;
        }

        assembly {
            // Change the length of depositsProcessed
            sstore(depositsProcessed, j)
            // Note that EthDeposit takes 64 bytes
            root := keccak256(depositsProcessed, mul(j, 64))
        }

        if (totalEtherGwei > 0) {
            address to = resolver.resolve("ether_vault", true);
            if (to == address(0)) {
                to = resolver.resolve("bridge", false);
            }
            to.sendEther(GWEI_TO_WEI * totalEtherGwei);
        }
    }
}
