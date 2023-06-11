// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import { TaikoData } from "./TaikoData.sol";

abstract contract TaikoEvents {
    // The following events must match the definitions in corresponding L1
    // libraries.
    event BatchBid(uint64 indexed batchId, uint64 startedAt, TaikoData.Bid bid);

    event BlockProposed(
        uint256 indexed id, TaikoData.BlockMetadata meta, uint64 blockFee
    );

    event BlockProven(
        uint256 indexed id,
        bytes32 parentHash,
        bytes32 blockHash,
        bytes32 signalRoot,
        address prover,
        uint32 parentGasUsed
    );

    event BlockVerified(uint256 indexed id, bytes32 blockHash, uint64 reward);

    event EthDeposited(TaikoData.EthDeposit deposit);

    event ProofParamsChanged(
        uint64 proofTimeTarget,
        uint64 proofTimeIssued,
        uint64 blockFee,
        uint16 adjustmentQuotient
    );
}
