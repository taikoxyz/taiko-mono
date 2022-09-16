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
import "../../libs/LibBlockHeader.sol";
import "../../thirdparty/Lib_MerkleTrie.sol";
import "./LibBridgeData.sol";

/// @author dantaik <dan@taiko.xyz>
library LibBridgeRead {
    using LibBridgeData for Message;
    using LibBlockHeader for BlockHeader;

    /*********************
     * Internal Functions*
     *********************/

    struct MKProof {
        BlockHeader header;
        bytes proof;
    }

    // TODO:isMessageSent()?

    function isMessageReceived(
        AddressResolver resolver,
        Message calldata message,
        bytes calldata proof
    ) external view returns (bool received, bytes32 messageHash) {
        messageHash = message.hashMessage();
        MKProof memory mkp = abi.decode(proof, (MKProof));

        bytes32 syncedHeaderHash = IHeaderSync(resolver.resolve("header_sync"))
            .getSyncedHeader(mkp.header.height);

        received =
            syncedHeaderHash != 0 &&
            syncedHeaderHash == mkp.header.hashBlockHeader() &&
            Lib_MerkleTrie.verifyInclusionProof(
                Lib_RLPWriter.writeBytes32(messageHash),
                Lib_RLPWriter.writeUint(1),
                mkp.proof,
                mkp.header.stateRoot
            );
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
