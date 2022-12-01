// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../common/EssentialContract.sol";
import "../common/IHeaderSync.sol";
import "../libs/LibAnchorSignature.sol";
import "./LibData.sol";
import "./v1/V1Events.sol";
import "./v1/V1Proposing.sol";
import "./v1/V1Proving.sol";
import "./v1/V1Utils.sol";
import "./v1/V1Verifying.sol";

/**
 * @author dantaik <dan@taiko.xyz>
 */
contract TaikoL1 is EssentialContract, IHeaderSync, V1Events {
    using LibData for LibData.State;

    LibData.State public state;
    LibData.TentativeState public tentative;
    uint256[50] private __gap;

    function init(
        address _addressManager,
        bytes32 _genesisBlockHash,
        uint256 _feeBase
    ) external initializer {
        EssentialContract._init(_addressManager);
        V1Verifying.init({
            state: state,
            genesisBlockHash: _genesisBlockHash,
            feeBase: _feeBase
        });

        tentative.whitelistProposers = false;
        tentative.whitelistProvers = true;
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
        V1Proposing.commitBlock(state, commitSlot, commitHash);
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
    function proposeBlock(bytes[] calldata inputs) external nonReentrant {
        V1Proposing.proposeBlock({
            state: state,
            tentative: tentative,
            resolver: AddressResolver(this),
            inputs: inputs
        });
        V1Verifying.verifyBlocks({
            state: state,
            resolver: AddressResolver(this),
            maxBlocks: LibConstants.K_MAX_VERIFICATIONS_PER_TX,
            checkHalt: false
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
    ) external nonReentrant {
        V1Proving.proveBlock({
            state: state,
            tentative: tentative,
            resolver: AddressResolver(this),
            blockId: blockId,
            inputs: inputs
        });
        V1Verifying.verifyBlocks({
            state: state,
            resolver: AddressResolver(this),
            maxBlocks: LibConstants.K_MAX_VERIFICATIONS_PER_TX,
            checkHalt: false
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
    ) external nonReentrant {
        V1Proving.proveBlockInvalid({
            state: state,
            tentative: tentative,
            resolver: AddressResolver(this),
            blockId: blockId,
            inputs: inputs
        });
        V1Verifying.verifyBlocks({
            state: state,
            resolver: AddressResolver(this),
            maxBlocks: LibConstants.K_MAX_VERIFICATIONS_PER_TX,
            checkHalt: false
        });
    }

    /**
     * Verify up to N blocks.
     * @param maxBlocks Max number of blocks to verify.
     */
    function verifyBlocks(uint256 maxBlocks) external nonReentrant {
        require(maxBlocks > 0, "L1:maxBlocks");
        V1Verifying.verifyBlocks({
            state: state,
            resolver: AddressResolver(this),
            maxBlocks: maxBlocks,
            checkHalt: true
        });
    }

    /**
     * Enable or disable proposer and prover whitelisting
     * @param whitelistProposers True to enable proposer whitelisting.
     * @param whitelistProvers True to enable prover whitelisting.
     */
    function enableWhitelisting(
        bool whitelistProposers,
        bool whitelistProvers
    ) public onlyOwner {
        V1Utils.enableWhitelisting({
            tentative: tentative,
            whitelistProposers: whitelistProposers,
            whitelistProvers: whitelistProvers
        });
    }

    /**
     *  Add or remove a proposer from the whitelist.
     *
     * @param proposer The proposer to be added or removed.
     * @param whitelisted True to add; remove otherwise.
     */
    function whitelistProposer(
        address proposer,
        bool whitelisted
    ) public onlyOwner {
        V1Utils.whitelistProposer({
            tentative: tentative,
            proposer: proposer,
            whitelisted: whitelisted
        });
    }

    /**
     *  Add or remove a prover from the whitelist.
     *
     * @param prover The prover to be added or removed.
     * @param whitelisted True to add; remove otherwise.
     */
    function whitelistProver(
        address prover,
        bool whitelisted
    ) public onlyOwner {
        V1Utils.whitelistProver({
            tentative: tentative,
            prover: prover,
            whitelisted: whitelisted
        });
    }

    /**
     * Halt or resume the chain.
     * @param toHalt True to halt, false to resume.
     */
    function halt(bool toHalt) public onlyOwner {
        V1Utils.halt(state, toHalt);
    }

    /**
     * Check whether a proposer is whitelisted.
     *
     * @param proposer The proposer.
     * @return True if the proposer is whitelisted, false otherwise.
     */
    function isProposerWhitelisted(
        address proposer
    ) public view returns (bool) {
        return V1Utils.isProposerWhitelisted(tentative, proposer);
    }

    /**
     * Check whether a prover is whitelisted.
     *
     * @param prover The prover.
     * @return True if the prover is whitelisted, false otherwise.
     */
    function isProverWhitelisted(address prover) public view returns (bool) {
        return V1Utils.isProverWhitelisted(tentative, prover);
    }

    function getBlockFee() public view returns (uint256) {
        (, uint fee, uint deposit) = V1Proposing.getBlockFee(state);
        return fee + deposit;
    }

    function getProofReward(
        uint64 provenAt,
        uint64 proposedAt
    ) public view returns (uint256 reward) {
        (, reward, ) = V1Verifying.getProofReward({
            state: state,
            provenAt: provenAt,
            proposedAt: proposedAt
        });
    }

    /**
     * Check if the L1 is halted.
     * @return True if halted, false otherwise.
     */
    function isHalted() public view returns (bool) {
        return V1Utils.isHalted(state);
    }

    function isCommitValid(
        uint256 commitSlot,
        uint256 commitHeight,
        bytes32 commitHash
    ) public view returns (bool) {
        return
            V1Proposing.isCommitValid(
                state,
                commitSlot,
                commitHeight,
                commitHash
            );
    }

    function getProposedBlock(
        uint256 id
    ) public view returns (LibData.ProposedBlock memory) {
        return state.getProposedBlock(id);
    }

    function getSyncedHeader(
        uint256 number
    ) public view override returns (bytes32) {
        return state.getL2BlockHash(number);
    }

    function getLatestSyncedHeader() public view override returns (bytes32) {
        return state.getL2BlockHash(state.latestVerifiedHeight);
    }

    function getStateVariables()
        public
        view
        returns (
            uint64 /*genesisHeight*/,
            uint64 /*latestVerifiedHeight*/,
            uint64 /*latestVerifiedId*/,
            uint64 /*nextBlockId*/
        )
    {
        return state.getStateVariables();
    }

    function signWithGoldenTouch(
        bytes32 hash,
        uint8 k
    ) public view returns (uint8 v, uint256 r, uint256 s) {
        return LibAnchorSignature.signTransaction(hash, k);
    }

    function getBlockProvers(
        uint256 id,
        bytes32 parentHash
    ) public view returns (address[] memory) {
        return state.forkChoices[id][parentHash].provers;
    }

    function getConstants()
        public
        pure
        returns (
            uint256, // K_ZKPROOFS_PER_BLOCK
            uint256, // K_CHAIN_ID
            uint256, // K_MAX_NUM_BLOCKS
            uint256, // K_MAX_VERIFICATIONS_PER_TX
            uint256, // K_COMMIT_DELAY_CONFIRMS
            uint256, // K_MAX_PROOFS_PER_FORK_CHOICE
            uint256, // K_BLOCK_MAX_GAS_LIMIT
            uint256, // K_BLOCK_MAX_TXS
            uint256, // K_TXLIST_MAX_BYTES
            uint256, // K_TX_MIN_GAS_LIMIT
            uint256 // K_ANCHOR_TX_GAS_LIMIT
        )
    {
        return (
            LibConstants.K_ZKPROOFS_PER_BLOCK,
            LibConstants.K_CHAIN_ID,
            LibConstants.K_MAX_NUM_BLOCKS,
            LibConstants.K_MAX_VERIFICATIONS_PER_TX,
            LibConstants.K_COMMIT_DELAY_CONFIRMS,
            LibConstants.K_MAX_PROOFS_PER_FORK_CHOICE,
            LibConstants.K_BLOCK_MAX_GAS_LIMIT,
            LibConstants.K_BLOCK_MAX_TXS,
            LibConstants.K_TXLIST_MAX_BYTES,
            LibConstants.K_TX_MIN_GAS_LIMIT,
            LibConstants.K_ANCHOR_TX_GAS_LIMIT
        );
    }
}
