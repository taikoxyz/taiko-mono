// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

/// @author dantaik <dan@taiko.xyz>
/// @dev Cross-chain Ether are held by Bridges, not TokenVaults.
interface IBridge {
    enum MessageStatus {
        NEW,
        RETRIABLE,
        DONE
    }

    struct Message {
        uint256 id; // auto filled
        address sender; // auto filled
        uint256 srcChainId; // auto filled
        uint256 destChainId;
        address owner;
        address to;
        address refundAddress;
        uint256 depositValue;
        uint256 callValue;
        uint256 maxProcessingFee;
        uint256 gasLimit;
        uint256 gasPrice;
        bytes data;
        string memo;
    }

    struct Context {
        bytes32 mhash;
        address sender;
        uint256 srcChainId;
    }

    /// @dev Sends a message to the destination chain and takes custody
    /// of Ether required in this contract. All extra Ether will be refunded.
    function sendMessage(Message memory message)
        external
        payable
        returns (bytes32 mhash);

    function context() external view returns (Context memory context);
}
