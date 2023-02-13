// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../common/EssentialContract.sol";
import "../common/IHeaderSync.sol";
import "../libs/LibAnchorSignature.sol";
import "../libs/LibSharedConfig.sol";
import "./TaikoData.sol";
import "./TaikoEvents.sol";
import "./libs/LibProposing.sol";
import "./libs/LibProving.sol";
import "./libs/LibUtils.sol";
import "./libs/LibVerifying.sol";

/**
 * @author dantaik <dan@taiko.xyz>
 */
contract TaikoL1 is EssentialContract, IHeaderSync, TaikoEvents {
    using LibUtils for TaikoData.State;

    TaikoData.State public state;
    uint256[100] private __gap;

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
    function proposeBlock(bytes[] calldata inputs) external nonReentrant {
        TaikoData.Config memory config = getConfig();
        LibProposing.proposeBlock({
            state: state,
            config: config,
            resolver: AddressResolver(this),
            inputs: inputs
        });
        LibVerifying.verifyBlocks({
            state: state,
            config: getConfig(),
            resolver: AddressResolver(this),
            maxBlocks: config.maxVerificationsPerTx,
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
            resolver: AddressResolver(this),
            maxBlocks: config.maxVerificationsPerTx,
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
            resolver: AddressResolver(this),
            maxBlocks: config.maxVerificationsPerTx,
            checkHalt: false
        });
    }

    /**
     * Verify up to N blocks.
     * @param maxBlocks Max number of blocks to verify.
     */
    function verifyBlocks(uint256 maxBlocks) external nonReentrant {
        require(maxBlocks > 0, "L1:maxBlocks");
        LibVerifying.verifyBlocks({
            state: state,
            config: getConfig(),
            resolver: AddressResolver(this),
            maxBlocks: maxBlocks,
            checkHalt: true
        });
    }

    /**
     * Halt or resume the chain.
     * @param toHalt True to halt, false to resume.
     */
    function halt(bool toHalt) public onlyOwner {
        LibUtils.halt(state, toHalt);
    }

    function getBlockFee() public view returns (uint256) {
        (, uint fee, uint deposit) = LibProposing.getBlockFee(
            state,
            getConfig()
        );
        return fee + deposit;
    }

    function getProofReward(
        uint64 provenAt,
        uint64 proposedAt
    ) public view returns (uint256 reward) {
        (, reward, ) = LibVerifying.getProofReward({
            state: state,
            config: getConfig(),
            provenAt: provenAt,
            proposedAt: proposedAt
        });
    }

    /**
     * Check if the L1 is halted.
     * @return True if halted, false otherwise.
     */
    function isHalted() public view returns (bool) {
        return LibUtils.isHalted(state);
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

    function getUncleProofDelay(uint256 blockId) public view returns (uint64) {
        return LibUtils.getUncleProofDelay(state, getConfig(), blockId);
    }

    function getConfig() public pure virtual returns (TaikoData.Config memory) {
        return LibSharedConfig.getConfig();
    }

    function isBlockVerifiable(
        uint256 blockId,
        bytes32 parentHash
    ) public view returns (bool) {
        return
            LibVerifying.isVerifiable({
                state: state,
                config: getConfig(),
                fc: state.forkChoices[blockId][parentHash],
                blockId: blockId
            });
    }
}
