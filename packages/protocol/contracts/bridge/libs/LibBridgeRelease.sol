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

    error ErrReleaseInvalidMessageOwner();
    error ErrReleaseInvalidSourceChain();
    error ErrReleaseEtherReleasedAlready();
    error ErrReleaseMessageNotFailedOnDestinationChain();
    error ErrReleaseEtherTransferFailed();

    function releaseEther(
        LibBridgeData.State storage state,
        AddressResolver resolver,
        IBridge.Message calldata message,
        bytes calldata proof
    ) internal {
        if (message.owner == address(0)) {
            revert ErrReleaseInvalidMessageOwner();
        }
        if (message.srcChainId != block.chainid) {
            revert ErrReleaseInvalidSourceChain();
        }

        bytes32 msgHash = message.hashMessage();
        if (state.etherReleased[msgHash]) {
            revert ErrReleaseEtherReleasedAlready();
        }
        if (
            !LibBridgeStatus.isMessageFailed(
                resolver,
                msgHash,
                message.destChainId,
                proof
            )
        ) {
            revert ErrReleaseMessageNotFailedOnDestinationChain();
        }

        state.etherReleased[msgHash] = true;

        uint256 releaseAmount = message.depositValue + message.callValue;

        if (releaseAmount > 0) {
            address ethVault = resolver.resolve("ether_vault", true);
            if (ethVault != address(0)) {
                EtherVault(payable(ethVault)).releaseEtherTo(
                    message.owner,
                    releaseAmount
                );
            } else {
                (bool success, ) = message.owner.call{value: releaseAmount}("");
                if (!success) revert ErrReleaseEtherTransferFailed();
            }
        }
        emit EtherReleased(msgHash, message.owner, releaseAmount);
    }
}
