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
import "../../libs/LibTrieProof.sol";
import "./LibBridgeData.sol";

/// @author dantaik <dan@taiko.xyz>
library LibBridgeRead {
    using LibBridgeData for IBridge.Message;
    using LibBlockHeader for BlockHeader;

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
        uint256 srcChainId,
        bytes calldata proof
    ) internal view returns (bool) {
        MKProof memory mkp = abi.decode(proof, (MKProof));
        require(srcChainId != block.chainid, "B:chainId");

        LibTrieProof.verify(
            mkp.header.stateRoot,
            resolver.resolve(srcChainId, "bridge"),
            mhash,
            bytes32(uint256(1)),
            mkp.proof
        );

        bytes32 syncedHeaderHash = IHeaderSync(resolver.resolve("taiko"))
            .getSyncedHeader(mkp.header.height);

        return
            syncedHeaderHash != 0 &&
            syncedHeaderHash == mkp.header.hashBlockHeader();
    }

    function isDestChainEnabled(
        LibBridgeData.State storage state,
        uint256 _chainId
    ) internal view returns (bool) {
        return state.destChains[_chainId];
    }
}
