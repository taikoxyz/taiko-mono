// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {IProofVerifier} from "../../L1/ProofVerifier.sol";
import {TaikoL1} from "../../L1/TaikoL1.sol";
import {TaikoData} from "../../L1/TaikoData.sol";

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
        config.maxVerificationsPerTx = 0;
        config.commitConfirmations = 1;
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
        config.bootstrapDiscountHalvingPeriod = 1 seconds;
        config.enableTokenomics = false;
        config.enablePublicInputsCheck = false;
        config.claimAuctionWindowInSeconds = 15 seconds;
        config.baseClaimHoldTimeInSeconds = 30 minutes;
        config.baseClaimDepositInWei = 0.000000001 ether;
        config.minimumClaimBidIncreaseInWei = 1 wei;
        config.claimAuctionDelayInSeconds = 5 seconds;
    }

    function verifyZKP(
        string memory /*verifierId*/,
        bytes calldata /*zkproof*/,
        bytes32 /*instance*/
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
