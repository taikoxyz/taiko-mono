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
    struct Message {
        uint256 id; // auto filled
        address sender; // auto filled
        uint256 srcChainId; // auto filled
        uint256 destChainId;
        address owner;
        address to; // target address on destChain
        address refundAddress; // address to refund gas/ether to, if address(0), refunds to owner
        uint256 depositValue; // value to be deposited at "to" address
        uint256 callValue; // value to be called on destChain
        uint256 processingFee; // processing fee sender is willing to pay
        uint256 gasLimit;
        bytes data; // calldata
        string memo;
    }

    struct Context {
        bytes32 signal; // messageHash
        address sender;
        uint256 srcChainId;
    }

    event SignalSent(address sender, bytes32 signal);

    event MessageSent(bytes32 indexed signal, Message message);

    /// @dev Sends a message to the destination chain and takes custody
    /// of Ether required in this contract. All extra Ether will be refunded.
    function sendMessage(Message memory message)
        external
        payable
        returns (bytes32 signal);

    function sendSignal(bytes32 signal) external;

    function isMessageSent(bytes32 signal) external view returns (bool);

    function isMessageReceived(
        bytes32 signal,
        uint256 srcChainId,
        bytes calldata proof
    ) external view returns (bool);

    function isSignalSent(address sender, bytes32 signal)
        external
        view
        returns (bool);

    function isSignalReceived(
        bytes32 signal,
        uint256 srcChainId,
        address sender,
        bytes calldata proof
    ) external view returns (bool);

    function context() external view returns (Context memory context);
}
