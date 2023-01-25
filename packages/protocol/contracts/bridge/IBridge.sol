// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

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
        bytes32 msgHash; // messageHash
        address sender;
        uint256 srcChainId;
    }

    event SignalSent(address sender, bytes32 msgHash);
    event MessageSent(bytes32 indexed msgHash, Message message);
    event EtherReleased(bytes32 indexed msgHash, address to, uint256 amount);

    /// Sends a message to the destination chain and takes custody
    /// of Ether required in this contract. All extra Ether will be refunded.
    function sendMessage(
        Message memory message
    ) external payable returns (bytes32 msgHash);

    // Release Ether with a proof that the message processing on the destination
    // chain has been failed.
    function releaseEther(
        IBridge.Message calldata message,
        bytes calldata proof
    ) external;

    /// Checks if a msgHash has been stored on the bridge contract by the
    /// current address.
    function isMessageSent(bytes32 msgHash) external view returns (bool);

    /// Checks if a msgHash has been received on the destination chain and
    /// sent by the src chain.
    function isMessageReceived(
        bytes32 msgHash,
        uint256 srcChainId,
        bytes calldata proof
    ) external view returns (bool);

    /// Checks if a msgHash has been failed on the destination chain.
    function isMessageFailed(
        bytes32 msgHash,
        uint256 destChainId,
        bytes calldata proof
    ) external view returns (bool);

    /// Returns the bridge state context.
    function context() external view returns (Context memory context);

    function hashMessage(
        IBridge.Message calldata message
    ) external pure returns (bytes32);
}
