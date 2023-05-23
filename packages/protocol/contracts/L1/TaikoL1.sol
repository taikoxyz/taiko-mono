// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {LibTokenomics} from "./libs/LibTokenomics.sol";
import {TaikoData, TaikoCallback, TaikoCore, AddressResolver, Proxied} from "./TaikoCore.sol";

/// @custom:security-contact hello@taiko.xyz
contract TaikoL1 is TaikoCore, TaikoCallback {
    function depositTaikoToken(uint256 amount) external nonReentrant {
        LibTokenomics.depositTaikoToken(state, AddressResolver(this), amount);
    }

    function withdrawTaikoToken(uint256 amount) external nonReentrant {
        LibTokenomics.withdrawTaikoToken(state, AddressResolver(this), amount);
    }

    function getTaikoTokenBalance(address addr) public view returns (uint256) {
        return state.taikoTokenBalances[addr];
    }

    function getProofReward(uint64 proofTime) public view returns (uint64) {
        return LibTokenomics.getProofReward(state, proofTime);
    }

    function afterBlockProposed(address proposer, TaikoData.BlockMetadata memory meta)
        public
        override
    {
        if (state.taikoTokenBalances[proposer] < state.blockFee) {
            revert L1_INSUFFICIENT_TOKEN();
        }

        unchecked {
            state.taikoTokenBalances[proposer] -= state.blockFee;
            state.accBlockFees += state.blockFee;
            state.accProposedAt += meta.timestamp;
        }
    }

    function afterBlockVerified(address prover, uint64 proposedAt, uint64 provenAt)
        public
        override
    {
        uint64 proofTime = provenAt - proposedAt;
        uint64 reward = LibTokenomics.getProofReward(state, proofTime);

        (state.proofTimeIssued, state.blockFee) =
            LibTokenomics.getNewBlockFeeAndProofTimeIssued(state, getConfig(), proofTime);

        unchecked {
            state.accBlockFees -= reward;
            state.accProposedAt -= proposedAt;
        }

        // reward the prover
        if (reward != 0) {
            address systemProver = AddressResolver(this).resolve("system_prover", true);
            address _prover = prover != address(1) ? prover : systemProver;

            // systemProver may become address(0) after a block is proven
            if (_prover != address(0)) {
                if (state.taikoTokenBalances[_prover] == 0) {
                    // Reduce refund to 1 wei as a penalty if the proposer
                    // has 0 TKO outstanding balance.
                    state.taikoTokenBalances[_prover] = 1;
                } else {
                    state.taikoTokenBalances[_prover] += reward;
                }
            }
        }
    }
}

contract ProxiedTaikoL1 is Proxied, TaikoL1 {}
