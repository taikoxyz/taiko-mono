// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../libs/LibTaikoConstants.sol";
import "../libs/LibTxListDecoder.sol";
import "../libs/LibMerkleProof.sol";

/// @dev The following rules are used for validating a txList:
///
/// 1. The txList is well-formed RLP, with no additional trailing bytes;
/// 2. The total number of transactions is no more than a given threshold;
/// 3. The sum of all transaction gas limit is no more than a given threshold;
/// 4. Each transaction is well-formed RLP, with no additional trailing bytes (rule#1 in Ethereum yellow paper);
/// 5. Each transaction's signature is valid (rule#2 in Ethereum yellow paper), and;
/// 6. Each transaction's the gas limit is no smaller than the intrinsic gas (rule#5 in Ethereum yellow paper).
///
/// TODO(Roger): work on 5 and 6.
library LibInvalidTxListProver {
    enum Reason {
        NOT_DECODABLE,
        TOO_MANY_TXS,
        BLOCK_GAS_LIMIT_EXCEEDED,
        INVALID_NONCE,
        CODE_DEPLOYED,
        LOWER_ETHER_BALANCE,
        GASLIMIT_TOO_SMALL
    }

    function proveTxListInvalid(
        bytes calldata encoded,
        uint256 txIdx,
        Reason reason,
        LibMerkleProof.Account calldata account,
        bytes calldata mkproof
    ) public view returns (Reason) {
        try LibTxListDecoder.decodeTxList(encoded) returns (
            LibTxListDecoder.TxList memory txList
        ) {
            if (
                txList.items.length > LibTaikoConstants.MAX_TAIKO_BLOCK_NUM_TXS
            ) {
                return Reason.TOO_MANY_TXS;
            }
            if (
                LibTxListDecoder.sumGasLimit(txList) >
                LibTaikoConstants.MAX_TAIKO_BLOCK_GAS_LIMIT
            ) {
                return Reason.BLOCK_GAS_LIMIT_EXCEEDED;
            }

            require(txIdx < txList.items.length, "invalid txIdx");
            LibTxListDecoder.Tx memory _tx = txList.items[txIdx];

            //   LibMerkleProof.verifyAccount(
            //     parentStateRoot
            //     _tx.sender
            //     account,
            //     mkproof
            // );

            if (reason == Reason.INVALID_NONCE) {
                // require(tx.nonce != account.nonce, "nonce indeed valid");
                return Reason.INVALID_NONCE;
            }

            if (reason == Reason.CODE_DEPLOYED) {
                // require(tx.codeHash != account.codeHash, "codeHash indeed valid");
                return Reason.CODE_DEPLOYED;
            }

            if (reason == Reason.LOWER_ETHER_BALANCE) {
                // require(tx.value != account.balance, "balance sufficient");
                return Reason.LOWER_ETHER_BALANCE;
            }

            if (reason == Reason.GASLIMIT_TOO_SMALL) {
                // require(tx.gasLimit < 1234, "gas limit not too small");
                return Reason.GASLIMIT_TOO_SMALL;
            }

            revert("failed to prove txlist invalid");
        } catch (bytes memory) {
            return Reason.NOT_DECODABLE;
        }
    }
}
