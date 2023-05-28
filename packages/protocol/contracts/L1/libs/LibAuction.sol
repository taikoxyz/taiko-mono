// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {LibUtils} from "./LibUtils.sol";
import {TaikoData} from "../../L1/TaikoData.sol";
import {LibAddress} from "../../libs/LibAddress.sol";
import {AddressResolver} from "../../common/AddressResolver.sol";

library LibAuction {
    using LibAddress for address;

    event Bid(
        uint256 indexed id,
        address claimer,
        uint256 claimedAt,
        uint256 deposit,
        uint256 minFeePerGasInWei
    );

    function bidForBatch(
        TaikoData.State storage state,
        AddressResolver resolver,
        TaikoData.Config memory config,
        uint256 batchStartBlockId,
        uint256 minFeePerGasInWei
    ) internal {
    }
}
