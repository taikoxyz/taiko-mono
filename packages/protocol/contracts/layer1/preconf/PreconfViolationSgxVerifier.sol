// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "src/layer1/based/ITaikoL1.sol";
import "src/layer1/verifiers/SgxVerifierBase.sol";
import "./IPreconfViolationVerifier.sol";

/// @title PreconfViolationSgxVerifier
/// @custom:security-contact security@taiko.xyz
contract PreconfViolationSgxVerifier is SgxVerifierBase, IPreconfViolationVerifier {
    using SignatureChecker for address;

    struct TransactionPreconfReceipt {
        bytes32 txHash;
        uint64 chainId;
        uint64 blockId;
        uint24 position;
        bool isNonRevertGuaranteed;
        address preconfer;
        bytes signature;
    }

    uint256[50] private __gap;

    error BLOCK_ID_MISMATCH();
    error BLOCK_METADATA_MISMATCH();
    error BLOCK_NOT_VERIFIED();
    error CHAIN_ID_MISMATCH();
    error INVALID_RECEIPT();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _preconfAddressManager The address of the {AddressManager} contract.
    function init(address _owner, address _preconfAddressManager) external initializer {
        __Essential_init(_owner, _preconfAddressManager);
    }

    /// @inheritdoc IPreconfViolationVerifier
    function verifyPreconfViolation(
        bytes calldata _receipt,
        bytes calldata _proof
    )
        external
        returns (address)
    {
        // We verify the receipt's signature on-chain to support contract-based preconfers.
        (TransactionPreconfReceipt memory receipt, bool isValid) = _isReceiptValid(_receipt);
        require(isValid, INVALID_RECEIPT());

        require(taikoChainId() == receipt.chainId, BLOCK_ID_MISMATCH());

        _proveTransactionInclusionWithSGX(receipt, _proof);

        return receipt.preconfer;
    }

    /// @inheritdoc IPreconfViolationVerifier
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

    function taikoChainId() internal view virtual returns (uint64) {
        return ITaikoL1(resolve(LibStrings.B_TAIKO, false)).getConfig().chainId;
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

    // @dev We do not verify if the block is actually proposed by the perconf, as long as the
    // inclusion/execution of the transaction can be verified.
    function _proveTransactionInclusionWithSGX(
        TransactionPreconfReceipt memory _receipt,
        bytes calldata _proof
    )
        private
    {
        (uint32 instanceId, address newInstance, bytes memory sgxSignature) =
            abi.decode(_proof, (uint32, address, bytes));

        // Get the block data for the given block ID.
        // Note that this function may revert as only a few days of transactions are available in
        // Taiko BCR protocol's ring buffer.
        ITaikoL1 taikoL1 = ITaikoL1(resolve(LibStrings.B_TAIKO, false));
        TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(_receipt.blockId);

        // Verify the block has been verified.
        require(blk.verifiedTransitionId != 0, BLOCK_NOT_VERIFIED());

        // Retrieve the block's block hash to verify the provided block header is correct.
        bytes32 blockHash =
            taikoL1.getTransition(_receipt.blockId, blk.verifiedTransitionId).blockHash;

        address oldInstance = ECDSA.recover(hashPublicInputs(_receipt, blockHash), sgxSignature);

        if (!_isInstanceValid(instanceId, oldInstance)) revert SGX_INVALID_INSTANCE();

        if (newInstance != oldInstance && newInstance != address(0)) {
            _replaceInstance(instanceId, oldInstance, newInstance);
        }
    }

    function hashPublicInputs(
        TransactionPreconfReceipt memory _receipt,
        bytes32 _blockHash
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_receipt, _blockHash));
    }
}
