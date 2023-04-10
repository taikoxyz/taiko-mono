// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibAddress} from "../../libs/LibAddress.sol";
import {LibTokenomics} from "./LibTokenomics.sol";
import {LibUtils} from "./LibUtils.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../TaikoData.sol";

library LibEthDepositing {
    error L1_INVALID_ETH_DEPOSIT();

    event EthDeposited(TaikoData.EthDeposit deposit);

    // TODO(daniel): how to prevent spam?
    function depositEtherToL2(
        TaikoData.State storage state,
        address recipient
    ) internal {
        if (
            recipient == address(0) ||
            msg.value == 0 ||
            msg.value > type(uint64).max
        ) revert L1_INVALID_ETH_DEPOSIT();

        TaikoData.EthDeposit memory deposit = TaikoData.EthDeposit({
            id: state.nextEthDepositId,
            recipient: recipient == address(0) ? msg.sender : recipient,
            amount: uint64(msg.value)
        });

        state.ethDeposits[state.nextEthDepositId] = deposit;
        unchecked {
            ++state.nextEthDepositId;
        }
        emit EthDeposited(deposit);
    }
}
