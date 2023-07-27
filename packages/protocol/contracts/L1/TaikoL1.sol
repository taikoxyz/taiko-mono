// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../common/AddressResolver.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { ICrossChainSync } from "../common/ICrossChainSync.sol";
import { Proxied } from "../common/Proxied.sol";
import { LibEthDepositing } from "./libs/LibEthDepositing.sol";
import { LibEthDepositing_A3 } from "./A3/libs/LibEthDepositing_A3.sol";
import { LibProposing } from "./libs/LibProposing.sol";
import { LibProposing_A3 } from "./A3/libs/LibProposing_A3.sol";
import { LibProving } from "./libs/LibProving.sol";
import { LibProving_A3 } from "./A3/libs/LibProving_A3.sol";
import { LibTkoDistribution } from "./libs/LibTkoDistribution.sol";
import { LibTokenomics_A3 } from "./A3/libs/LibTokenomics_A3.sol";
import { LibUtils } from "./libs/LibUtils.sol";
import { LibUtils_A3 } from "./A3/libs/LibUtils_A3.sol";
import { LibVerifying } from "./libs/LibVerifying.sol";
import { LibVerifying_A3 } from "./A3/libs/LibVerifying_A3.sol";
import { TaikoConfig } from "./TaikoConfig.sol";
import { TaikoErrors } from "./TaikoErrors.sol";
import { TaikoData } from "./TaikoData.sol";
import { TaikoEvents } from "./TaikoEvents.sol";

