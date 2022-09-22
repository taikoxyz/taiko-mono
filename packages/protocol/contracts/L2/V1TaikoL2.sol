// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../common/AddressResolver.sol";
import "../common/IHeaderSync.sol";
import "../libs/LibInvalidTxList.sol";
import "../libs/LibConstants.sol";
import "../libs/LibTxDecoder.sol";

/// @author dantaik <dan@taiko.xyz>
contract V1TaikoL2 is AddressResolver, ReentrancyGuard, IHeaderSync {
    using LibTxDecoder for bytes;

    /**********************
     * State Variables    *
     **********************/

     mapping(uint256 => bytes32) public blockhashes;
    mapping(uint256 => bytes32) private l1Hashes;
    bytes32 public publicInputHash;

    uint256[47] private __gap;

    /**********************
     * Events             *
     **********************/

    event BlockInvalidated(bytes32 indexed txListHash);
    event EtherCredited(address recipient, uint256 amount);
    event EtherReturned(address recipient, uint256 amount);

    /**********************
     * Constructor         *
     **********************/

    // This constructor is only used for testing the contract.
    constructor(address _addressManager, uint256 _chainId) initializer {
        AddressResolver._init(_addressManager);
        require(block.chainid == _chainId, "L2:chainId");

        bytes32[255] memory ancestors;
        uint256 number = block.number;
        for (uint256 i = 0; i < 255 && number >= i + 2; i++) {
            ancestors[i] = blockhash(number - i - 2);
        }
        publicInputHash = _hashPublicInputHash(
            block.chainid,
            number,
            0,
            ancestors
        );
    }

    /**********************
     * External Functions *
     **********************/

    receive() external payable onlyFromNamed("eth_depositor") {
        emit EtherReturned(msg.sender, msg.value);
    }

    fallback() external payable {
        revert("L2:prohibited");
    }

    function creditEther(address recipient, uint256 amount)
        external
        nonReentrant
        onlyFromNamed("eth_depositor")
    {
        require(
            recipient != address(0) && recipient != address(this),
            "L2:recipient"
        );
        payable(recipient).transfer(amount);
        emit EtherCredited(recipient, amount);
    }

    /// @notice Persist the latest L1 block height and hash to L2 for cross-layer
    ///         bridging. This function will also check certain block-level global
    ///         variables because they are not part of the Trie structure.
    ///
    ///         Note taht this transaciton shall be the first transaction in every L2 block.
    ///
    /// @param l1Height The latest L1 block height when this block was proposed.
    /// @param l1Hash The latest L1 block hash when this block was proposed.
    function anchor(uint256 l1Height, bytes32 l1Hash) external {
        _checkPublicInputs();

        l1Hashes[l1Height] = l1Hash;
        emit HeaderSynced(block.number, l1Height, l1Hash);
    }

    /// @notice Invalidate a L2 block by verifying its txList is not intrinsically valid.
    /// @param txList The L2 block's txList.
    /// @param hint A hint for this method to invalidate the txList.
    /// @param txIdx If the hint is for a specific transaction in txList, txIdx specifies
    ///        which transaction to check.
    function invalidateBlock(
        bytes calldata txList,
        LibInvalidTxList.Reason hint,
        uint256 txIdx
    ) external {
        LibInvalidTxList.Reason reason = LibInvalidTxList.isTxListInvalid(
            txList,
            hint,
            txIdx
        );
        require(reason != LibInvalidTxList.Reason.OK, "L2:reason");

        _checkPublicInputs();

        emit BlockInvalidated(txList.hashTxList());
    }

    /**********************
     * Public Functions   *
     **********************/

    function getSyncedHeader(uint256 number)
        public
        view
        override
        returns (bytes32)
    {
        return l1Hashes[number];
    }

    /**********************
     * Private Functions  *
     **********************/

    function getConstants()
        public
        pure
        returns (
            uint256, // TAIKO_CHAIN_ID
            uint256, // TAIKO_MAX_PENDING_BLOCKS
            uint256, // TAIKO_MAX_FINALIZATIONS_PER_TX
            uint256, // TAIKO_COMMIT_DELAY_CONFIRMATIONS
            uint256, // TAIKO_MAX_PROOFS_PER_FORK_CHOICE
            uint256, // TAIKO_BLOCK_MAX_GAS_LIMIT
            uint256, // TAIKO_BLOCK_MAX_TXS
            bytes32, // TAIKO_BLOCK_DEADEND_HASH
            uint256, // TAIKO_TXLIST_MAX_BYTES
            uint256, // TAIKO_TX_MIN_GAS_LIMIT
            uint256, // V1_ANCHOR_TX_GAS_LIMIT
            bytes4, // V1_ANCHOR_TX_SELECTOR
            bytes32 // V1_INVALIDATE_BLOCK_LOG_TOPIC
        )
    {
        return (
            LibConstants.TAIKO_CHAIN_ID,
            LibConstants.TAIKO_MAX_PENDING_BLOCKS,
            LibConstants.TAIKO_MAX_FINALIZATIONS_PER_TX,
            LibConstants.TAIKO_COMMIT_DELAY_CONFIRMATIONS,
            LibConstants.TAIKO_MAX_PROOFS_PER_FORK_CHOICE,
            LibConstants.TAIKO_BLOCK_MAX_GAS_LIMIT,
            LibConstants.TAIKO_BLOCK_MAX_TXS,
            LibConstants.TAIKO_BLOCK_DEADEND_HASH,
            LibConstants.TAIKO_TXLIST_MAX_BYTES,
            LibConstants.TAIKO_TX_MIN_GAS_LIMIT,
            LibConstants.V1_ANCHOR_TX_GAS_LIMIT,
            LibConstants.V1_ANCHOR_TX_SELECTOR,
            LibConstants.V1_INVALIDATE_BLOCK_LOG_TOPIC
        );
    }

    function _checkPublicInputs() private {
        // Check the latest 256 block hashes (exlcuding the parent hash).
        bytes32[255] memory ancestors;
        uint256 number = block.number;
        uint256 chainId = block.chainid;

        for (uint256 i = 2; i <= 256 && number >= i; i++) {
            ancestors[(number - i) % 255] = blockhash(number - i);
        }

        uint parentHeight = number - 1;
        bytes32 parentHash = blockhash(parentHeight);

        require(
            publicInputHash ==
                _hashPublicInputHash(chainId, parentHeight, 0, ancestors),
            "L2:publicInputHash"
        );
        
        ancestors[parentHeight % 255] = parentHash;
        publicInputHash = _hashPublicInputHash(chainId, number, 0, ancestors);
        
        blockhashes[parentHeight] = parentHash;
    }

    function _hashPublicInputHash(
        uint256 chainId,
        uint256 number,
        uint256 baseFee,
        bytes32[255] memory ancestors
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(chainId, number, baseFee, ancestors));
    }
}
