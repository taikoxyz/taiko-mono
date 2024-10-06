// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../libs/LibBlockHeader.sol";
import "./PreconfTaskManagerBase.sol";

/// @title PreconfTaskManager
/// @custom:security-contact security@taiko.xyz
contract PreconfTaskManager is PreconfTaskManagerBase {
    using ECDSA for bytes32;

    struct Receipt {
        uint64 blockId;
        uint64 chainId;
        uint32 position;
        bool isExecutionPreconf;
        bytes32 txHash;
        bytes signature;
    }

    event IncorrectPreconfirmationProved(
        address indexed preconfer, uint64 indexed blockId, address indexed operator
    );

    error ChainIdMismatch();
    error BlockHashMismatch();
    error BlockMetadataMismatch();
    error BlockNotVerified();
    error ExecutionPreconfNotSupported();
    error InvalidSignature();
    error TxIncluded();

    uint256[50] private __gap;

    /// @notice Initializes the contract.
    function init(address _owner, address _rollupAddressManager) external initializer {
        __Essential_init(_owner, _rollupAddressManager);
    }

    function proveIncorrectPreconfirmation(
        TaikoData.BlockMetadataV2 calldata _meta,
        Receipt calldata _receipt,
        BlockHeader calldata _blockHeader,
        bytes32[] calldata _transactionHashes
    )
        external
        nonReentrant
    {
        // For now only tx-inclusion preconfirmation are supported
        require(!_receipt.isExecutionPreconf, ExecutionPreconfNotSupported());

        // This function verifies that the provided list of transaction hashes matches the
        // transactions root in the block header.
        // Note: The data cost for _transactionHashes can be very high with this implementation.
        // Consider optimizing this function to reduce data costs.
        // require(
        //     _blockHeader.transactionsRoot == _transactionHashes.merklize(), TxRootHashMismatch()
        // );

        ITaikoL1 taiko = ITaikoL1(resolve(LibNames.B_TAIKO, false));

        // Verify chainId
        require(taiko.getConfig().chainId == _receipt.chainId, ChainIdMismatch());

        // Get the block data for the given block ID.
        // Note that this function may revert as only a few days of transactions are available in
        // Taiko BCR protocol's ring buffer.
        TaikoData.BlockV2 memory blk = taiko.getBlockV2(_meta.id);

        // Verify the block has been verified.
        require(blk.verifiedTransitionId != 0, BlockNotVerified());
        require(blk.metaHash == keccak256(abi.encode(_meta)), BlockMetadataMismatch());

        // Verify the preconfirmation is signed by the block's proposer.
        require(recoverPreconfer(_receipt) == _meta.proposer, InvalidSignature());

        // Retrieve the block's block hash to verify the provided block header is correct.
        TaikoData.TransitionState memory tran =
            taiko.getTransition(_meta.id, blk.verifiedTransitionId);
        require(LibBlockHeader.hashBlockHeader(_blockHeader) == tran.blockHash, BlockHashMismatch());

        // Verify the transaction is not already included in the block.
        require(
            _receipt.position >= _transactionHashes.length
                || _transactionHashes[_receipt.position] != _receipt.txHash,
            TxIncluded()
        );

        emit IncorrectPreconfirmationProved(_meta.proposer, _meta.id, msg.sender);

        // Slash the preconfer
        IPreconfServiceManager psm =
            IPreconfServiceManager(resolve(LibNames.B_PRECONF_SERVICE_MANAGER, false));
        psm.slashOperator(_meta.proposer);
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
}