/// @custom:security-contact hello@taiko.xyz
contract TaikoL1 is
    EssentialContract,
    ICrossChainSync,
    TaikoEvents,
    TaikoErrors
{
    using LibUtils for TaikoData.State;

    TaikoData.State public state;
    uint256[100] private __gap;

    receive() external payable {
        depositEtherToL2(address(0));
    }

    // This - as an upgrade - so the init() will not have any effect
    /**
     * Initialize the rollup.
     *
     * @param _addressManager The AddressManager address.
     * @param _genesisBlockHash The block hash of the genesis block.
     * @param _initFeePerGas Initial (reasonable) block fee value,
     * @param _initAvgProofDelay Initial (reasonable) proof window.
     */
    function init(
        address _addressManager,
        bytes32 _genesisBlockHash,
        uint32 _initFeePerGas,
        uint16 _initAvgProofDelay
    )
        external
        initializer
    {
        EssentialContract._init(_addressManager);
        LibVerifying.init({
            state: state,
            config: getConfig(),
            genesisBlockHash: _genesisBlockHash,
            initFeePerGas: _initFeePerGas,
            initAvgProofDelay: _initAvgProofDelay
        });
    }

    /**
     * Initialize vars necessary for the upgrade
     * 
     * @param _activationHeight When activation shall happen (block height)
     * @param _initFeePerGas Initial (reasonable) block fee value,
     * @param _initAvgProofDelay Initial (reasonable) proof window.
     */
    function initA4(
        uint32 _activationHeight,
        uint32 _initFeePerGas,
        uint16 _initAvgProofDelay
    )
        external
        onlyOwner
    {
        state.plannedActivationHeight = _activationHeight;
        state.slot6.feePerGas = _initFeePerGas;
        state.slot6.avgProofDelay = _initAvgProofDelay;
    }

    // proposeBlock has no change in terms of return value
    /**
     * Propose a Taiko L2 block.
     *
     * @param input An abi-encoded BlockMetadataInput that the actual L2
     *        block header must satisfy.
     * @param txList A list of transactions in this block, encoded with RLP.
     *        Note, in the corresponding L2 block an _anchor transaction_
     *        will be the first transaction in the block -- if there are
     *        `n` transactions in `txList`, then there will be up to `n + 1`
     *        transactions in the L2 block.
     */
    function proposeBlock(
        bytes calldata input,
        bytes calldata txList
    )
        external
        nonReentrant
        returns (TaikoData.BlockMetadata memory meta)
    {
        TaikoData.Config memory config = getConfig();

        // If we haven't set the plannedActivationHeight yet OR
        // we set but we haven't elapsed that go with the 'old'
        // system
        if(state.plannedActivationHeight == 0
            || 
            (state.plannedActivationHeight != 0 
            && state.slot7.numBlocks < state.plannedActivationHeight)
        ) {
                meta = LibProposing_A3.proposeBlock({
                    state: state,
                    config: config,
                    resolver: AddressResolver(this),
                    input: abi.decode(input, (TaikoData.BlockMetadataInput)),
                    txList: txList
                });
        }
        else {
            meta = LibProposing.proposeBlock({
                state: state,
                config: config,
                resolver: AddressResolver(this),
                input: abi.decode(input, (TaikoData.BlockMetadataInput)),
                txList: txList
            });
        }

        // Which verification to be called
        if(state.plannedActivationHeight == 0
            || 
            (state.plannedActivationHeight != 0 
            && state.slot8.lastVerifiedBlockId < state.plannedActivationHeight)
        ) {
            if (config.blockMaxVerificationsPerTx > 0) {
                    LibVerifying_A3.verifyBlocks({
                        state: state,
                        config: config,
                        resolver: AddressResolver(this),
                        maxBlocks: config.blockMaxVerificationsPerTx
                    });
                }
        }
        else {
            if (config.blockMaxVerificationsPerTx > 0) {
                LibVerifying.verifyBlocks({
                    state: state,
                    config: config,
                    resolver: AddressResolver(this),
                    maxBlocks: config.blockMaxVerificationsPerTx
                });
            }
        }
    }
    // proposeBlock has no change in terms of return value
    /**
     * Prove a block with a zero-knowledge proof.
     *
     * @param blockId The index of the block to prove. This is also used
     *        to select the right implementation version.
     * @param input An abi-encoded TaikoData.BlockEvidence object.
     */
    function proveBlock(
        uint256 blockId,
        bytes calldata input
    )
        external
        nonReentrant
    {
        TaikoData.Config memory config = getConfig();
        if(state.plannedActivationHeight == 0
            || 
            (state.plannedActivationHeight != 0 
            && state.slot7.numBlocks < state.plannedActivationHeight)
        ) {

            LibProving_A3.proveBlock({
                state: state,
                config: config,
                resolver: AddressResolver(this),
                blockId: blockId,
                evidence: abi.decode(input, (TaikoData.BlockEvidence))
            });
        }
        else {
            LibProving.proveBlock({
                state: state,
                config: config,
                resolver: AddressResolver(this),
                blockId: blockId,
                evidence: abi.decode(input, (TaikoData.BlockEvidence))
            });
        }

        // Which verification to be called
        if(state.plannedActivationHeight == 0
            || 
            (state.plannedActivationHeight != 0 
            && state.slot8.lastVerifiedBlockId < state.plannedActivationHeight)
        ) {
            if (config.blockMaxVerificationsPerTx > 0) {
                    LibVerifying_A3.verifyBlocks({
                        state: state,
                        config: config,
                        resolver: AddressResolver(this),
                        maxBlocks: config.blockMaxVerificationsPerTx
                    });
                }
        }
        else {
            if (config.blockMaxVerificationsPerTx > 0) {
                LibVerifying.verifyBlocks({
                    state: state,
                    config: config,
                    resolver: AddressResolver(this),
                    maxBlocks: config.blockMaxVerificationsPerTx
                });
            }
        }
    }

    /**
     * Verify up to N blocks.
     * @param maxBlocks Max number of blocks to verify.
     */
    function verifyBlocks(uint256 maxBlocks) external nonReentrant {
        if (maxBlocks == 0) revert L1_INVALID_PARAM();
         // Which verification to be called
        if(state.plannedActivationHeight == 0
            || 
            (state.plannedActivationHeight != 0 
            && state.slot8.lastVerifiedBlockId < state.plannedActivationHeight)
        ) {
            LibVerifying_A3.verifyBlocks({
                state: state,
                config: getConfig(),
                resolver: AddressResolver(this),
                maxBlocks: maxBlocks
            });
        }
        else {
            LibVerifying.verifyBlocks({
                state: state,
                config: getConfig(),
                resolver: AddressResolver(this),
                maxBlocks: maxBlocks
            });
        }
    }


    /** A3 related
     * Change proof parameters (time target and time issued) - to avoid complex/risky upgrades in case need to change relatively frequently.
     * @param newProofTimeTarget New proof time target.
     * @param newProofTimeIssued New proof time issued. If set to type(uint64).max, let it be unchanged.
     * @param newBlockFee New blockfee. If set to type(uint64).max, let it be unchanged.
     * @param newAdjustmentQuotient New adjustment quotient. If set to type(uint16).max, let it be unchanged.
     */
    function setProofParams(
        uint64 newProofTimeTarget,
        uint64 newProofTimeIssued,
        uint64 newBlockFee,
        uint16 newAdjustmentQuotient
    ) external onlyOwner {
        if (newProofTimeTarget == 0 || newProofTimeIssued == 0) {
            revert L1_INVALID_PARAM();
        }

        state.slot8.proofTimeTarget = newProofTimeTarget;
        // Special case in a way - that we leave the proofTimeIssued unchanged
        // because we think provers will adjust behavior.
        if (newProofTimeIssued != type(uint64).max) {
            state.slot8.proofTimeIssued = newProofTimeIssued;
        }
        // Special case in a way - that we leave the blockFee unchanged
        // because the level we are at is fine.
        if (newBlockFee != type(uint64).max) {
            state.slot8.blockFee = newBlockFee;
        }
        // Special case in a way - that we leave the adjustmentQuotient unchanged
        // because we the 'slowlyness' of the curve is fine.
        if (newAdjustmentQuotient != type(uint16).max) {
            state.slot6.adjustmentQuotient = newAdjustmentQuotient;
        }

        emit ProofParamsChanged(
            newProofTimeTarget, newProofTimeIssued, newBlockFee, newAdjustmentQuotient
        );
    }

    /// @dev For A3 - simply address(0) call makes it, because A3 did
    /// not have this parameter.
    function depositEtherToL2(address recipient) public payable {
        if(state.plannedActivationHeight == 0
            || 
            (state.plannedActivationHeight != 0 
            && state.slot7.numBlocks < state.plannedActivationHeight)
        ) {
            LibEthDepositing_A3.depositEtherToL2({
                state: state,
                config: getConfig(),
                resolver: AddressResolver(this)
            });
        }
        else {
            LibEthDepositing.depositEtherToL2({
                state: state,
                config: getConfig(),
                resolver: AddressResolver(this),
                recipient: recipient
            });
        }
    }

    function depositTaikoToken(uint256 amount) public nonReentrant {
        if(state.plannedActivationHeight == 0
            || 
            (state.plannedActivationHeight != 0 
            && state.slot7.numBlocks < state.plannedActivationHeight)
        ) {
            LibTokenomics_A3.depositTaikoToken(state, AddressResolver(this), amount);
        }
        else {
            LibTkoDistribution.depositTaikoToken(
                state, AddressResolver(this), amount
            );
        }
    }

    function withdrawTaikoToken(uint256 amount) public nonReentrant {
        if(state.plannedActivationHeight == 0
            || 
            (state.plannedActivationHeight != 0 
            && state.slot7.numBlocks < state.plannedActivationHeight)
        ) {
            LibTokenomics_A3.withdrawTaikoToken(state, AddressResolver(this), amount);
        }
        else {    
            LibTkoDistribution.withdrawTaikoToken(
                state, AddressResolver(this), amount
            );
        }
    }

    // A3 does not have it (as a funciton but checks when actually depositing)
    // so safe to just leaves this as is.
    function canDepositEthToL2(uint256 amount) public view returns (bool) {
        return LibEthDepositing.canDepositEthToL2({
            state: state,
            config: getConfig(),
            amount: amount
        });

    }

    function getBlockFee(uint32 gasLimit) public view returns (uint64) {
        if(state.plannedActivationHeight == 0
            || 
            (state.plannedActivationHeight != 0 
            && state.slot7.numBlocks < state.plannedActivationHeight)
        ) {
            return state.slot8.blockFee;
        }
        else {
            return LibUtils.getBlockFee({
                state: state,
                config: getConfig(),
                gasAmount: gasLimit
            });
        }
    }

    function getTaikoTokenBalance(address addr) public view returns (uint256) {
        return state.taikoTokenBalances[addr];
    }

    // After the upgrade the return value will (bytes) because
    // A3 and A4 has different Block structure.
    function getBlock(uint256 blockId)
        public
        view
        returns (
            bytes memory
        )
    {
        if(state.plannedActivationHeight == 0
            || 
            (state.plannedActivationHeight != 0 
            && state.slot7.numBlocks < state.plannedActivationHeight)
        ) {
            TaikoData.Block_A3 storage blk =
                LibProposing_A3.getBlock({state: state, config: getConfig(), blockId: blockId});
            
            return abi.encode(
                blk.metaHash,
                blk.proposer,
                blk.proposedAt
            );
        }
        else {
            TaikoData.Block storage blk = LibProposing.getBlock({
                state: state,
                config: getConfig(),
                blockId: blockId
            });

            return abi.encode(
                blk.metaHash,
                blk.gasLimit,
                blk.nextForkChoiceId,
                blk.verifiedForkChoiceId,
                blk.proverReleased,
                blk.proposer,
                blk.feePerGas,
                blk.proposedAt,
                blk.assignedProver,
                blk.rewardPerGas,
                blk.proofWindow
            );
        }
    }

    function getForkChoice(
        uint256 blockId,
        bytes32 parentHash,
        uint32 parentGasUsed
    )
        public
        view
        returns (TaikoData.ForkChoice memory)
    {
        if(state.plannedActivationHeight == 0
            || 
            (state.plannedActivationHeight != 0 
            && state.slot7.numBlocks < state.plannedActivationHeight)
        ) {
            return LibProving_A3.getForkChoice({
                state: state,
                config: getConfig(),
                blockId: blockId,
                parentHash: parentHash,
                parentGasUsed: parentGasUsed
            });
        }
        else {
            return LibProving.getForkChoice({
                state: state,
                config: getConfig(),
                blockId: blockId,
                parentHash: parentHash,
                parentGasUsed: parentGasUsed
            });
        }
    }

    function getCrossChainBlockHash(uint256 blockId)
        public
        view
        override
        returns (bytes32)
    {
        if(state.plannedActivationHeight == 0
            || 
            (state.plannedActivationHeight != 0 
            && state.slot7.numBlocks < state.plannedActivationHeight)
        ) {
            (bool found, TaikoData.Block_A3 storage blk) =
            LibUtils_A3.getL2ChainData({state: state, config: getConfig(), blockId: blockId});
            return found ? blk.forkChoices[blk.verifiedForkChoiceId].blockHash : bytes32(0);
        }
        else {
            (bool found, TaikoData.Block storage blk) = LibUtils.getL2ChainData({
                state: state,
                config: getConfig(),
                blockId: blockId
            });
            return found
                ? blk.forkChoices[blk.verifiedForkChoiceId].blockHash
                : bytes32(0);
        }
    }

    function getCrossChainSignalRoot(uint256 blockId)
        public
        view
        override
        returns (bytes32)
    {
        if(state.plannedActivationHeight == 0
            || 
            (state.plannedActivationHeight != 0 
            && state.slot7.numBlocks < state.plannedActivationHeight)
        ) {
            (bool found, TaikoData.Block_A3 storage blk) =
            LibUtils_A3.getL2ChainData({state: state, config: getConfig(), blockId: blockId});
            return found ? blk.forkChoices[blk.verifiedForkChoiceId].signalRoot : bytes32(0);
        }
        else {
            (bool found, TaikoData.Block storage blk) = LibUtils.getL2ChainData({
                state: state,
                config: getConfig(),
                blockId: blockId
            });
            return found
                ? blk.forkChoices[blk.verifiedForkChoiceId].signalRoot
                : bytes32(0);
        }
    }

    function getStateVariables()
        public
        view
        returns (bytes memory)
    {
        if(state.plannedActivationHeight == 0
            ||
            (state.plannedActivationHeight != 0 
            && state.slot7.numBlocks < state.plannedActivationHeight)
        ) {
            return abi.encode(LibUtils_A3.getStateVariables({state: state}));
        }
        else {
            return abi.encode(state.getStateVariables());
        }
    }

    function getConfig()
        public
        pure
        virtual
        returns (TaikoData.Config memory)
    {
        return TaikoConfig.getConfig();
    }

    // Same in A3
    function getVerifierName(uint16 id) public pure returns (bytes32) {
        return LibUtils.getVerifierName(id);
    }
}

contract ProxiedTaikoL1 is Proxied, TaikoL1 { }
