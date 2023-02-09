// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

/**
 * Bridge interface.
 * @dev Ether is held by Bridges on L1 and by the EtherVault on L2,
 * not TokenVaults.
 * @author dantaik <dan@taiko.xyz>
 */
interface IBridge {
    struct Message {
        // Message ID.
        uint256 id;
        // Message sender address (auto filled).
        address sender;
        // Source chain ID (auto filled).
        uint256 srcChainId;
        // Destination chain ID where the `to` address lives (auto filled).
        uint256 destChainId;
        // Owner address of the bridged asset.
        address owner;
        // Destination owner address.
        address to;
        // Alternate address to send any refund. If blank, defaults to owner.
        address refundAddress;
        // Deposited Ether minus the processingFee.
        uint256 depositValue;
        // callValue to invoke on the destination chain, for ERC20 transfers.
        uint256 callValue;
        // Processing fee for the relayer. Zero if owner will process themself.
        uint256 processingFee;
        // gasLimit to invoke on the destination chain, for ERC20 transfers.
        uint256 gasLimit;
        // callData to invoke on the destination chain, for ERC20 transfers.
        bytes data;
        // Optional memo.
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
