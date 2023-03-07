// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../common/AddressResolver.sol";
import {EssentialContract} from "../common/EssentialContract.sol";
import {IXchainSync} from "../common/IXchainSync.sol";
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
     *        - inputs[1] is called the `txList` which is list of transactions in
     *          this block, encoded with RLP.
     *          Note, in the corresponding L2 block an _anchor transaction_
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

    /**
     * Prove a block is valid with a zero-knowledge proof, a transaction
     * merkel proof, and a receipt merkel proof.
     *
     * @param blockId The index of the block to prove. This is also used
     *        to select the right implementation version.
     * @param evidenceBytes An abi-encoded TaikoData.ValidBlockEvidence object.
     */

    function proveBlock(
        uint256 blockId,
        bytes calldata evidenceBytes
    ) external onlyFromEOA nonReentrant {
        TaikoData.Config memory config = getConfig();
        LibProving.proveBlock({
            state: state,
            config: config,
            resolver: AddressResolver(this),
            blockId: blockId,
            evidenceBytes: evidenceBytes
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
     * @param evidenceBytes evidenceBytes An abi-encoded TaikoData.InvalidBlockEvidence object.
     */
    function proveBlockInvalid(
        uint256 blockId,
        bytes calldata evidenceBytes
    ) external onlyFromEOA nonReentrant {
        TaikoData.Config memory config = getConfig();

        LibProving.proveBlockInvalid({
            state: state,
            config: config,
            resolver: AddressResolver(this),
            blockId: blockId,
            evidenceBytes: evidenceBytes
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

    function deposit(uint256 amount) external nonReentrant {
        LibVerifying.deposit(state, AddressResolver(this), amount);
    }

    function withdraw() external nonReentrant {
        LibVerifying.withdraw(state, AddressResolver(this));
    }

    function getBalance(address addr) public view returns (uint256) {
        return state.balances[addr];
    }

    function getBlockFee() public view returns (uint256) {
        (, uint256 feeAmount, uint256 depositAmount) = LibProposing.getBlockFee(
            state,
            getConfig()
        );
        return feeAmount + depositAmount;
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

    function getProposedBlock(
        uint256 id
    ) public view returns (TaikoData.ProposedBlock memory) {
        return
            LibProposing.getProposedBlock(state, getConfig().maxNumBlocks, id);
    }

    function getXchainBlockHash(
        uint256 number
    ) public view override returns (bytes32) {
        return
            state.getL2Snippet(number, getConfig().blockHashHistory).blockHash;
    }

    function getXchainSignalRoot(
        uint256 number
    ) public view override returns (bytes32) {
        return
            state.getL2Snippet(number, getConfig().blockHashHistory).signalRoot;
    }

    function getStateVariables()
        public
        view
        returns (LibUtils.StateVariables memory)
    {
        return state.getStateVariables();
    }

    function getForkChoice(
        uint256 id,
        bytes32 parentHash
    ) public view returns (TaikoData.ForkChoice memory) {
        return state.forkChoices[id][parentHash];
    }

    function getConfig() public pure virtual returns (TaikoData.Config memory) {
        return TaikoConfig.getConfig();
    }
}
