// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../../shared/common/EssentialContract.sol";
import "../based/ITaikoL1.sol";
import "../based/TaikoData.sol";
import "./LibNames.sol";
import "./ILookahead.sol";
import "./IPreconfServiceManager.sol";
import "./IPreconfTaskManager.sol";

/// @title PreconfTaskManager.sol
/// @custom:security-contact security@taiko.xyz
contract PreconfTaskManager is IPreconfTaskManager, EssentialContract {
    using ECDSA for bytes32;

    struct Receipt {
        uint64 blockId;
        uint64 chainId;
        uint32 position;
        bytes32 txHash;
    }

    struct BlockHeader {
        // TODO
        bytes32 parentHash;
        bytes32 stateRoot;
        bytes32 transactionsHash;
        uint64 timestamp;
        uint64 difficulty;
        uint64 nonce;
    }

    error ChainIdMismatch();
    error BlockHashMismatch();
    error BlockMetadataMismatch();
    error BlockNotVerified();
    error InvalidSignature();
    error PositionOutOfBounds();
    error SenderNotCurrentPreconfer();
    error TxHashMismatch();
    error TxRootHashMismatch();

    modifier onlyFromCurrentPreconfer() {
        require(_lookahead().isCurrentPreconfer(msg.sender), SenderNotCurrentPreconfer());
        _;
    }

    /// @notice Proposes a Taiko L2 block (version 2)
    /// @param _params Block parameters, an encoded BlockParamsV2 object.
    /// @param _txList txList data if calldata is used for DA.
    /// @return meta_ The metadata of the proposed L2 block.
    function newBlockProposal(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        onlyFromCurrentPreconfer
        nonReentrant
        returns (TaikoData.BlockMetadataV2 memory)
    {
        return _taikoL1().proposeBlockV2(_params, _txList);
    }

    /// @notice Proposes multiple Taiko L2 blocks (version 2)
    /// @param _paramsArr A list of encoded BlockParamsV2 objects.
    /// @param _txListArr A list of txList.
    /// @return metaArr_ The metadata objects of the proposed L2 blocks.
    function newBlockProposals(
        bytes[] calldata _paramsArr,
        bytes[] calldata _txListArr
    )
        external
        onlyFromCurrentPreconfer
        nonReentrant
        returns (TaikoData.BlockMetadataV2[] memory)
    {
        return _taikoL1().proposeBlocksV2(_paramsArr, _txListArr);
    }

    function proveIncorrectPreconfirmation(
        TaikoData.BlockMetadataV2 calldata _meta,
        Receipt calldata _receipt,
        bytes calldata _receiptSignature,
        BlockHeader calldata _blockHeader,
        bytes32[] calldata _transactionHashes
    )
        external
        onlyFromCurrentPreconfer
        nonReentrant
    {
        require(_transactionHashes.length > _receipt.position, PositionOutOfBounds());
        require(_transactionHashes[_receipt.position] == _receipt.txHash, TxHashMismatch());
        require(_blockHeader.transactionsHash == merklize(_transactionHashes), TxRootHashMismatch());

        ITaikoL1 taiko = _taikoL1();
        require(taiko.getConfig().chainId == _receipt.chainId, ChainIdMismatch());

        TaikoData.BlockV2 memory blk = taiko.getBlockV2(_meta.id);
        require(blk.verifiedTransitionId != 0, BlockNotVerified());
        require(blk.metaHash == keccak256(abi.encode(_meta)), BlockMetadataMismatch());
        require(
            hashReceipt(_receipt).recover(_receiptSignature) == _meta.proposer, InvalidSignature()
        );

        TaikoData.TransitionState memory tran =
            taiko.getTransition(_meta.id, blk.verifiedTransitionId);
        require(hashBlockHeader(_blockHeader) == tran.blockHash, BlockHashMismatch());

        // Slash The preconfirer
        _preconfServiceManager().slashOperator(_meta.proposer);
    }

    function hashReceipt(Receipt calldata _receipt) public pure returns (bytes32) {
        return keccak256(abi.encode("TAIKO_PRECONFIRMATION_RECEIPT", _receipt));
    }

    function hashBlockHeader(BlockHeader calldata _blockHeader) public pure returns (bytes32) {
        // TODO
    }

    function merklize(bytes32[] calldata _hashes) public pure returns (bytes32) {
        // TODO
    }

    function _taikoL1() private view returns (ITaikoL1) {
        return ITaikoL1(resolve(LibNames.B_TAIKO, false));
    }

    function _lookahead() private view returns (ILookahead) {
        return ILookahead(resolve(LibNames.B_LOOKAHEAD, false));
    }

    function _preconfServiceManager() private view returns (IPreconfServiceManager) {
        return IPreconfServiceManager(resolve(LibNames.B_PRECONF_SERVICE_MANAGER, false));
    }
}
