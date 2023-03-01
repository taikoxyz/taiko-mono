// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {EssentialContract} from "../common/EssentialContract.sol";
import {IHeaderSync} from "../common/IHeaderSync.sol";
import {LibAnchorSignature} from "../libs/LibAnchorSignature.sol";
import {LibSharedConfig} from "../libs/LibSharedConfig.sol";
import {TaikoData} from "./TaikoData.sol";
import {TaikoEvents} from "./TaikoEvents.sol";
import {TaikoCustomErrors} from "./TaikoCustomErrors.sol";
import {LibProposing} from "./libs/LibProposing.sol";
import {LibProving} from "./libs/LibProving.sol";
import {LibUtils} from "./libs/LibUtils.sol";
import {LibVerifying} from "./libs/LibVerifying.sol";
import {AddressResolver} from "../common/AddressResolver.sol";
import {LibClaiming} from "./libs/LibClaiming.sol";

contract TaikoL1 is
    EssentialContract,
    IHeaderSync,
    TaikoEvents,
    TaikoCustomErrors
{
    using LibUtils for TaikoData.State;

    TaikoData.State public state;
    uint256[100] private __gap;

    modifier onlyFromEOA() {
        // solhint-disable-next-line avoid-tx-origin
        if (msg.sender != tx.origin) revert L1_CONTRACT_NOT_ALLOWED();
        _;
    }

    function init(
        address _addressManager,
        bytes32 _genesisBlockHash,
        uint256 _feeBase
    ) external initializer {
        EssentialContract._init(_addressManager);
        LibVerifying.init({
            state: state,
            genesisBlockHash: _genesisBlockHash,
            feeBase: _feeBase
        });
    }

    /**
     * Write a _commit hash_ so a few blocks later a L2 block can be proposed
     * such that `calculateCommitHash(meta.beneficiary, meta.txListHash)` equals
     * to this commit hash.
     *
     * @param commitSlot A slot to save this commit. Slot 0 will always be reset
     *                   to zero for refund.
     * @param commitHash Calculated with:
     *                  `calculateCommitHash(beneficiary, txListHash)`.
     */
    function commitBlock(uint64 commitSlot, bytes32 commitHash) external {
        LibProposing.commitBlock({
            state: state,
            config: getConfig(),
            commitSlot: commitSlot,
            commitHash: commitHash
        });
    }

    /**
     * Propose a Taiko L2 block.
     *
     * @param inputs A list of data input:
     *        - inputs[0] is abi-encoded BlockMetadata that the actual L2 block
     *          header must satisfy.
     *          Note the following fields in the provided meta object must
     *          be zeros -- their actual values will be provisioned by Ethereum.
     *            - id
     *            - l1Height
     *            - l1Hash
     *            - mixHash
     *            - timestamp
     *        - inputs[1] is a list of transactions in this block, encoded with
     *          RLP. Note, in the corresponding L2 block an _anchor transaction_
     *          will be the first transaction in the block -- if there are
     *          n transactions in `txList`, then there will be up to n+1
     *          transactions in the L2 block.
     */
    function proposeBlock(
        bytes[] calldata inputs
    ) external onlyFromEOA nonReentrant {
        TaikoData.Config memory config = getConfig();
        LibProposing.proposeBlock({
            state: state,
            config: config,
            resolver: AddressResolver(this),
            inputs: inputs
        });
        LibVerifying.verifyBlocks({
            state: state,
            config: config,
            maxBlocks: config.maxVerificationsPerTx
        });
    }

    function claimBlock(uint256 blockId) external payable nonReentrant {
        LibClaiming.claimBlock({
            state: state,
            config: getConfig(),
            blockId: blockId
        });
    }

    /**
     * Prove a block is valid with a zero-knowledge proof, a transaction
     * merkel proof, and a receipt merkel proof.
     *
     * @param blockId The index of the block to prove. This is also used
     *        to select the right implementation version.
     * @param inputs A list of data input:
     *        - inputs[0] is an abi-encoded object with various information
     *          regarding  the block to be proven and the actual proofs.
     *        - inputs[1] is the actual anchor transaction in this L2 block.
     *          Note that the anchor transaction is always the first transaction
     *          in the block.
     *        - inputs[2] is the receipt of the anchor transaction.
     */

    function proveBlock(
        uint256 blockId,
        bytes[] calldata inputs
    ) external onlyFromEOA nonReentrant {
        TaikoData.Config memory config = getConfig();
        LibProving.proveBlock({
            state: state,
            config: config,
            resolver: AddressResolver(this),
            blockId: blockId,
            inputs: inputs
        });
        LibVerifying.verifyBlocks({
            state: state,
            config: config,
            maxBlocks: config.maxVerificationsPerTx
        });
    }

    /**
     * Prove a block is invalid with a zero-knowledge proof and a receipt
     * merkel proof.
     *
     * @param blockId The index of the block to prove. This is also used to
     *        select the right implementation version.
     * @param inputs A list of data input:
     *        - inputs[0] An Evidence object with various information regarding
     *          the block to be proven and the actual proofs.
     *        - inputs[1] The target block to be proven invalid.
     *        - inputs[2] The receipt for the `invalidBlock` transaction
     *          on L2. Note that the `invalidBlock` transaction is supposed to
     *          be the only transaction in the L2 block.
     */
    function proveBlockInvalid(
        uint256 blockId,
        bytes[] calldata inputs
    ) external onlyFromEOA nonReentrant {
        TaikoData.Config memory config = getConfig();

        LibProving.proveBlockInvalid({
            state: state,
            config: config,
            resolver: AddressResolver(this),
            blockId: blockId,
            inputs: inputs
        });
        LibVerifying.verifyBlocks({
            state: state,
            config: config,
            maxBlocks: config.maxVerificationsPerTx
        });
    }

    /**
     * Verify up to N blocks.
     * @param maxBlocks Max number of blocks to verify.
     */
    function verifyBlocks(uint256 maxBlocks) external onlyFromEOA nonReentrant {
        if (maxBlocks == 0) revert L1_INVALID_PARAM();
        LibVerifying.verifyBlocks({
            state: state,
            config: getConfig(),
            maxBlocks: maxBlocks
        });
    }

    function withdrawBalance() external nonReentrant {
        LibVerifying.withdrawBalance(state, AddressResolver(this));
    }

    function getRewardBalance(address addr) public view returns (uint256) {
        return state.balances[addr];
    }

    function getBlockFee() public view returns (uint256) {
        (, uint256 fee, uint256 deposit) = LibProposing.getBlockFee(
            state,
            getConfig()
        );
        return fee + deposit;
    }

    function getProofReward(
        uint64 provenAt,
        uint64 proposedAt,
        uint256 blockId
    ) public view returns (uint256 eth, uint256 token) {
        (, token, ) = LibVerifying.getProofReward({
            state: state,
            config: getConfig(),
            provenAt: provenAt,
            proposedAt: proposedAt
        });

        if (
            state.claims[blockId].claimer != address(0) &&
            isClaimForProposedBlockStillValid(blockId)
        ) {
            eth = state.claims[blockId].deposit;
        }
    }

    function isCommitValid(
        uint256 commitSlot,
        uint256 commitHeight,
        bytes32 commitHash
    ) public view returns (bool) {
        return
            LibProposing.isCommitValid(
                state,
                getConfig().commitConfirmations,
                commitSlot,
                commitHeight,
                commitHash
            );
    }

    function getProposedBlock(
        uint256 id
    ) public view returns (TaikoData.ProposedBlock memory) {
        return
            LibProposing.getProposedBlock(state, getConfig().maxNumBlocks, id);
    }

    function getSyncedHeader(
        uint256 number
    ) public view override returns (bytes32) {
        return state.getL2BlockHash(number, getConfig().blockHashHistory);
    }

    function getLatestSyncedHeader() public view override returns (bytes32) {
        return
            state.getL2BlockHash(
                state.latestVerifiedHeight,
                getConfig().blockHashHistory
            );
    }

    function getStateVariables()
        public
        view
        returns (LibUtils.StateVariables memory)
    {
        return state.getStateVariables();
    }

    function signWithGoldenTouch(
        bytes32 hash,
        uint8 k
    ) public view returns (uint8 v, uint256 r, uint256 s) {
        return LibAnchorSignature.signTransaction(hash, k);
    }

    function getForkChoice(
        uint256 id,
        bytes32 parentHash
    ) public view returns (TaikoData.ForkChoice memory) {
        return state.forkChoices[id][parentHash];
    }

    function getConfig() public pure virtual returns (TaikoData.Config memory) {
        return LibSharedConfig.getConfig();
    }

    function claimForProposedBlock(
        uint256 blockId
    ) public view returns (TaikoData.Claim memory claim) {
        return state.claims[blockId];
    }

    // TODO: remove this and the isClaimedBlockProvable for a
    // ClaimedBlockStatus enum instead, determining whether
    // a claimed block is Unclaimed, in the ClaimingWindow,
    // Claimed and waiting for proof, or Claimed but claim is no longer valid
    // and anyone can prove
    function isClaimForProposedBlockStillValid(
        uint256 blockId
    ) public view returns (bool) {
        if (state.claims[blockId].claimer == address(0)) return false;
        return
            block.timestamp - state.claims[blockId].claimedAt <
            getConfig().baseClaimHoldTimeInSeconds;
    }

    function isClaimedBlockProvable(
        uint256 blockId
    ) public view returns (bool) {
        if (state.claims[blockId].claimer == address(0)) return false;
        if (
            block.timestamp -
                state
                    .proposedBlocks[blockId % getConfig().maxNumBlocks]
                    .proposedAt >
            getConfig().claimAuctionWindowInSeconds
        ) {
            return true;
        }

        return false;
    }
}
