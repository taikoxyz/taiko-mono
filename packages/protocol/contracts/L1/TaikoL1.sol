// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {LibTokenomics} from "./libs/LibTokenomics.sol";
import {TaikoData, TaikoCallback, TaikoCore, AddressResolver, Proxied} from "./TaikoCore.sol";
import {TaikoToken} from "./TaikoToken.sol";
import {LibMath} from "../libs/LibMath.sol";
import {LibFixedPointMath as Math} from "../thirdparty/LibFixedPointMath.sol";

/// @custom:security-contact hello@taiko.xyz
contract TaikoL1 is TaikoCore, TaikoCallback {
    using LibMath for uint256;

    error L1_INSUFFICIENT_TOKEN();

    mapping(address account => uint256 balance) taikoTokenBalances;
    uint64 public accProposedAt;
    uint64 public accBlockFees;
    uint64 public blockFee;
    uint64 public proofTimeIssued;
    uint64 public proofTimeTarget;

    uint256[47] __gap;

    /**
     * Initialize the rollup.
     *
     * @param _addressManager The AddressManager address.
     * @param _genesisBlockHash The block hash of the genesis block.
     * @param _initBlockFee Initial (reasonable) block fee value.
     * @param _initProofTimeTarget Initial (reasonable) proof submission time target.
     * @param _initProofTimeIssued Initial proof time issued corresponding
     *        with the initial block fee.
     */
    function init(
        address _addressManager,
        bytes32 _genesisBlockHash,
        uint64 _initBlockFee,
        uint64 _initProofTimeTarget,
        uint64 _initProofTimeIssued
    ) external initializer {
        TaikoCore._init(_addressManager, _genesisBlockHash);

        blockFee = _initBlockFee;
        proofTimeTarget = _initProofTimeTarget;
        proofTimeIssued = _initProofTimeIssued;
    }
    /**
     * Change proof parameters (time target and time issued) - to avoid complex/risky upgrades in case need to change relatively frequently.
     * @param newProofTimeTarget New proof time target.
     * @param newProofTimeIssued New proof time issued. If set to type(uint64).max, let it be unchanged.
     */

    function setProofParams(uint64 newProofTimeTarget, uint64 newProofTimeIssued)
        external
        onlyOwner
    {
        if (newProofTimeTarget == 0 || newProofTimeIssued == 0) {
            revert L1_INVALID_PARAM();
        }

        proofTimeTarget = newProofTimeTarget;
        // Special case in a way - that we leave the proofTimeIssued unchanged
        // because we think provers will adjust behavior.
        if (newProofTimeIssued != type(uint64).max) {
            proofTimeIssued = newProofTimeIssued;
        }

        emit ProofTimeTargetChanged(newProofTimeTarget);
    }

    function withdrawTaikoToken(uint256 amount) public {
        uint256 balance = taikoTokenBalances[msg.sender];
        if (balance < amount) revert L1_INSUFFICIENT_TOKEN();

        unchecked {
            taikoTokenBalances[msg.sender] -= amount;
        }

        TaikoToken(AddressResolver(this).resolve("taiko_token", false)).mint(msg.sender, amount);
    }

    function depositTaikoToken(uint256 amount) public {
        if (amount > 0) {
            TaikoToken(AddressResolver(this).resolve("taiko_token", false)).burn(msg.sender, amount);
            taikoTokenBalances[msg.sender] += amount;
        }
    }

    function getTaikoTokenBalance(address addr) public view returns (uint256) {
        return taikoTokenBalances[addr];
    }

    function getProofReward(uint64 proofTime) public view returns (uint64) {
        return _getProofReward(proofTime);
    }

    function afterBlockProposed(address proposer) public override {
        if (taikoTokenBalances[proposer] < blockFee) {
            revert L1_INSUFFICIENT_TOKEN();
        }

        unchecked {
            taikoTokenBalances[msg.sender] -= blockFee;
            accBlockFees += blockFee;
            accProposedAt += uint64(block.timestamp);
        }
    }

    function afterBlockVerified(address prover, uint64 proposedAt, uint64 provenAt)
        public
        override
    {
        uint64 proofTime;
        unchecked {
            proofTime = provenAt - proposedAt;
        }

        uint64 reward = _getProofReward(proofTime);

        (proofTimeIssued, blockFee) = _getNewBlockFeeAndProofTimeIssued(getConfig(), proofTime);

        unchecked {
            accBlockFees -= reward;
            accProposedAt -= proposedAt;
        }

        // reward the prover
        if (reward != 0) {
            address _prover = prover != address(1)
                ? prover //
                : AddressResolver(this).resolve("system_prover", true);

            // systemProver may become address(0) after a block is proven
            if (_prover != address(0)) {
                if (taikoTokenBalances[_prover] == 0) {
                    // Reduce refund to 1 wei as a penalty if the proposer
                    // has 0 TKO outstanding balance.
                    taikoTokenBalances[_prover] = 1;
                } else {
                    taikoTokenBalances[_prover] += reward;
                }
            }
        }
    }

    function getBlockFee() public view returns (uint64) {
        return blockFee;
    }

    function _getProofReward(uint64 proofTime) internal view returns (uint64) {
        uint64 numBlocksUnverified = state.numBlocks - state.lastVerifiedBlockId - 1;

        if (numBlocksUnverified == 0) {
            return 0;
        } else {
            uint64 totalNumProvingSeconds =
                uint64(uint256(numBlocksUnverified) * block.timestamp - accProposedAt);
            // If block timestamp is equal to state.accProposedAt (not really,
            // but theoretically possible) there will be division by 0 error
            if (totalNumProvingSeconds == 0) {
                totalNumProvingSeconds = 1;
            }

            return uint64((uint256(accBlockFees) * proofTime) / totalNumProvingSeconds);
        }
    }

    function _getNewBlockFeeAndProofTimeIssued(TaikoData.Config memory config, uint64 proofTime)
        private
        view
        returns (uint64 newProofTimeIssued, uint64 _blockFee)
    {
        newProofTimeIssued =
            (proofTimeIssued > proofTimeTarget) ? proofTimeIssued - proofTimeTarget : uint64(0);
        newProofTimeIssued += proofTime;

        uint256 x = (newProofTimeIssued * Math.SCALING_FACTOR_1E18)
            / (proofTimeTarget * config.adjustmentQuotient);

        if (Math.MAX_EXP_INPUT <= x) {
            x = Math.MAX_EXP_INPUT;
        }

        uint256 result = (uint256(Math.exp(int256(x))) / Math.SCALING_FACTOR_1E18)
            / (proofTimeTarget * config.adjustmentQuotient);

        _blockFee = uint64(result.min(type(uint64).max));
    }
}

contract ProxiedTaikoL1 is Proxied, TaikoL1 {}
