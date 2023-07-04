// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

//_A4 does not change in terms of BlockMetadata or EthDeposit
// structs so safe to use the _A3 version
import {TaikoData_A3} from "./A3/TaikoData_A3.sol";

abstract contract TaikoEvents {
    // The following events must match the definitions in corresponding L1 libraries.
    event BlockProposed(uint256 indexed id, TaikoData_A3.BlockMetadata meta, uint64 blockFee);

    event BlockProven(
        uint256 indexed id,
        bytes32 parentHash,
        bytes32 blockHash,
        bytes32 signalRoot,
        address prover,
        uint32 parentGasUsed
    );

    event BlockVerified(uint256 indexed id, bytes32 blockHash, uint64 reward);

    event EthDeposited(TaikoData_A3.EthDeposit deposit);

    event ProofParamsChanged(
        uint64 proofTimeTarget, uint64 proofTimeIssued, uint64 blockFee, uint16 adjustmentQuotient
    );
}
