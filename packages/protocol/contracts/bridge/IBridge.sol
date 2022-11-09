// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

/**
 * Bridge interface.
 * @dev Cross-chain Ether is held by Bridges, not TokenVaults.
 * @author dantaik <dan@taiko.xyz>
 */
interface IBridge {
    struct Message {
        uint256 id; // auto filled
        address sender; // auto filled
        uint256 srcChainId; // auto filled
        uint256 destChainId;
        address owner;
        address to; // target address on destChain
        address refundAddress; // if address(0), refunds to owner
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

    /// Sends a message to the destination chain and takes custody
    /// of Ether required in this contract. All extra Ether will be refunded.
    function sendMessage(
        Message memory message
    ) external payable returns (bytes32 signal);

    /// Stores a signal on the bridge contract and emits an event for the
    /// relayer to pick up.
    function sendSignal(bytes32 signal) external;

    /// Checks if a signal has been stored on the bridge contract by the
    /// current address.
    function isMessageSent(bytes32 signal) external view returns (bool);

    /// Checks if a signal has been received on the destination chain and
    /// sent by the src chain.
    function isMessageReceived(
        bytes32 signal,
        uint256 srcChainId,
        bytes calldata proof
    ) external view returns (bool);

    /// Checks if a signal has been stored on the bridge contract by the
    /// specified address.
    function isSignalSent(
        address sender,
        bytes32 signal
    ) external view returns (bool);

    /// Check if a signal has been received on the destination chain and sent
    /// by the specified sender.
    function isSignalReceived(
        bytes32 signal,
        uint256 srcChainId,
        address sender,
        bytes calldata proof
    ) external view returns (bool);

    /// Returns the bridge state context.
    function context() external view returns (Context memory context);
}
