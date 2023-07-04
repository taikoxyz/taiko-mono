// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {AddressResolver} from "../common/AddressResolver.sol";
import {EssentialContract} from "../common/EssentialContract.sol";
import {ICrossChainSync} from "../common/ICrossChainSync.sol";
import {Proxied} from "../common/Proxied.sol";
import {LibEthDepositing_A3} from "./A3/libs_a3/LibEthDepositing_A3.sol";
import {LibTokenomics_A3} from "./A3/libs_a3/LibTokenomics_A3.sol";
import {LibProposing_A3} from "./A3/libs_a3/LibProposing_A3.sol";
import {LibProving_A3} from "./A3/libs_a3/LibProving_A3.sol";
import {LibUtils_A3} from "./A3/libs_a3/LibUtils_A3.sol";
import {LibVerifying_A3} from "./A3/libs_a3/LibVerifying_A3.sol";
import {TaikoConfig_A3} from "./A3/TaikoConfig_A3.sol";
import {TaikoErrors} from "./TaikoErrors.sol";
import {TaikoData_A3} from "./A3/TaikoData_A3.sol";
import {TaikoEvents} from "./TaikoEvents.sol";

/// @custom:security-contact hello@taiko.xyz
contract TaikoL1 is EssentialContract, ICrossChainSync, TaikoEvents, TaikoErrors {
    using LibUtils_A3 for TaikoData_A3.State;

    TaikoData_A3.State public state;
    uint256[100] private __gap;

    receive() external payable {
        depositEtherToL2();
    }

    /**
     * Initialize the rollup.
     *
     * @param _addressManager The AddressManager address.
     * @param _genesisBlockHash The block hash of the genesis block.
     * @param _initBlockFee Initial (reasonable) block fee value.
     * @param _initProofTimeTarget Initial (reasonable) proof submission time target.
     * @param _initProofTimeIssued Initial proof time issued corresponding
     *        with the initial block fee.
     * @param _adjustmentQuotient Block fee calculation adjustment quotient.
     */
    function init(
        address _addressManager,
        bytes32 _genesisBlockHash,
        uint64 _initBlockFee,
        uint64 _initProofTimeTarget,
        uint64 _initProofTimeIssued,
        uint16 _adjustmentQuotient
    ) external initializer {
        EssentialContract._init(_addressManager);
        LibVerifying_A3.init({
            state: state,
            config: getConfig(),
            genesisBlockHash: _genesisBlockHash,
            initBlockFee: _initBlockFee,
            initProofTimeTarget: _initProofTimeTarget,
            initProofTimeIssued: _initProofTimeIssued,
            adjustmentQuotient: _adjustmentQuotient
        });
    }

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
    function proposeBlock(bytes calldata input, bytes calldata txList)
        external
        nonReentrant
        returns (TaikoData_A3.BlockMetadata memory meta)
    {
        TaikoData_A3.Config memory config = getConfig();
        meta = LibProposing_A3.proposeBlock({
            state: state,
            config: config,
            resolver: AddressResolver(this),
            input: abi.decode(input, (TaikoData_A3.BlockMetadataInput)),
            txList: txList
        });
        if (config.maxVerificationsPerTx > 0) {
            LibVerifying_A3.verifyBlocks({
                state: state,
                config: config,
                resolver: AddressResolver(this),
                maxBlocks: config.maxVerificationsPerTx
            });
        }
    }

    /**
     * Prove a block with a zero-knowledge proof.
     *
     * @param blockId The index of the block to prove. This is also used
     *        to select the right implementation version.
     * @param input An abi-encoded TaikoData_A3.BlockEvidence object.
     */
    function proveBlock(uint256 blockId, bytes calldata input) external nonReentrant {
        TaikoData_A3.Config memory config = getConfig();
        LibProving_A3.proveBlock({
            state: state,
            config: config,
            resolver: AddressResolver(this),
            blockId: blockId,
            evidence: abi.decode(input, (TaikoData_A3.BlockEvidence))
        });
        if (config.maxVerificationsPerTx > 0) {
            LibVerifying_A3.verifyBlocks({
                state: state,
                config: config,
                resolver: AddressResolver(this),
                maxBlocks: config.maxVerificationsPerTx
            });
        }
    }

    /**
     * Verify up to N blocks.
     * @param maxBlocks Max number of blocks to verify.
     */
    function verifyBlocks(uint256 maxBlocks) external nonReentrant {
        if (maxBlocks == 0) revert L1_INVALID_PARAM();
        LibVerifying_A3.verifyBlocks({
            state: state,
            config: getConfig(),
            resolver: AddressResolver(this),
            maxBlocks: maxBlocks
        });
    }

    /**
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

        state.proofTimeTarget = newProofTimeTarget;
        // Special case in a way - that we leave the proofTimeIssued unchanged
        // because we think provers will adjust behavior.
        if (newProofTimeIssued != type(uint64).max) {
            state.proofTimeIssued = newProofTimeIssued;
        }
        // Special case in a way - that we leave the blockFee unchanged
        // because the level we are at is fine.
        if (newBlockFee != type(uint64).max) {
            state.blockFee = newBlockFee;
        }
        // Special case in a way - that we leave the adjustmentQuotient unchanged
        // because we the 'slowlyness' of the curve is fine.
        if (newAdjustmentQuotient != type(uint16).max) {
            state.adjustmentQuotient = newAdjustmentQuotient;
        }

        emit ProofParamsChanged(
            newProofTimeTarget, newProofTimeIssued, newBlockFee, newAdjustmentQuotient
        );
    }

    function depositTaikoToken(uint256 amount) external nonReentrant {
        LibTokenomics_A3.depositTaikoToken(state, AddressResolver(this), amount);
    }

    function withdrawTaikoToken(uint256 amount) external nonReentrant {
        LibTokenomics_A3.withdrawTaikoToken(state, AddressResolver(this), amount);
    }

    function depositEtherToL2() public payable {
        LibEthDepositing_A3.depositEtherToL2(state, getConfig(), AddressResolver(this));
    }

    function getTaikoTokenBalance(address addr) public view returns (uint256) {
        return state.taikoTokenBalances[addr];
    }

    function getBlockFee() public view returns (uint64) {
        return state.blockFee;
    }

    function getProofReward(uint64 proofTime) public view returns (uint64) {
        return LibTokenomics_A3.getProofReward(state, proofTime);
    }

    function getBlock(uint256 blockId)
        public
        view
        returns (bytes32 _metaHash, address _proposer, uint64 _proposedAt)
    {
        TaikoData_A3.Block storage blk =
            LibProposing_A3.getBlock({state: state, config: getConfig(), blockId: blockId});
        _metaHash = blk.metaHash;
        _proposer = blk.proposer;
        _proposedAt = blk.proposedAt;
    }

    function getForkChoice(uint256 blockId, bytes32 parentHash, uint32 parentGasUsed)
        public
        view
        returns (TaikoData_A3.ForkChoice memory)
    {
        return LibProving_A3.getForkChoice({
            state: state,
            config: getConfig(),
            blockId: blockId,
            parentHash: parentHash,
            parentGasUsed: parentGasUsed
        });
    }

    function getCrossChainBlockHash(uint256 blockId) public view override returns (bytes32) {
        (bool found, TaikoData_A3.Block storage blk) =
            LibUtils_A3.getL2ChainData({state: state, config: getConfig(), blockId: blockId});
        return found ? blk.forkChoices[blk.verifiedForkChoiceId].blockHash : bytes32(0);
    }

    function getCrossChainSignalRoot(uint256 blockId) public view override returns (bytes32) {
        (bool found, TaikoData_A3.Block storage blk) =
            LibUtils_A3.getL2ChainData({state: state, config: getConfig(), blockId: blockId});

        return found ? blk.forkChoices[blk.verifiedForkChoiceId].signalRoot : bytes32(0);
    }

    function getStateVariables() public view returns (TaikoData_A3.StateVariables memory) {
        return state.getStateVariables();
    }

    function getConfig() public pure virtual returns (TaikoData_A3.Config memory) {
        return TaikoConfig_A3.getConfig();
    }

    function getVerifierName(uint16 id) public pure returns (bytes32) {
        return LibUtils_A3.getVerifierName(id);
    }
}

contract ProxiedTaikoL1 is Proxied, TaikoL1 {}
