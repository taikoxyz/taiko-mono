// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../EtherVault.sol";
import "./LibBridgeData.sol";
import "./LibBridgeStatus.sol";

/**
 * @author dantaik <dan@taiko.xyz>
 */
library LibBridgeRelease {
    using LibBridgeData for IBridge.Message;

    event EtherReleased(bytes32 indexed msgHash, address to, uint256 amount);

    /**
     * Release Ether to the message owner, only if the Taiko Bridge state says:
     * - Ether for this message has not been released before.
     * - The message is in a failed state.
     */
    function releaseEther(
        LibBridgeData.State storage state,
        AddressResolver resolver,
        IBridge.Message calldata message,
        bytes calldata proof
    ) internal {
        require(message.owner != address(0), "B:owner");
        require(message.srcChainId == block.chainid, "B:srcChainId");

        bytes32 msgHash = message.hashMessage();
        require(state.etherReleased[msgHash] == false, "B:etherReleased");
        require(
            LibBridgeStatus.isMessageFailed(
                resolver,
                msgHash,
                message.destChainId,
                proof
            ),
            "B:notFailed"
        );

        state.etherReleased[msgHash] = true;

        uint256 releaseAmount = message.depositValue + message.callValue;

        if (releaseAmount > 0) {
            address ethVault = resolver.resolve("ether_vault", true);
            // if on Taiko
            if (ethVault != address(0)) {
                EtherVault(payable(ethVault)).releaseEther(
                    message.owner,
                    releaseAmount
                );
            } else {
                // if on Ethereum
                (bool success, ) = message.owner.call{value: releaseAmount}("");
                require(success, "B:transfer");
            }
        }
        emit EtherReleased(msgHash, message.owner, releaseAmount);
    }
}
