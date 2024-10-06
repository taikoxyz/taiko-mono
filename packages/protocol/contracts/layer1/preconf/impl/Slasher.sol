// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../../../shared/common/EssentialContract.sol";
import "../../based/ITaikoL1.sol";
import "../../based/TaikoData.sol";
import "../libs/LibNames.sol";
import "../iface/IPreconfServiceManager.sol";
import "../iface/ISlasher.sol";

/// @title Slasher.sol
/// @custom:security-contact security@taiko.xyz
contract Slasher is ISlasher, EssentialContract {
    struct Receipt {
        uint64 blockId;
        uint64 chainId;
        uint32 position;
        bytes32 txHash;
    }

    // TODO: complete the definition
    struct BlockHeader {
        bytes32 parentHash;
        bytes32 stateRoot;
        bytes32 transactionsHash;
        uint64 timestamp;
        uint64 difficulty;
        uint64 nonce;
    }

    uint256[50] private __gap;
    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _rollupAddressManager The address of the {AddressManager} contract.

    function init(address _owner, address _rollupAddressManager) external initializer {
        __Essential_init(_owner, _rollupAddressManager);
    }

    // @notice This function verifies that one of the following is true then slash the preconfirer
    // 1. The actual transaction hash at position `_receipt.position` in the given block's
    // transactios trie does not match the transaction hash in the receipt
    // 2. The block contains less transations than `_receipt.position` -- this is current not
    // possible with existing data.
    // 3. The transtion at position `_receipt.position` did not revert.
    function slashIncorrectPreconfirmation(
        TaikoData.BlockMetadataV2 calldata _meta,
        Receipt calldata _receipt,
        bytes calldata _receiptSignature,
        BlockHeader calldata _blockHeader,
        bytes32[] calldata _transactionHashes
    )
        external
        nonReentrant
    {
        // TODO: implement the logic
        IPreconfServiceManager preconfServiceManager =
            IPreconfServiceManager(resolve(LibNames.B_PRECONF_SERVICE_MANAGER, false));
        preconfServiceManager.slashOperator(_meta.proposer);
    }

    function hashReceipt(Receipt calldata _receipt) public pure returns (bytes32) {
        return keccak256(abi.encode("TAIKO_PRECONFIRMATION_RECEIPT", _receipt));
    }
}
