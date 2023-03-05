// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {LibMath} from "../../libs/LibMath.sol";
import {LibTokenomics} from "./LibTokenomics.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {Snippet} from "../../common/IXchainSync.sol";
import {TaikoData} from "../TaikoData.sol";

library LibUtils {
    using LibMath for uint256;

    bytes32 public constant BLOCK_DEADEND_HASH = bytes32(uint256(1));

    error L1_BLOCK_NUMBER();

    struct StateVariables {
        uint256 feeBase;
        uint64 genesisHeight;
        uint64 genesisTimestamp;
        uint64 nextBlockId;
        uint64 lastProposedAt;
        uint64 avgBlockTime;
        uint64 latestVerifiedHeight;
        uint64 latestVerifiedId;
        uint64 avgProofTime;
    }

    function getProposedBlock(
        TaikoData.State storage state,
        uint256 maxNumBlocks,
        uint256 id
    ) internal view returns (TaikoData.ProposedBlock storage) {
        return state.proposedBlocks[id % maxNumBlocks];
    }

    function getL2Snippet(
        TaikoData.State storage state,
        uint256 number,
        uint256 blockHashHistory
    ) internal view returns (Snippet storage) {
        uint256 _number = number;
        if (_number == 0) {
            _number = state.latestVerifiedHeight;
        } else if (
            _number + blockHashHistory <= state.latestVerifiedHeight ||
            _number > state.latestVerifiedHeight
        ) revert L1_BLOCK_NUMBER();

        return state.l2Snippets[_number % blockHashHistory];
    }

    function getStateVariables(
        TaikoData.State storage state
    ) internal view returns (StateVariables memory) {
        return
            StateVariables({
                feeBase: LibTokenomics.szaboToWei(state.feeBaseSzabo),
                genesisHeight: state.genesisHeight,
                genesisTimestamp: state.genesisTimestamp,
                nextBlockId: state.nextBlockId,
                lastProposedAt: state.lastProposedAt,
                avgBlockTime: state.avgBlockTime,
                latestVerifiedHeight: state.latestVerifiedHeight,
                latestVerifiedId: state.latestVerifiedId,
                avgProofTime: state.avgProofTime
            });
    }

    function hashMetadata(
        TaikoData.BlockMetadata memory meta
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(meta));
    }

    function hashTxList(bytes memory txList) internal pure returns (bytes32) {
        return keccak256(txList);
    }

    function movingAverage(
        uint256 maValue,
        uint256 newValue,
        uint256 maf
    ) internal pure returns (uint256) {
        if (maValue == 0) {
            return newValue;
        }
        uint256 _ma = (maValue * (maf - 1) + newValue) / maf;
        return _ma > 0 ? _ma : maValue;
    }
}
