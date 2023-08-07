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
import { LibProposing } from "./libs/LibProposing.sol";
import { LibProving } from "./libs/LibProving.sol";
import { LibTaikoToken } from "./libs/LibTaikoToken.sol";
import { LibUtils } from "./libs/LibUtils.sol";
import { LibVerifying } from "./libs/LibVerifying.sol";
import { TaikoConfig } from "./TaikoConfig.sol";
import { TaikoErrors } from "./TaikoErrors.sol";
import { TaikoData } from "./TaikoData.sol";
import { TaikoEvents } from "./TaikoEvents.sol";

/**
 * @title TaikoL1
 * @notice This contract serves as the Layer 1 contract of the Taiko protocol,
 * providing functionalities for proposing, proving, and verifying blocks. It
 * also handles deposit and withdrawal of Taiko tokens and Ether.
 */
contract TaikoL1 is
    EssentialContract,
    ICrossChainSync,
    TaikoEvents,
    TaikoErrors
{
    using LibUtils for TaikoData.State;

    TaikoData.State public state;
    uint256[100] private __gap;

    // Fallback function to receive Ether and deposit it to Layer 2.
    receive() external payable {
        depositEtherToL2(address(0));
    }

    /**
     * Initialize the rollup.
     *
     * @param _addressManager The AddressManager address.
     * @param _genesisBlockHash The block hash of the genesis block.
     * @param _initFeePerGas Initial (reasonable) block fee value.
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
     * Propose a Taiko L2 block.
     *
     * @param input An abi-encoded BlockMetadataInput that the actual L2
     *        block header must satisfy.
     * @param txList A list of transactions in this block, encoded with RLP.
     *        Note, in the corresponding L2 block an _anchor transaction_
     *        will be the first transaction in the block -- if there are
     *        `n` transactions in `txList`, then there will be up to `n + 1`
     *        transactions in the L2 block.
     * @return meta The metadata of the proposed L2 block.
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
        meta = LibProposing.proposeBlock({
            state: state,
            config: config,
            resolver: AddressResolver(this),
            input: abi.decode(input, (TaikoData.BlockMetadataInput)),
            txList: txList
        });
        if (config.blockMaxVerificationsPerTx > 0) {
            LibVerifying.verifyBlocks({
                state: state,
                config: config,
                resolver: AddressResolver(this),
                maxBlocks: config.blockMaxVerificationsPerTx
            });
        }
    }

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
        LibProving.proveBlock({
            state: state,
            config: config,
            resolver: AddressResolver(this),
            blockId: blockId,
            evidence: abi.decode(input, (TaikoData.BlockEvidence))
        });
        if (config.blockMaxVerificationsPerTx > 0) {
            LibVerifying.verifyBlocks({
                state: state,
                config: config,
                resolver: AddressResolver(this),
                maxBlocks: config.blockMaxVerificationsPerTx
            });
        }
    }

    /**
     * Verify up to N blocks.
     * @param maxBlocks Max number of blocks to verify.
     */
    function verifyBlocks(uint256 maxBlocks) external nonReentrant {
        if (maxBlocks == 0) revert L1_INVALID_PARAM();
        LibVerifying.verifyBlocks({
            state: state,
            config: getConfig(),
            resolver: AddressResolver(this),
            maxBlocks: maxBlocks
        });
    }

    /**
     * Deposit Ether to Layer 2.
     * @param recipient Address of the recipient for the deposited Ether on
     * Layer 2.
     */
    function depositEtherToL2(address recipient) public payable {
        LibEthDepositing.depositEtherToL2({
            state: state,
            config: getConfig(),
            resolver: AddressResolver(this),
            recipient: recipient
        });
    }

    /**
     * Deposit Taiko tokens to the contract.
     * @param amount Amount of Taiko tokens to deposit.
     */
    function depositTaikoToken(uint256 amount) public nonReentrant {
        LibTaikoToken.depositTaikoToken(state, AddressResolver(this), amount);
    }

    /**
     * Withdraw Taiko tokens from the contract.
     * @param amount Amount of Taiko tokens to withdraw.
     */
    function withdrawTaikoToken(uint256 amount) public nonReentrant {
        LibTaikoToken.withdrawTaikoToken(state, AddressResolver(this), amount);
    }

    /**
     * Check if Ether deposit is allowed for Layer 2.
     * @param amount Amount of Ether to be deposited.
     * @return true if Ether deposit is allowed, false otherwise.
     */
    function canDepositEthToL2(uint256 amount) public view returns (bool) {
        return LibEthDepositing.canDepositEthToL2({
            state: state,
            config: getConfig(),
            amount: amount
        });
    }

    /**
     * Get the block fee for a given gas limit.
     * @param gasLimit Gas limit for the block.
     * @return The block fee in Taiko tokens.
     */
    function getBlockFee(uint32 gasLimit) public view returns (uint64) {
        return LibUtils.getBlockFee({
            state: state,
            config: getConfig(),
            gasAmount: gasLimit
        });
    }

    /**
     * Get the Taiko token balance for a specific address.
     * @param addr Address to check the Taiko token balance.
     * @return The Taiko token balance of the address.
     */
    function getTaikoTokenBalance(address addr) public view returns (uint256) {
        return state.taikoTokenBalances[addr];
    }

    /**
     * Get the details of a block.
     * @param blockId Index of the block.
     * @return _metaHash Metadata hash of the block.
     * @return _gasLimit Gas limit of the block.
     * @return _nextForkChoiceId Next fork choice ID of the block.
     * @return _verifiedForkChoiceId Verified fork choice ID of the block.
     * @return _proverReleased True if the prover has been released for the
     * block, false otherwise.
     * @return _proposer Address of the block proposer.
     * @return _feePerGas Fee per gas of the block.
     * @return _proposedAt Timestamp when the block was proposed.
     * @return _assignedProver Address of the assigned prover for the block.
     * @return _rewardPerGas Reward per gas of the block.
     * @return _proofWindow Proof window of the block.
     */
    function getBlock(uint256 blockId)
        public
        view
        returns (
            bytes32 _metaHash,
            uint32 _gasLimit,
            uint24 _nextForkChoiceId,
            uint24 _verifiedForkChoiceId,
            bool _proverReleased,
            address _proposer,
            uint32 _feePerGas,
            uint64 _proposedAt,
            address _assignedProver,
            uint32 _rewardPerGas,
            uint64 _proofWindow
        )
    {
        TaikoData.Block storage blk = LibProposing.getBlock({
            state: state,
            config: getConfig(),
            blockId: blockId
        });
        _metaHash = blk.metaHash;
        _gasLimit = blk.gasLimit;
        _nextForkChoiceId = blk.nextForkChoiceId;
        _verifiedForkChoiceId = blk.verifiedForkChoiceId;
        _proverReleased = blk.proverReleased;
        _proposer = blk.proposer;
        _feePerGas = blk.feePerGas;
        _proposedAt = blk.proposedAt;
        _assignedProver = blk.assignedProver;
        _rewardPerGas = blk.rewardPerGas;
        _proofWindow = blk.proofWindow;
    }

    /**
     * Get the fork choice for a specific block.
     * @param blockId Index of the block.
     * @param parentHash Parent hash of the block.
     * @param parentGasUsed Gas used by the parent block.
     * @return ForkChoice struct of the block.
     */
    function getForkChoice(
        uint256 blockId,
        bytes32 parentHash,
        uint32 parentGasUsed
    )
        public
        view
        returns (TaikoData.ForkChoice memory)
    {
        return LibProving.getForkChoice({
            state: state,
            config: getConfig(),
            blockId: blockId,
            parentHash: parentHash,
            parentGasUsed: parentGasUsed
        });
    }

    /**
     * Get the block hash of the specified Layer 2 block.
     * @param blockId Index of the block.
     * @return Block hash of the specified block.
     */
    function getCrossChainBlockHash(uint256 blockId)
        public
        view
        override
        returns (bytes32)
    {
        (bool found, TaikoData.Block storage blk) = LibUtils.getL2ChainData({
            state: state,
            config: getConfig(),
            blockId: blockId
        });
        return found
            ? blk.forkChoices[blk.verifiedForkChoiceId].blockHash
            : bytes32(0);
    }

    /**
     * Get the signal root of the specified Layer 2 block.
     * @param blockId Index of the block.
     * @return Signal root of the specified block.
     */
    function getCrossChainSignalRoot(uint256 blockId)
        public
        view
        override
        returns (bytes32)
    {
        (bool found, TaikoData.Block storage blk) = LibUtils.getL2ChainData({
            state: state,
            config: getConfig(),
            blockId: blockId
        });

        return found
            ? blk.forkChoices[blk.verifiedForkChoiceId].signalRoot
            : bytes32(0);
    }

    /**
     * Get the state variables of the Taiko L1 contract.
     * @return StateVariables struct containing state variables.
     */
    function getStateVariables()
        public
        view
        returns (TaikoData.StateVariables memory)
    {
        return state.getStateVariables();
    }

    /**
     * Get the configuration of the Taiko L1 contract.
     * @return TaikoData.Config struct containing configuration parameters.
     */
    function getConfig()
        public
        pure
        virtual
        returns (TaikoData.Config memory)
    {
        return TaikoConfig.getConfig();
    }

    /**
     * Get the name of the verifier by ID.
     * @param id ID of the verifier.
     * @return Verifier name.
     */
    function getVerifierName(uint16 id) public pure returns (bytes32) {
        return LibUtils.getVerifierName(id);
    }
}

/**
 * @title ProxiedTaikoL1
 * @dev Proxied version of the TaikoL1 contract.
 */
contract ProxiedTaikoL1 is Proxied, TaikoL1 { }
