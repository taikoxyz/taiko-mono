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
import "../Signaler.sol";
import "./LibBridgeData.sol";

/// @author dantaik <dan@taiko.xyz>
library LibBridgeRead {
    using LibBridgeData for IBridge.Message;
    using LibBlockHeader for BlockHeader;

    /**
     * @dev Queries contract storage for whether the messageHash is present. Only supposed to be called on srcChain bridge contract.
     */
    function isMessageSent(AddressResolver resolver, bytes32 mhash)
        internal
        view
        returns (bool)
    {
        return
            Signaler(resolver.resolve("signaler")).isSignalSent(
                address(this),
                mhash
            );
    }

    function isMessageReceived(
        AddressResolver resolver,
        bytes32 mhash,
        uint256 srcChainId,
        bytes calldata proof
    ) internal view returns (bool) {
        return
            Signaler(resolver.resolve("signaler")).isSignalReceived(
                address(this),
                mhash,
                srcChainId,
                proof
            );
    }

    function isDestChainEnabled(
        LibBridgeData.State storage state,
        uint256 _chainId
    ) internal view returns (bool) {
        return state.destChains[_chainId];
    }
}
