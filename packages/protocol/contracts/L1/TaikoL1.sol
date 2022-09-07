// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import "../common/EssentialContract.sol";
import "../common/ConfigManager.sol";
import "../L2/TaikoL2.sol";
import "../libs/LibBlockHeader.sol";
import "../libs/LibConstants.sol";
import "../libs/LibTxDecoder.sol";
import "../libs/LibReceiptDecoder.sol";
import "../libs/LibZKP.sol";
import "../thirdparty/Lib_BytesUtils.sol";
import "../thirdparty/Lib_MerkleTrie.sol";
import "../thirdparty/Lib_RLPWriter.sol";

// import "./broker/IProtoBroker.sol";

/// @dev We have quit a few ZKP design assumptions. These assumptions are documentd in
///      https://github.com/taikochain/taiko-mono/packages/protocol/DESIGN.md
///
/// This contract shall be deployed as the initial implementation of a
/// https://docs.openzeppelin.com/contracts/4.x/api/proxy#UpgradeableBeacon contract,
/// then a https://docs.openzeppelin.com/contracts/4.x/api/proxy#BeaconProxy contract
/// shall be deployed infront of it.
contract TaikoL1 is EssentialContract {
    using LibBlockHeader for BlockHeader;
    using LibTxDecoder for bytes;
    using SafeCastUpgradeable for uint256;

    /**********************
     * Structs            *
     **********************/
    enum EverProven {
        _NO, //=0
        NO, //=1
        YES //=2
    }

    struct PendingBlock {
        bytes32 contextHash;
        uint128 proposerFee;
        uint8 everProven;
    }

    struct BlockContext {
        uint256 id;
        uint256 anchorHeight;
        bytes32 anchorHash;
        address beneficiary;
        uint64 gasLimit;
        uint64 proposedAt;
        bytes32 txListHash;
        bytes32 mixHash;
        bytes extraData;
    }

    struct ForkChoice {
        bytes32 blockHash;
        uint64 proposedAt;
        uint64 provenAt;
        address[] provers;
    }

    struct Evidence {
        BlockContext context;
        BlockHeader header;
        address prover;
        bytes32 parentHash;
        bytes[] proofs;
    }

    /**********************
     * State Variables    *
     **********************/

    // block id => block hash
    mapping(uint256 => bytes32) public finalizedBlocks;

    // block id => PendingBlock
    mapping(uint256 => PendingBlock) public pendingBlocks;

    // block id => parent hash => fork choice
    mapping(uint256 => mapping(bytes32 => ForkChoice)) public forkChoices;

    mapping(bytes32 => uint256) public commits;

    uint64 public genesisHeight;
    uint64 public lastFinalizedHeight;
    uint64 public lastFinalizedId;
    uint64 public nextPendingId;
    uint64 public numUnprovenBlocks;

    uint256[44] private __gap;

    /**********************
     * Events             *
     **********************/

    event BlockCommitted(bytes32 hash, uint256 validSince);

    event BlockProposed(uint256 indexed id, BlockContext context);

    event BlockProven(
        uint256 indexed id,
        bytes32 parentHash,
        bytes32 blockHash,
        uint64 proposedAt,
        uint64 provenAt,
        address prover
    );

    event BlockFinalized(
        uint256 indexed id,
        uint256 indexed height,
        bytes32 blockHash
    );

    /**********************
     * External Functions *
     **********************/

    function init(address _addressManager, bytes32 _genesisBlockHash)
        external
        initializer
    {
        EssentialContract._init(_addressManager);

        finalizedBlocks[0] = _genesisBlockHash;
        nextPendingId = 1;
        genesisHeight = uint64(block.number);

        emit BlockFinalized(0, 0, _genesisBlockHash);
    }

    /// @notice Write a _commit hash_ so a few blocks later a L2 block can be proposed
    ///         such that `calculateCommitHash(context.beneficiary, context.txListHash)`
    ///         equals to this commit hash.
    /// @param commitHash A commit hash calculated as: `calculateCommitHash(beneficiary, txListHash)`.
    function commitBlock(bytes32 commitHash) external {
        require(commitHash != 0, "L1:hash");
        require(commits[commitHash] == 0, "L1:committed");
        commits[commitHash] = block.number;

        emit BlockCommitted(
            commitHash,
            block.number + LibConstants.TAIKO_COMMIT_DELAY_CONFIRMATIONS
        );
    }

    /// @notice Propose a Taiko L2 block.
    /// @param inputs A list of data input:
    ///
    ///     - inputs[0] is abi-encoded BlockContext that the actual L2 block header
    ///       must satisfy.
    ///       Note the following fields in the provided context object must
    ///       be zeros -- their actual values will be provisioned by Ethereum.
    ///        - id
    ///        - anchorHeight
    ///        - context.anchorHash
    ///        - mixHash
    ///        - proposedAt
    ///
    ///     - inputs[1] is a list of transactions in this block, encoded with RLP.
    ///       Note in the corresponding L2 block, an _anchor transaction_ will be
    ///       the first transaction in the block, i.e., if there are n transactions
    ///       in `txList`, then then will be up to n+1 transactions in the L2 block.
    function proposeBlock(bytes[] calldata inputs)
        external
        payable
        nonReentrant
    {
        require(inputs.length == 2, "L1:inputs:size");
        BlockContext memory context = abi.decode(inputs[0], (BlockContext));
        bytes calldata txList = inputs[1];

        validateContext(context);

        bytes32 commitHash = calculateCommitHash(
            context.beneficiary,
            context.txListHash
        );

        require(isCommitValid(commitHash), "L1:commit");
        delete commits[commitHash];

        require(
            txList.length > 0 &&
                txList.length <= LibConstants.TAIKO_BLOCK_MAX_TXLIST_BYTES &&
                context.txListHash == txList.hashTxList(),
            "L1:txList"
        );
        require(
            nextPendingId <=
                lastFinalizedId + LibConstants.TAIKO_MAX_PENDING_BLOCKS,
            "L1:tooMany"
        );

        context.id = nextPendingId;
        context.anchorHeight = block.number - 1;
        context.anchorHash = blockhash(block.number - 1);
        context.proposedAt = uint64(block.timestamp);

        // if multiple L2 blocks included in the same L1 block,
        // their block.mixHash fields for randomness will be the same.
        context.mixHash = bytes32(block.difficulty);

        uint256 proposerFee = 0;
        // IProtoBroker(resolve("proto_broker"))
        //     .chargeProposer(
        //         nextPendingId,
        //         msg.sender,
        //         context.gasLimit,
        //         numUnprovenBlocks
        //     );

        _savePendingBlock(
            nextPendingId,
            PendingBlock({
                contextHash: _hashContext(context),
                proposerFee: proposerFee.toUint128(),
                everProven: uint8(EverProven.NO)
            })
        );

        numUnprovenBlocks += 1;

        emit BlockProposed(nextPendingId++, context);

        finalizeBlocks();
    }

    /// @notice Prove a block is valid with a zero-knowledge proof, a transaction
    ///         merkel proof, and a receipt merkel proof.
    /// @param inputs A list of data input:
    ///
    ///     - inputs[0] is an abi-encoded object with various information regarding
    ///       the block to be proven and the actual proofs.
    ///
    ///     - inputs[1] is the actual anchor transaction in this L2 block. Note that the
    ///       anchor tranaction is always the first transaction in the block.
    ///
    ///     - inputs[2] is he receipt of the anchor transacton.
    function proveBlock(bytes[] calldata inputs) external nonReentrant {
        require(inputs.length == 3, "L1:inputs:size");
        Evidence memory evidence = abi.decode(inputs[0], (Evidence));
        bytes calldata anchorTx = inputs[1];
        bytes calldata anchorReceipt = inputs[2];

        require(evidence.proofs.length == 3, "L1:proof:size");
        _proveBlock(evidence, evidence.context, 0);

        LibTxDecoder.Tx memory _tx = LibTxDecoder.decodeTx(anchorTx);

        require(_tx.txType == 0, "L1:anchor:type");
        require(_tx.destination == resolve("taiko_l2"), "L1:anchor:dest");
        require(
            _tx.gasLimit == LibConstants.TAIKO_ANCHOR_TX_GAS_LIMIT,
            "L1:anchor:gasLimit"
        );
        require(
            Lib_BytesUtils.equal(
                _tx.data,
                bytes.concat(
                    TaikoL2.anchor.selector,
                    bytes32(evidence.context.anchorHeight),
                    evidence.context.anchorHash
                )
            ),
            "L1:anchor:calldata"
        );

        require(
            Lib_MerkleTrie.verifyInclusionProof(
                Lib_RLPWriter.writeUint(0),
                anchorTx,
                evidence.proofs[1],
                evidence.header.transactionsRoot
            ),
            "L1:tx:proof"
        );

        LibReceiptDecoder.Receipt memory receipt = LibReceiptDecoder
            .decodeReceipt(anchorReceipt);

        require(receipt.status == 1, "L1:receipt:status");

        require(
            Lib_MerkleTrie.verifyInclusionProof(
                Lib_RLPWriter.writeUint(0),
                anchorReceipt,
                evidence.proofs[2],
                evidence.header.receiptsRoot
            ),
            "L1:receipt:proof"
        );

        finalizeBlocks();
    }

    /// @notice Prove a block is invalid with a zero-knowledge proof and
    ///         a receipt merkel proof
    /// @param inputs A list of data input:
    ///
    ///     - inputs[0] An Evidence object with various information regarding
    ///       the block to be proven and the actual proofs.
    ///
    ///     - inputs[1] The target block to be proven invalid.
    ///
    ///     - inputs[2] The receipt for the `invalidBlock` transaction
    ///       on L2. Note that the `invalidBlock` transaction is supported to be the
    ///       only transaction in the L2 block.
    function proveBlockInvalid(bytes[] calldata inputs) external nonReentrant {
        require(inputs.length == 3, "L1:inputs:size");
        Evidence memory evidence = abi.decode(inputs[0], (Evidence));
        BlockContext memory target = abi.decode(inputs[1], (BlockContext));
        bytes calldata invalidateBlockReceipt = inputs[2];

        require(evidence.proofs.length == 2, "L1:proof:size");
        _proveBlock(
            evidence,
            target,
            LibConstants.TAIKO_INVALID_BLOCK_DEADEND_HASH
        );

        LibReceiptDecoder.Receipt memory receipt = LibReceiptDecoder
            .decodeReceipt(invalidateBlockReceipt);

        require(receipt.status == 1, "L1:receipt:status");
        require(receipt.logs.length == 1, "L1:receipt:logsize");

        LibReceiptDecoder.Log memory log = receipt.logs[0];

        require(log.contractAddress == resolve("taiko_l2"), "L1:receipt:addr");
        require(log.data.length == 0, "L1:receipt:data");
        require(
            log.topics.length == 2 &&
                log.topics[0] == LibConstants.TAIKO_INVALIDATE_BLOCK_EVENT &&
                log.topics[1] == target.txListHash,
            "L1:receipt:topics"
        );

        require(
            Lib_MerkleTrie.verifyInclusionProof(
                Lib_RLPWriter.writeUint(0),
                invalidateBlockReceipt,
                evidence.proofs[1],
                evidence.header.receiptsRoot
            ),
            "L1:receipt:proof"
        );

        finalizeBlocks();
    }

    /**********************
     * Public Functions   *
     **********************/

    function finalizeBlocks() public {
        uint64 id = lastFinalizedId + 1;
        uint256 processed = 0;

        while (
            id < nextPendingId &&
            processed <= LibConstants.TAIKO_MAX_FINALIZATION_PER_TX
        ) {
            bytes32 lastFinalizedHash = finalizedBlocks[lastFinalizedHeight];
            ForkChoice storage fc = forkChoices[id][lastFinalizedHash];

            if (fc.blockHash == LibConstants.TAIKO_INVALID_BLOCK_DEADEND_HASH) {
                _finalizeBlock(id, fc);
            } else if (fc.blockHash != 0) {
                finalizedBlocks[++lastFinalizedHeight] = fc.blockHash;
                _finalizeBlock(id, fc);
            } else {
                break;
            }

            lastFinalizedId += 1;
            id += 1;
            processed += 1;
        }
    }

    function isCommitValid(bytes32 hash) public view returns (bool) {
        return
            hash != 0 &&
            commits[hash] != 0 &&
            block.number >=
            commits[hash] + LibConstants.TAIKO_COMMIT_DELAY_CONFIRMATIONS;
    }

    function validateContext(BlockContext memory context) public pure {
        require(
            context.id == 0 &&
                context.anchorHeight == 0 &&
                context.anchorHash == 0 &&
                context.mixHash == 0 &&
                context.proposedAt == 0 &&
                context.beneficiary != address(0) &&
                context.txListHash != 0,
            "L1:placeholder"
        );

        require(
            context.gasLimit <= LibConstants.TAIKO_BLOCK_MAX_GAS_LIMIT,
            "L1:gasLimit"
        );
        require(context.extraData.length <= 32, "L1:extraData");
    }

    function calculateCommitHash(address beneficiary, bytes32 txListHash)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(beneficiary, txListHash));
    }

    /**********************
     * Private Functions  *
     **********************/

    function _proveBlock(
        Evidence memory evidence,
        BlockContext memory target,
        bytes32 blockHashOverride
    ) private {
        require(evidence.context.id == target.id, "L1:height");
        require(evidence.prover != address(0), "L1:prover");

        _checkContextPending(target);
        _validateHeaderForContext(evidence.header, evidence.context);

        bytes32 blockHash = evidence.header.hashBlockHeader(
            evidence.parentHash
        );

        LibZKP.verify(
            ConfigManager(resolve("config_manager")).getValue(
                LibConstants.TAIKO_ZKP_VKEY
            ),
            evidence.proofs[0],
            blockHash,
            evidence.prover,
            evidence.context.txListHash
        );

        _markBlockProven(
            evidence.prover,
            evidence.context,
            evidence.parentHash,
            blockHashOverride == 0 ? blockHash : blockHashOverride
        );
    }

    function _markBlockProven(
        address prover,
        BlockContext memory context,
        bytes32 parentHash,
        bytes32 blockHash
    ) private {
        ForkChoice storage fc = forkChoices[context.id][parentHash];

        if (fc.blockHash == 0) {
            fc.blockHash = blockHash;
            fc.proposedAt = context.proposedAt;
            fc.provenAt = uint64(block.timestamp);
        } else {
            require(
                fc.blockHash == blockHash &&
                    fc.proposedAt == context.proposedAt,
                "L1:proof:conflict"
            );
            require(
                fc.provers.length <
                    LibConstants.TAIKO_MAX_PROOFS_PER_FORK_CHOICE,
                "L1:proof:tooMany"
            );

            // No uncle proof can take more than 1.5x time the first proof did.
            uint256 delay = fc.provenAt - fc.proposedAt;
            uint256 deadline = fc.provenAt + delay / 2;
            require(block.timestamp <= deadline, "L1:tooLate");

            for (uint256 i = 0; i < fc.provers.length; i++) {
                require(fc.provers[i] != prover, "L1:prover:dup");
            }
        }

        fc.provers.push(prover);

        PendingBlock storage blk = _getPendingBlock(context.id);
        if (blk.everProven != uint8(EverProven.YES)) {
            blk.everProven = uint8(EverProven.YES);
            numUnprovenBlocks -= 1;
        }

        emit BlockProven(
            context.id,
            parentHash,
            blockHash,
            fc.proposedAt,
            fc.provenAt,
            prover
        );
    }

    function _finalizeBlock(
        uint64 id,
        ForkChoice storage /*fc*/
    ) private {
        // IProtoBroker(resolve("proto_broker")).payProvers(
        //     id,
        //     fc.provenAt,
        //     fc.proposedAt,
        //     _getPendingBlock(id).proposerFee,
        //     fc.provers
        // );

        emit BlockFinalized(
            id,
            lastFinalizedHeight,
            finalizedBlocks[lastFinalizedHeight]
        );
    }

    function _savePendingBlock(uint256 id, PendingBlock memory blk) private {
        pendingBlocks[id % LibConstants.TAIKO_MAX_PENDING_BLOCKS] = blk;
    }

    function _getPendingBlock(uint256 id)
        private
        view
        returns (PendingBlock storage)
    {
        return pendingBlocks[id % LibConstants.TAIKO_MAX_PENDING_BLOCKS];
    }

    function _checkContextPending(BlockContext memory context) private view {
        require(
            context.id > lastFinalizedId && context.id < nextPendingId,
            "L1:ctx:id"
        );
        require(
            _getPendingBlock(context.id).contextHash == _hashContext(context),
            "L1:contextHash"
        );
    }

    function _validateHeaderForContext(
        BlockHeader memory header,
        BlockContext memory context
    ) private pure {
        require(
            header.beneficiary == context.beneficiary &&
                header.gasLimit == context.gasLimit &&
                header.timestamp == context.proposedAt &&
                header.extraData.length == context.extraData.length &&
                keccak256(header.extraData) == keccak256(context.extraData) &&
                header.mixHash == context.mixHash,
            "L1:ctx:headerMismatch"
        );
    }

    function _hashContext(BlockContext memory context)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(context));
    }
}
