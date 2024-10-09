// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../../../shared/common/EssentialContract.sol";
import "../../based/ITaikoL1.sol";
import "../../based/TaikoData.sol";
import "../iface/IReceiptProver.sol";
import "../libs/LibBlockHeader.sol";
import "../libs/LibNames.sol";

/// @title PreconfTaskManager
/// @custom:security-contact security@taiko.xyz
abstract contract ReceiptProver is IReceiptProver, EssentialContract {
    using ECDSA for bytes32;

    uint256[50] private __gap;

    error BlockHashMismatch();
    error BlockMetadataMismatch();
    error BlockNotVerified();
    error ChainIdMismatch();
    error ExecutionPreconfNotSupported();
    error InvalidProofKind();
    error InvalidReceipt();
    error InvalidSignature();
    error TxIncluded();

    /// @notice Initializes the contract.
    function init(address _owner, address _preconfAddressManager) external initializer {
        __Essential_init(_owner, _preconfAddressManager);
    }

    /// @inheritdoc IReceiptProver
    function proveReceiptViolation(
        Receipt calldata _receipt,
        bytes calldata _proof
    )
        external
        onlyFromNamed(LibNames.B_PRECONF_SERVICE_MANAGER)
        nonReentrant
        returns (address preconfer_)
    {
        uint8 proofType = uint8(_proof[0]);
        if (proofType == 0) {
            preconfer_ = _verifyOnChainNatively(_receipt, _proof[1:]);
        } else if (proofType == 1) {
            preconfer_ = _verifyOnChainWithSGX(_receipt, _proof[1:]);
        } else {
            revert InvalidProofKind();
        }

        emit ReceiptViolationProved(preconfer_, _receipt);
    }

    /// @notice Hashes a receipt into a bytes32 hash to be signed by the preconfer.
    /// @param _receipt The receipt to hash.
    /// @return hash_ The hash of the receipt.
    function hashReceipt(Receipt calldata _receipt) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                "TAIKO_PRECONFIRMATION_RECEIPT",
                _receipt.blockId,
                _receipt.chainId,
                _receipt.position,
                _receipt.isExecutionPreconf,
                _receipt.txHash
            )
        ).toEthSignedMessageHash();
    }

    /// @notice Recovers the preconfer's address from a receipt's signature.
    /// @param _receipt The receipt to recover the preconfer's address from.
    /// @return preconfer_ The preconfer's address.
    function recoverPreconfer(Receipt calldata _receipt) public pure returns (address) {
        return hashReceipt(_receipt).recover(_receipt.signature);
    }

    // TODO: implement merklize().
    function _verifyOnChainNatively(
        Receipt calldata _receipt,
        bytes calldata _proof
    )
        private
        view
        returns (address preconfer_)
    {
        require(_receipt.position != 0, InvalidReceipt());
        // For now only tx-inclusion preconfirmation are supported
        require(!_receipt.isExecutionPreconf, ExecutionPreconfNotSupported());

        ITaikoL1 taiko = ITaikoL1(resolve(LibNames.B_TAIKO, false));

        // Verify chainId
        require(taiko.getConfig().chainId == _receipt.chainId, ChainIdMismatch());

        (
            TaikoData.BlockMetadataV2 memory meta,
            BlockHeader memory blockHeader,
            bytes32[] memory transactionHashes
        ) = abi.decode(_proof, (TaikoData.BlockMetadataV2, BlockHeader, bytes32[]));

        // This function verifies that the provided list of transaction hashes matches the
        // transactions root in the block header.
        // Note: The data cost for _transactionHashes can be very high with this implementation.
        // Consider optimizing this function to reduce data costs.
        // require(
        //     _blockHeader.transactionsRoot == _transactionHashes.merklize(), TxRootHashMismatch()
        // );

        // Get the block data for the given block ID.
        // Note that this function may revert as only a few days of transactions are available in
        // Taiko BCR protocol's ring buffer.
        TaikoData.BlockV2 memory blk = taiko.getBlockV2(meta.id);

        // Verify the block has been verified.
        require(blk.verifiedTransitionId != 0, BlockNotVerified());
        require(blk.metaHash == keccak256(abi.encode(meta)), BlockMetadataMismatch());

        // Verify the preconfirmation is signed by the block's proposer.
        require(recoverPreconfer(_receipt) == meta.proposer, InvalidSignature());

        // Retrieve the block's block hash to verify the provided block header is correct.
        TaikoData.TransitionState memory tran =
            taiko.getTransition(meta.id, blk.verifiedTransitionId);
        require(LibBlockHeader.hashBlockHeader(blockHeader) == tran.blockHash, BlockHashMismatch());

        // Verify the transaction is not included in the block.
        require(
            _receipt.position >= transactionHashes.length
                || transactionHashes[_receipt.position] != _receipt.txHash,
            TxIncluded()
        );

        return meta.proposer;
    }

    function _verifyOnChainWithSGX(
        Receipt calldata _receipt,
        bytes calldata _proof
    )
        private
        view
        notImplemented
        returns (address preconfer_)
    { }
}
