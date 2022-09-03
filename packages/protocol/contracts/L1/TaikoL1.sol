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
import "../libs/LibTaikoConstants.sol";
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
    using SafeCastUpgradeable for uint256;
    using LibBlockHeader for BlockHeader;
    using LibTxDecoder for bytes;

    bytes32 private constant BLOCK_INVALIDATED_EVENT_SELECTOR =
        keccak256("BlockInvalidated(bytes32)");

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
     * Constants          *
     **********************/

    uint256 public constant MAX_ANCHOR_HEIGHT_DIFF = 128;
    uint256 public constant MAX_PENDING_BLOCKS = 2048;
    uint256 public constant MAX_THROW_AWAY_PARENT_DIFF = 1024;
    uint256 public constant MAX_FINALIZATION_PER_TX = 5;
    uint256 public constant PROPOSING_DELAY_MIN = 1 minutes;
    uint256 public constant PROPOSING_DELAY_MAX = 30 minutes;
    uint256 public constant MAX_PROOFS_PER_FORK_CHOICE = 5;
    bytes32 public constant INVALID_BLOCK_DEADEND_HASH = bytes32(uint256(1));
    string public constant ZKP_VKEY = "TAIKO_ZKP_VKEY";

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

    event BlockCommitted(bytes32 hash, uint256 expireAt);

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
     * Modifiers          *
     **********************/

    modifier whenBlockIsCommitted(BlockContext memory context) {
        validateContext(context);

        bytes32 hash = keccak256(
            abi.encodePacked(context.beneficiary, context.txListHash)
        );
        require(isCommitValid(hash), "L1:commit");
        delete commits[hash];
        _;
        finalizeBlocks();
    }

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

    function commitBlock(bytes32 hash) external {
        require(hash != 0, "L1:hash");

        require(
            commits[hash] == 0 ||
                block.timestamp > commits[hash] + PROPOSING_DELAY_MAX,
            "L1:committed"
        );
        commits[hash] = block.timestamp;
        emit BlockCommitted(hash, block.timestamp + PROPOSING_DELAY_MAX);
    }

    /// @notice Propose a Taiko L2 block.
    /// @param context The context that the actual L2 block header must satisfy.
    ///        Note the following fields in the provided context object must
    ///        be zeros, and their actual values will be provisioned by Ethereum.
    ///        - id
    ///        - mixHash
    ///        - proposedAt
    ///        - anchorHeight
    ///        - anchorHash
    /// @param txList A list of transactions in this block, encoded with RLP.
    function proposeBlock(BlockContext memory context, bytes calldata txList)
        external
        payable
        nonReentrant
        whenBlockIsCommitted(context)
    {
        require(
            txList.length > 0 &&
                txList.length <=
                LibTaikoConstants.TAIKO_BLOCK_MAX_TXLIST_BYTES &&
                context.txListHash == txList.hashTxList(),
            "L1:txList"
        );
        require(
            nextPendingId <= lastFinalizedId + MAX_PENDING_BLOCKS,
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
    }

    function proveBlock(
        Evidence calldata evidence,
        bytes calldata anchorTx,
        bytes calldata anchorReceipt
    ) external nonReentrant {
        require(evidence.proofs.length == 3, "L1:proof:size");
        _proveBlock(evidence, evidence.context, 0);

        LibTxDecoder.Tx memory _tx = LibTxDecoder.decodeTx(anchorTx);

        require(_tx.txType == 0, "L1:anchor:type");
        require(_tx.destination == resolve("taiko_l2"), "L1:anchor:dest");
        require(
            _tx.gasLimit == LibTaikoConstants.TAIKO_ANCHOR_TX_GAS_LIMIT,
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

    function proveBlockInvalid(
        Evidence calldata evidence,
        BlockContext calldata target,
        bytes calldata invalidateBlockReceipt
    ) external nonReentrant {
        require(evidence.proofs.length == 2, "L1:proof:size");
        _proveBlock(evidence, target, INVALID_BLOCK_DEADEND_HASH);

        LibReceiptDecoder.Receipt memory receipt = LibReceiptDecoder
            .decodeReceipt(invalidateBlockReceipt);

        require(receipt.status == 1, "L1:receipt:status");
        require(receipt.logs.length == 1, "L1:receipt:logsize");

        LibReceiptDecoder.Log memory log = receipt.logs[0];

        require(log.contractAddress == resolve("taiko_l2"), "L1:receipt:addr");
        require(log.data.length == 0, "L1:receipt:data");
        require(
            log.topics.length == 2 &&
                log.topics[0] == BLOCK_INVALIDATED_EVENT_SELECTOR &&
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

        while (id < nextPendingId && processed <= MAX_FINALIZATION_PER_TX) {
            bytes32 lastFinalizedHash = finalizedBlocks[lastFinalizedHeight];
            ForkChoice storage fc = forkChoices[id][lastFinalizedHash];

            if (fc.blockHash == INVALID_BLOCK_DEADEND_HASH) {
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
            block.timestamp >= commits[hash] + PROPOSING_DELAY_MIN &&
            block.timestamp <= commits[hash] + PROPOSING_DELAY_MAX;
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
            context.gasLimit <= LibTaikoConstants.TAIKO_BLOCK_MAX_GAS_LIMIT,
            "L1:gasLimit"
        );
        require(context.extraData.length <= 32, "L1:extraData too large");
    }

    /**********************
     * Private Functions  *
     **********************/

    function _proveBlock(
        Evidence calldata evidence,
        BlockContext calldata target,
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
            ConfigManager(resolve("config_manager")).getValue(ZKP_VKEY),
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
                "L1:proof:conflicting"
            );
            require(
                fc.provers.length < MAX_PROOFS_PER_FORK_CHOICE,
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
        pendingBlocks[id % MAX_PENDING_BLOCKS] = blk;
    }

    function _getPendingBlock(uint256 id)
        private
        view
        returns (PendingBlock storage)
    {
        return pendingBlocks[id % MAX_PENDING_BLOCKS];
    }

    function _checkContextPending(BlockContext calldata context) private view {
        require(
            context.id > lastFinalizedId && context.id < nextPendingId,
            "L1:ctx:id"
        );
        require(
            _getPendingBlock(context.id).contextHash == _hashContext(context),
            "L1:cxt:mismatch"
        );
    }

    function _validateHeader(BlockHeader calldata header) private pure {
        require(
            header.gasLimit <= LibTaikoConstants.TAIKO_BLOCK_MAX_GAS_LIMIT &&
                header.extraData.length <= 32 &&
                header.difficulty == 0 &&
                header.nonce == 0,
            "L1:header:mismatch"
        );
    }

    function _validateHeaderForContext(
        BlockHeader calldata header,
        BlockContext memory context
    ) private pure {
        require(
            header.beneficiary == context.beneficiary &&
                header.gasLimit == context.gasLimit &&
                header.timestamp == context.proposedAt &&
                header.extraData.length == context.extraData.length &&
                keccak256(header.extraData) == keccak256(context.extraData) &&
                header.mixHash == context.mixHash,
            "L1:ctx:mismatch"
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
