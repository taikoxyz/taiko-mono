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
import "../libs/LibInvalidTxList.sol";
import "../libs/LibConstants.sol";
import "../libs/LibTxDecoder.sol";

/// @author dantaik <dan@taiko.xyz>
contract V1TaikoL2 is AddressResolver, ReentrancyGuard {
    using LibTxDecoder for bytes;

    /**********************
     * State Variables    *
     **********************/

    mapping(uint256 => bytes32) public blockHashes;
    mapping(uint256 => bytes32) private l1Hashes;
    uint256 public chainId;
    uint256 public latestL1Height;

    uint256[46] private __gap;

    /**********************
     * Events             *
     **********************/

    event HeaderExchanged(
        uint256 indexed height,
        uint256 indexed srcHeight,
        bytes32 srcHash
    );

    event BlockInvalidated(bytes32 indexed txListHash);
    event EtherCredited(address recipient, uint256 amount);
    event EtherReturned(address recipient, uint256 amount);

    /**********************
     * Modifiers          *
     **********************/

    modifier onlyWhenNotAnchored() {
        require(latestL1Height + 1 == block.number, "L2:anchored");
        latestL1Height = block.number;
        _;
    }

    /**********************
     * Constructor         *
     **********************/

    constructor(address _addressManager, uint256 _chainId) initializer {
        AddressResolver._init(_addressManager);

        require(block.chainid == _chainId, "L2:chainId");
        chainId = _chainId;
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
    function anchor(uint256 l1Height, bytes32 l1Hash)
        external
        onlyWhenNotAnchored
    {
        l1Hashes[l1Height] = l1Hash;
        _checkGlobalVariables();

        emit HeaderExchanged(block.number, l1Height, l1Hash);
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

        _checkGlobalVariables();

        emit BlockInvalidated(txList.hashTxList());
    }

    /**********************
     * Public Functions   *
     **********************/
    function getL1BlockHash(uint256 number) public view returns (bytes32) {
        require(number <= latestL1Height, "L2:number");
        return l1Hashes[number];
    }

    /**********************
     * Private Functions  *
     **********************/

    function _checkGlobalVariables() private {
        // Check chainid
        require(block.chainid == chainId, "L2:chainId");

        // It turns out that if  EIP1559 is disabled, the basefee opcode
        // won't be available.
        // require(block.basefee == 0, "L2:baseFee");

        // Check the latest 255 block hashes match the storage version.
        for (uint256 i = 2; i <= 256 && block.number >= i; i++) {
            uint256 j = block.number - i;
            require(blockHashes[j] == blockhash(j), "L2:ancestorHash");
        }

        // Store parent hash into storage tree.
        blockHashes[block.number - 1] = blockhash(block.number - 1);
    }
}
