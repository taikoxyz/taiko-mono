// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../common/AddressResolver.sol";
import {EssentialContract} from "../common/EssentialContract.sol";
import {IXchainSync} from "../common/IXchainSync.sol";
import {LibL1Tokenomics} from "./libs/LibL1Tokenomics.sol";
import {LibL2Tokenomics} from "./libs/LibL2Tokenomics.sol";
import {LibProposing} from "./libs/LibProposing.sol";
import {LibProving} from "./libs/LibProving.sol";
import {LibUtils} from "./libs/LibUtils.sol";
import {LibVerifying} from "./libs/LibVerifying.sol";
import {TaikoConfig} from "./TaikoConfig.sol";
import {TaikoErrors} from "./TaikoErrors.sol";
import {TaikoData} from "./TaikoData.sol";
import {TaikoEvents} from "./TaikoEvents.sol";

contract TaikoL1 is EssentialContract, IXchainSync, TaikoEvents, TaikoErrors {
    using LibUtils for TaikoData.State;

    TaikoData.State public state;
    uint256[100] private __gap;

    function init(
        address _addressManager,
        bytes32 _genesisBlockHash,
        uint64 _feeBase,
        uint64 _gasAccumulated
    ) external initializer {
        EssentialContract._init(_addressManager);
        LibVerifying.init({
            state: state,
            config: getConfig(),
            genesisBlockHash: _genesisBlockHash,
            feeBase: _feeBase,
            gasAccumulated: _gasAccumulated
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
    function proposeBlock(
        bytes calldata input,
        bytes calldata txList
    ) external payable nonReentrant {
        TaikoData.Config memory config = getConfig();
        LibProposing.proposeBlock({
            state: state,
            config: config,
            resolver: AddressResolver(this),
            input: abi.decode(input, (TaikoData.BlockMetadataInput)),
            txList: txList
        });
        if (config.maxVerificationsPerTx > 0) {
            LibVerifying.verifyBlocks({
                state: state,
                config: config,
                maxBlocks: config.maxVerificationsPerTx
            });
        }
    }

    /**
     * Prove a block is valid with a zero-knowledge proof, a transaction
     * merkel proof, and a receipt merkel proof.
     *
     * @param blockId The index of the block to prove. This is also used
     *        to select the right implementation version.
     * @param input An abi-encoded TaikoData.ValidBlockEvidence object.
     */

    function proveBlock(
        uint256 blockId,
        bytes calldata input
    ) external nonReentrant {
        TaikoData.Config memory config = getConfig();
        LibProving.proveBlock({
            state: state,
            config: config,
            resolver: AddressResolver(this),
            blockId: blockId,
            evidence: abi.decode(input, (TaikoData.BlockEvidence))
        });
        if (config.maxVerificationsPerTx > 0) {
            LibVerifying.verifyBlocks({
                state: state,
                config: config,
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
        LibVerifying.verifyBlocks({
            state: state,
            config: getConfig(),
            maxBlocks: maxBlocks
        });
    }

    function deposit(uint256 amount) external nonReentrant {
        LibL1Tokenomics.deposit(state, AddressResolver(this), amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        LibL1Tokenomics.withdraw(state, AddressResolver(this), amount);
    }

    function getBalance(address addr) public view returns (uint256) {
        return state.balances[addr];
    }

    function getBlockFee()
        public
        view
        returns (uint256 feeAmount, uint256 depositAmount)
    {
        (, feeAmount, depositAmount) = LibL1Tokenomics.getBlockFee(
            state,
            getConfig()
        );
    }

    function getProofReward(
        uint64 provenAt,
        uint64 proposedAt
    ) public view returns (uint256 reward) {
        (, reward, ) = LibL1Tokenomics.getProofReward({
            state: state,
            config: getConfig(),
            provenAt: provenAt,
            proposedAt: proposedAt
        });
    }

    function getBlock(
        uint256 blockId
    )
        public
        view
        returns (
            bytes32 _metaHash,
            uint256 _deposit,
            address _proposer,
            uint64 _proposedAt
        )
    {
        TaikoData.Block storage blk = LibProposing.getBlock({
            state: state,
            config: getConfig(),
            blockId: blockId
        });
        _metaHash = blk.metaHash;
        _deposit = blk.deposit;
        _proposer = blk.proposer;
        _proposedAt = blk.proposedAt;
    }

    function getForkChoice(
        uint256 blockId,
        bytes32 parentHash
    ) public view returns (TaikoData.ForkChoice memory) {
        return
            LibProving.getForkChoice({
                state: state,
                config: getConfig(),
                blockId: blockId,
                parentHash: parentHash
            });
    }

    function getXchainBlockHash(
        uint256 blockId
    ) public view override returns (bytes32) {
        (bool found, TaikoData.Block storage blk) = LibUtils.getL2ChainData({
            state: state,
            config: getConfig(),
            blockId: blockId
        });
        return
            found
                ? blk.forkChoices[blk.verifiedForkChoiceId].blockHash
                : bytes32(0);
    }

    function getXchainSignalRoot(
        uint256 blockId
    ) public view override returns (bytes32) {
        (bool found, TaikoData.Block storage blk) = LibUtils.getL2ChainData({
            state: state,
            config: getConfig(),
            blockId: blockId
        });

        return
            found
                ? blk.forkChoices[blk.verifiedForkChoiceId].signalRoot
                : bytes32(0);
    }

    function get1559Basefee(
        uint32 gasLimit
    ) public view returns (uint64 basefee) {
        (, basefee, ) = LibL2Tokenomics.get1559Basefee(
            state,
            getConfig(),
            gasLimit
        );
    }

    function getStateVariables()
        public
        view
        returns (TaikoData.StateVariables memory)
    {
        return state.getStateVariables(getConfig());
    }

    function getConfig() public pure virtual returns (TaikoData.Config memory) {
        return TaikoConfig.getConfig();
    }
}
