// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import {IProofVerifier} from "../../L1/ProofVerifier.sol";
import "../../L1/TaikoL1.sol";

contract TestTaikoL1 is TaikoL1, IProofVerifier {
    function getConfig()
        public
        pure
        override
        returns (TaikoData.Config memory config)
    {
        config.chainId = 167;
        // up to 2048 pending blocks
        config.maxNumBlocks = 4;
        config.blockHashHistory = 3;
        // This number is calculated from maxNumBlocks to make
        // the 'the maximum value of the multiplier' close to 20.0
        config.zkProofsPerBlock = 1;
        config.maxVerificationsPerTx = 0;
        config.commitConfirmations = 1;
        config.maxProofsPerForkChoice = 5;
        config.blockMaxGasLimit = 30000000; // TODO
        config.maxTransactionsPerBlock = 20; // TODO
        config.maxBytesPerTxList = 10240; // TODO
        config.minTxGasLimit = 21000; // TODO
        config.anchorTxGasLimit = 250000;
        config.slotSmoothingFactor = 590000;
        config.rewardBurnBips = 100; // 100 basis points or 1%
        config.proposerDepositPctg = 25; // 25%

        // Moving average factors
        config.feeBaseMAF = 1024;
        config.blockTimeMAF = 64;
        config.proofTimeMAF = 64;

        config.rewardMultiplierPctg = 400; // 400%
        config.feeGracePeriodPctg = 125; // 125%
        config.feeMaxPeriodPctg = 375; // 375%
        config.blockTimeCap = 48 seconds;
        config.proofTimeCap = 4 seconds;
        config.bootstrapDiscountHalvingPeriod = 180 days;
        config.initialUncleDelay = 1 seconds;
        config.enableTokenomics = false;
        config.enablePublicInputsCheck = false;
        config.enableOracleProver = false;
    }

    function verifyZKP(
        string memory /*verifierId*/,
        bytes calldata /*zkproof*/,
        bytes32 /*blockHash*/,
        address /*prover*/,
        bytes32 /*txListHash*/
    ) public pure override returns (bool) {
        return true;
    }

    function verifyMKP(
        bytes memory /*key*/,
        bytes memory /*value*/,
        bytes memory /*proof*/,
        bytes32 /*root*/
    ) public pure override returns (bool) {
        return true;
    }
}
