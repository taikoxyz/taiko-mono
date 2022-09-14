// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../common/IHeaderSync.sol";
import "../../thirdparty/Lib_MerkleTrie.sol";
import "./LibBridgeData.sol";

/// @author dantaik <dan@taiko.xyz>
library LibBridgeRead {
    using LibBridgeData for Message;

    /*********************
     * Internal Functions*
     *********************/

    struct MKProof {
        uint256 blockNumber;
        bytes proof;
    }

    function isMessageReceived(
        AddressResolver resolver,
        Message memory message,
        bytes memory proof
    ) internal view returns (bool received, bytes32 messageHash) {
        messageHash = message.hashMessage();
        MKProof memory mkp = abi.decode(proof, (MKProof));

        bytes32 syncedHeaderHash = IHeaderSync(resolver.resolve("header_sync"))
            .getSyncedHeader(mkp.blockNumber);

        received =
            syncedHeaderHash != 0 &&
            Lib_MerkleTrie.verifyInclusionProof(
                Lib_RLPWriter.writeBytes32(messageHash),
                Lib_RLPWriter.writeUint(1),
                mkp.proof,
                syncedHeaderHash
            );
    }

    function getMessageStatus(
        LibBridgeData.State storage state,
        uint256 srcChainId,
        uint256 messageId
    ) internal view returns (IBridge.MessageStatus) {
        uint256 bits = state.statusBitmaps[srcChainId][messageId / 128];
        uint256 value = (bits >> ((messageId % 128) << 1)) & 3;
        return IBridge.MessageStatus(value);
    }

    function context(LibBridgeData.State storage state)
        internal
        view
        returns (IBridge.Context memory)
    {
        require(
            state.ctx.srcChainSender !=
                LibBridgeData.SRC_CHAIN_SENDER_PLACEHOLDER,
            "B:noContext"
        );
        return state.ctx;
    }

    function isDestChainEnabled(
        LibBridgeData.State storage state,
        uint256 _chainId
    ) internal view returns (bool) {
        return state.destChains[_chainId];
    }

    function chainId() internal view returns (uint256 _chainId) {
        assembly {
            _chainId := chainid()
        }
    }
}
