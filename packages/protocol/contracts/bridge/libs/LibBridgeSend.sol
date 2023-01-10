// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "./LibBridgeData.sol";
import "./LibBridgeSignal.sol";

/**
 * Entry point for starting a bridge transaction.
 *
 * @title LibBridgeSend
 * @author dantaik <dan@taiko.xyz>
 */
library LibBridgeSend {
    using LibAddress for address;
    using LibBridgeData for IBridge.Message;

    /**
     * Initiate a bridge request.
     *
     * @param message Specifies the `depositValue`, `callValue`,
     * and `processingFee`. These must sum to `msg.value`. It also specifies the
     * `destChainId` which must be first enabled via `enableDestChain`,
     * and differ from the current chain ID.
     *
     * @return signal The message is hashed, stored, and emitted as a signal.
     * This is picked up by an off-chain relayer which indicates a
     * bridge message has been sent and is ready to be processed on the
     * destination chain.
     */
    function sendMessage(
        LibBridgeData.State storage state,
        AddressResolver resolver,
        IBridge.Message memory message
    ) internal returns (bytes32 signal) {
        require(message.owner != address(0), "B:owner");
        require(
            message.destChainId != block.chainid &&
                state.destChains[message.destChainId],
            "B:destChainId"
        );

        uint256 expectedAmount = message.depositValue +
            message.callValue +
            message.processingFee;
        require(expectedAmount == msg.value, "B:value");

        // For each message, expectedAmount is sent to ethVault to be handled.
        // Processing will retrieve these funds directly from ethVault.
        address ethVault = resolver.resolve("ether_vault");
        if (ethVault != address(0)) {
            ethVault.sendEther(expectedAmount);
        }

        message.id = state.nextMessageId++;
        message.sender = msg.sender;
        message.srcChainId = block.chainid;

        signal = message.hashMessage();
        // Store a key which is the hash of this contract address and the
        // signal, with a value of 1.
        LibBridgeSignal.sendSignal(address(this), signal);
        emit LibBridgeData.MessageSent(signal, message);
    }

    /**
     * Enable a destination chain ID for bridge transactions.
     */
    function enableDestChain(
        LibBridgeData.State storage state,
        uint256 chainId,
        bool enabled
    ) internal {
        require(chainId > 0 && chainId != block.chainid, "B:chainId");
        require(state.destChains[chainId] != enabled, "B:enabled");
        state.destChains[chainId] = enabled;
        emit LibBridgeData.DestChainEnabled(chainId, enabled);
    }
}
