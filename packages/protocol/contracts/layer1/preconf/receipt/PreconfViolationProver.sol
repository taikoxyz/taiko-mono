// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "src/layer1/based/ITaikoL1.sol";
import "src/shared/libs/LibBlockHeader.sol";
import "./IPreconfViolationProver.sol";

/// @title PreconfViolationProver
/// @custom:security-contact security@taiko.xyz
contract PreconfViolationProver is IPreconfViolationProver {
    using SignatureChecker for address;

    struct TransactionPreconfReceipt {
        bytes32 txHash;
        uint256 chainId;
        uint256 blockId;
        uint256 position;
        bool isNonRevertGuaranteed;
        address preconfer;
        bytes signature;
    }

    ITaikoL1 public immutable taikoL1;

    error INVALID_PRECONFER();
    error INVALID_RECEIPT();
    error ChainIdMismatch();
    error BlockMetadataMismatch();
    error BlockHashMismatch();
    error BlockNotVerified();
    error TxIncluded();
    error Failed();
    error NoTransactionReceiptProof();

    /// @notice Validates the integrity and authenticity of a receipt.
    /// @param _receipt The serialized receipt data to validate.
    /// @return isValid_ Returns `true` if the receipt is valid, otherwise `false`.
    function isReceiptValid(bytes calldata _receipt) external view returns (bool isValid_) {
        (, isValid_) = _isReceiptValid(_receipt);
    }

    function getHashToSign(TransactionPreconfReceipt memory _receipt)
        public
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                "TAIKO_PRECONFIRMATION",
                _receipt.txHash,
                _receipt.chainId,
                _receipt.blockId,
                _receipt.position,
                _receipt.isNonRevertGuaranteed,
                _receipt.preconfer
            )
        );
    }

    /// @inheritdoc IPreconfViolationProver
    function provePreconfViolation(
        bytes calldata _receipt,
        bytes calldata _proof
    )
        external
        view
        returns (address)
    {
        (TransactionPreconfReceipt memory receipt, bool isValid) = _isReceiptValid(_receipt);
        require(isValid, INVALID_RECEIPT());
        return _proveOnChainNatively(receipt, _proof);
    }


    function _isReceiptValid(bytes calldata _receipt)
        private
        view
        returns (TransactionPreconfReceipt memory receipt_, bool isValid_)
    {
        receipt_ = abi.decode(_receipt, (TransactionPreconfReceipt));
        isValid_ = receipt_.txHash != 0 && receipt_.chainId != 0 && receipt_.blockId != 0
            && receipt_.position != 0 && receipt_.preconfer != address(0)
            && receipt_.signature.length != 0
            && receipt_.preconfer.isValidSignatureNow(getHashToSign(receipt_), receipt_.signature);
    }

    // TODO: implement merklize().
    function _proveOnChainNatively(
        TransactionPreconfReceipt memory _receipt,
        bytes calldata _proof
    )
        private
        view
        returns (address preconfer_)
    {
        require(_receipt.isNonRevertGuaranteed == false, "NOT SUPPORTED");

        // Verify chainId
        require(taikoL1.getConfig().chainId == _receipt.chainId, ChainIdMismatch());

        (TaikoData.BlockMetadataV2 memory meta, bytes memory extraBytes) =
            abi.decode(_proof, (TaikoData.BlockMetadataV2, bytes));

        // Get the block data for the given block ID.
        // Note that this function may revert as only a few days of transactions are available in
        // Taiko BCR protocol's ring buffer.
        TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);

        // Verify the block has been verified.
        require(blk.verifiedTransitionId != 0, BlockNotVerified());
        require(blk.metaHash == keccak256(abi.encode(meta)), BlockMetadataMismatch());

        // If the perconfer did not propose the block, the proving is done.
        if (_receipt.preconfer != meta.proposer) {
            return _receipt.preconfer;
        }

        // Retrieve the block's block hash to verify the provided block header is correct.
        TaikoData.TransitionState memory tran =
            taikoL1.getTransition(meta.id, blk.verifiedTransitionId);

        (BlockHeader memory blockHeader, bytes32[] memory transactionHashes, bytes memory txReceiptProof) =
            abi.decode(extraBytes, (BlockHeader, bytes32[], bytes));

        require(LibBlockHeader.hashBlockHeader(blockHeader) == tran.blockHash, BlockHashMismatch());

        // This function verifies that the provided list of transaction hashes matches the
        // transactions root in the block header.
        // Note: The data cost for _transactionHashes can be very high with this implementation.
        // Consider optimizing this function to reduce data costs.
        // require(
        //     _blockHeader.transactionsRoot == _transactionHashes.merklize(), TxRootHashMismatch()
        // );

        if (
            _receipt.position >= transactionHashes.length
                || transactionHashes[_receipt.position] != _receipt.txHash
        ) return _receipt.preconfer;


        if (_receipt.isNonRevertGuaranteed) {
            require(txReceiptProof.length !=0, NoTransactionReceiptProof());
        }

        revert Failed();
    }
}
