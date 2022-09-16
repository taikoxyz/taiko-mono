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

    function isMessageSent(bytes32 mhash) internal view returns (bool) {
        uint256 v;
        assembly {
            v := sload(mhash)
        }
        return v == uint256(1);
    }

    function isMessageReceived(
        AddressResolver resolver,
        bytes32 mhash,
        bytes calldata proof
    ) internal view returns (bool received) {
        MKProof memory mkp = abi.decode(proof, (MKProof));

        bytes32 syncedHeaderHash = IHeaderSync(resolver.resolve("header_sync"))
            .getSyncedHeader(mkp.header.height);

        received =
            syncedHeaderHash != 0 &&
            syncedHeaderHash == mkp.header.hashBlockHeader() &&
            Lib_MerkleTrie.verifyInclusionProof(
                Lib_RLPWriter.writeBytes32(mhash),
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
}
