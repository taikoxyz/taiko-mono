// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { EtherVault } from "../EtherVault.sol";
import { IBridge } from "../IBridge.sol";
import {
    IERC165Upgradeable
} from "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import { LibBridgeData } from "./LibBridgeData.sol";
import { LibBridgeStatus } from "./LibBridgeStatus.sol";

interface VaultContract {
    function releaseToken(IBridge.Message calldata message) external;
}
/**
 * This library provides functions for releasing Ether related to message
 * execution on the Bridge.
 */

library LibBridgeRelease {
    using LibBridgeData for IBridge.Message;

    // All of the vaults has the same interface id
    bytes4 public constant VAULT_INTERFACE_ID = 0x156ef222;

    event EtherReleased(bytes32 indexed msgHash, address to, uint256 amount);

    error B_TOKENS_RELEASED_ALREADY();
    error B_FAILED_TRANSFER();
    error B_MSG_NOT_FAILED();
    error B_OWNER_IS_NULL();
    error B_WRONG_CHAIN_ID();

    /**
     * Release Ether to the message owner
     * @dev This function releases Ether to the message owner, only if the
     * Bridge state says:
     * - Ether for this message has not been released before.
     * - The message is in a failed state.
     * @param state The current state of the Bridge
     * @param resolver The AddressResolver instance
     * @param message The message whose associated Ether should be released
     * @param proof The proof data
     */
    function recallMessage(
        LibBridgeData.State storage state,
        AddressResolver resolver,
        IBridge.Message calldata message,
        bytes calldata proof
    )
        internal
    {
        if (message.owner == address(0)) {
            revert B_OWNER_IS_NULL();
        }

        if (message.srcChainId != block.chainid) {
            revert B_WRONG_CHAIN_ID();
        }

        bytes32 msgHash = message.hashMessage();

        if (
            !LibBridgeStatus.isMessageFailed(
                resolver, msgHash, message.destChainId, proof
            )
        ) {
            revert B_MSG_NOT_FAILED();
        }
        
        if(state.recallStatus[msgHash] 
                == LibBridgeData.RecallStatus.FULLY_RECALLED
        ){
            // Both ether and tokens are released
            revert B_TOKENS_RELEASED_ALREADY();
        }

        uint256 releaseAmount;

        if(state.recallStatus[msgHash] 
                == LibBridgeData.RecallStatus.NOT_RECALLED
        ) {
            // Release ETH first
            state.recallStatus[msgHash] = LibBridgeData.RecallStatus.ETH_RELEASED;

            releaseAmount = message.depositValue + message.callValue;

            if (releaseAmount > 0) {
                address ethVault = resolver.resolve("ether_vault", true);
                // if on Taiko
                if (ethVault != address(0)) {
                    EtherVault(payable(ethVault)).releaseEther(
                        message.owner, releaseAmount
                    );
                } else {
                    // if on Ethereum
                    (bool success,) = message.owner.call{ value: releaseAmount }("");
                    if (!success) {
                        revert B_FAILED_TRANSFER();
                    }
                }
            }
        }
        //2nd stage is releasing the tokens
        if(state.recallStatus[msgHash] 
                == LibBridgeData.RecallStatus.ETH_RELEASED 
        ) {
            if( message.to == address(0)
                || !_isContract(message.sender)
                || !IERC165Upgradeable(message.sender).supportsInterface(VAULT_INTERFACE_ID) 
            ) {
                state.recallStatus[msgHash] = LibBridgeData.RecallStatus.FULLY_RECALLED;
            } else {
                // Set state before successfull call because of reentrancy
                // we changing it back in the catch() if call unsuccessful
                state.recallStatus[msgHash] =
                    LibBridgeData.RecallStatus.FULLY_RECALLED;
                try VaultContract(
                    (message.sender)
                ).releaseToken(message){
                } catch {
                    // If it had a token (erc20/721/1115) try to release
                    // it and if unsuccessfull set the status back so that
                    // we might try once more to releaseTokens - if it
                    // fails bc. we forgot to set AddressManager or something (?)
                    state.recallStatus[msgHash] = LibBridgeData.RecallStatus.ETH_RELEASED;
                }
            }
        }
        emit EtherReleased(msgHash, message.owner, releaseAmount);
    }

    function _isContract(address _addr) private view returns (bool isContract){
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}
