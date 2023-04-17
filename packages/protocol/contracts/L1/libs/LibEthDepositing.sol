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

    // When maxEthDepositPerBlock is 32, the average gas cost per
    // EthDeposit is about 2700 gas. We use 20000 so the proposer may
    // earn a small profit if there are 32 deposits included
    // in the block; if there are less EthDeposit to process, the
    // proposer may suffer a loss so the proposer should simply wait
    // for more EthDeposit be become available.
    uint256 public constant GAS_PER_ETH_DEPOSIT = 20000;

    error L1_INVALID_ETH_DEPOSIT();
    error L1_TOO_MANY_ETH_DEPOSITS();

    event EthDepositRequested(uint64 id, TaikoData.EthDeposit deposit);
    event EthDepositCanceled(uint64 id, TaikoData.EthDeposit deposit);

    /// @dev Each EthDeposit can carry  18,446.74 Ether. It will take forever
    // for someone to overflow Ether balance on L2 if we limit the number of
    // EthDeposits per L2 block.
    function depositEtherToL2(
        TaikoData.State storage state,
        address recipient
    ) public returns (uint64 depositId) {
        if (msg.value == 0 || msg.value > type(uint96).max)
            revert L1_INVALID_ETH_DEPOSIT();

        TaikoData.EthDeposit memory deposit = TaikoData.EthDeposit({
            recipient: recipient == address(0) ? msg.sender : recipient,
            amount: uint96(msg.value)
        });

        depositId = state.nextEthDepositId;
        state.ethDeposits[depositId] = deposit;
        emit EthDepositRequested(depositId, deposit);

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

        deposit.recipient.sendEther(deposit.amount);
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
        returns (
            bytes32 depositsRoot,
            TaikoData.EthDeposit[] memory depositsProcessed
        )
    {
        if (ethDepositIds.length == 0)
            return (0, new TaikoData.EthDeposit[](0));

        if (ethDepositIds.length >= config.maxEthDepositPerBlock)
            revert L1_TOO_MANY_ETH_DEPOSITS();

        depositsProcessed = new TaikoData.EthDeposit[](
            ethDepositIds.length + 1
        );
        uint96 feePerDeposit = (tx.gasprice * GAS_PER_ETH_DEPOSIT).toUint96();
        uint256 totalEth;
        uint j;

        unchecked {
            for (uint256 i; i < ethDepositIds.length; ++i) {
                uint256 id = ethDepositIds[i];
                TaikoData.EthDeposit storage deposit = state.ethDeposits[id];

                if (
                    deposit.recipient == address(0) ||
                    deposit.amount < feePerDeposit
                ) continue;

                depositsProcessed[j].recipient = deposit.recipient;
                depositsProcessed[j].amount = deposit.amount - feePerDeposit;
                totalEth += deposit.amount;
                ++j;

                // delete this record
                delete state.ethDeposits[id];
            }

            depositsProcessed[j].recipient = beneficiary;
            depositsProcessed[j].amount = (feePerDeposit * j).toUint96();
        }

        assembly {
            // Change the length of depositsProcessed
            sstore(depositsProcessed, j)
            // Note that EthDeposit takes 1 slot each
            depositsRoot := keccak256(depositsProcessed, mul(j, 32))
        }

        if (totalEth > 0) {
            address to = resolver.resolve("ether_vault", true);
            if (to == address(0)) {
                to = resolver.resolve("bridge", false);
            }
            to.sendEther(totalEth);
        }
    }
}
