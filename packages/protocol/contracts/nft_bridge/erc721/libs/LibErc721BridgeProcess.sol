// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../../common/AddressResolver.sol";
import { Erc721Vault } from "../../Erc721Vault.sol";
import { IErc721Bridge } from "../IErc721Bridge.sol";
import { ISignalService } from "../../../signal/ISignalService.sol";
import { LibAddress } from "../../../libs/LibAddress.sol";
import { LibErc721BridgeData } from "./LibErc721BridgeData.sol";
import { LibErc721BridgeStatus } from "./LibErc721BridgeStatus.sol";
import { LibMath } from "../../../libs/LibMath.sol";

/**
 * This library provides functions for processing bridge messages on the
 * destination chain.
 */
library LibErc721BridgeProcess {
    using LibMath for uint256;
    using LibAddress for address;
    using LibErc721BridgeData for IErc721Bridge.Message;
    using LibErc721BridgeData for LibErc721BridgeData.State;

    error ERC721_B_FORBIDDEN();
    error ERC721_B_SIGNAL_NOT_RECEIVED();
    error ERC721_B_STATUS_MISMATCH();
    error ERC721_B_WRONG_CHAIN_ID();

    /**
     * Process the bridge message on the destination chain. It can be called by
     * any address, including `message.owner`.
     * @dev It starts by hashing the message,
     * and doing a lookup in the bridge state to see if the status is "NEW".
     * It then does 2 things. Checks if Vault already has this NFT. If yes, then
     * releases it (sends) if not it means it is a new bridging (so mints it).
     * @param state The bridge state.  // @Jeff: Not needed here in erc721 bridge, since we dont have message.data() to invoke and no reentrancy attack for fungible tokens..(?)
     * @param resolver The address resolver.
     * @param message The message to process.
     * @param proof The msgHash proof from the source chain.
     */
    function processMessageErc721(
        LibErc721BridgeData.State storage state,
        AddressResolver resolver,
        IErc721Bridge.Message calldata message,
        bytes calldata proof
    )
        internal
    {
        
        // If the gas limit is set to zero, only the owner can process the
        // message.
        if (message.gasLimit == 0 && msg.sender != message.owner) {
            revert ERC721_B_FORBIDDEN();
        }

        if (message.destChainId != block.chainid) {
            revert ERC721_B_WRONG_CHAIN_ID();
        }

        // The message status must be "NEW"; 
        // There is no "RETRIABLE" here because 
        // there is no message.data to be invoked
        // LibBridgeRetry.sol.
        bytes32 msgHash = message.hashMessage();

        if (
            LibErc721BridgeStatus.getMessageStatusErc721(msgHash)
                != LibErc721BridgeStatus.MessageStatus.NEW
        ) {
            revert ERC721_B_STATUS_MISMATCH();
        }

        // Mark the status as FAILED in case something goes wrong with execution
        // ppl could claim it back on the source chain
        LibErc721BridgeStatus.updateMessageStatusErc721(msgHash, LibErc721BridgeStatus.MessageStatus.FAILED);

        // Message must have been "received" on the destChain (current chain)
        address srcErc721Bridge =
            resolver.resolve(message.srcChainId, "erc721_bridge", false);

        if (
            !ISignalService(resolver.resolve("signal_service", false))
                .isSignalReceived({
                srcChainId: message.srcChainId,
                app: srcErc721Bridge,
                signal: msgHash,
                proof: proof
            })
        ) {
            revert ERC721_B_SIGNAL_NOT_RECEIVED();
        }

        // Release tokens needs to have the mechanism to resolve the addresses
        // and deploy modified erc721 contracts if needed (with tokenURI)
        address tokenVault = resolver.resolve("erc721_vault", true);
        if (tokenVault != address(0)) {
            Erc721Vault(tokenVault).releaseOrMintTokens(
                message.owner,
                message.tokenContract,
                message.tokenIds,
                message.tokenURIs,
                message.tokenName,
                message.tokenSymbol
            );
        }

        // if sender is a relayer
        if (msg.sender != message.owner) {
            msg.sender.sendEther(message.processingFee);
        }

        // Mark the status as DONE (otherwise reverts anyways)
        LibErc721BridgeStatus.updateMessageStatusErc721(msgHash, LibErc721BridgeStatus.MessageStatus.DONE);
    }
}
