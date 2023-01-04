// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../signal/ISignalService.sol";
import "./LibBridgeData.sol";

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
     * @return msgHash The message is hashed, stored, and emitted as a signal.
     * This is picked up by an off-chain relayer which indicates a
     * bridge message has been sent and is ready to be processed on the
     * destination chain.
     */
    function sendMessage(
        LibBridgeData.State storage state,
        AddressResolver resolver,
        IBridge.Message memory message
    ) internal returns (bytes32 msgHash) {
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

        msgHash = message.hashMessage();
        // Store a key which is the hash of this contract address and the
        // signal, with a value of 1.
        ISignalService(resolver.resolve("signal_service")).sendSignal(
            address(0),
            msgHash
        );
        emit LibBridgeData.MessageSent(msgHash, message);
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
        state.destChains[chainId] = enabled;
        emit LibBridgeData.DestChainEnabled(chainId, enabled);
    }

    function isMessageSent(
        AddressResolver resolver,
        bytes32 msgHash
    ) internal view returns (bool) {
        return
            ISignalService(resolver.resolve("signal_service")).isSignalSent(
                address(this),
                address(0),
                msgHash
            );
    }

    function isMessageReceived(
        AddressResolver resolver,
        bytes32 msgHash,
        uint256 srcChainId,
        bytes calldata proof
    ) internal view returns (bool) {
        address srcBridge = resolver.resolve(srcChainId, "bridge");
        return
            ISignalService(resolver.resolve("signal_service"))
                .isSignalReceived({
                    app: srcBridge,
                    user: address(0),
                    signal: msgHash,
                    proof: proof
                });
    }
}
