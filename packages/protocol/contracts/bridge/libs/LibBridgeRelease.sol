// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../../common/IHeaderSync.sol";
import "../../libs/LibBlockHeader.sol";
import "../../libs/LibTrieProof.sol";
import "./LibBridgeData.sol";
import "./LibBridgeStatus.sol";

/**
 * @author dantaik <dan@taiko.xyz>
 */
library LibBridgeRelease {
    using LibBlockHeader for BlockHeader;
    using LibBridgeData for IBridge.Message;

    /*********************
     * Internal Functions*
     *********************/

    function isMessageFailed(
        AddressResolver resolver,
        bytes32 msgHash,
        uint256 destChainId,
        bytes calldata proof
    ) internal view returns (bool) {
        require(destChainId != block.chainid, "B:destChainId");
        require(msgHash != 0, "B:msgHash");

        LibBridgeData.StatusProof memory sp = abi.decode(
            proof,
            (LibBridgeData.StatusProof)
        );
        bytes32 syncedHeaderHash = IHeaderSync(resolver.resolve("taiko", false))
            .getSyncedHeader(sp.header.height);

        if (
            syncedHeaderHash == 0 ||
            syncedHeaderHash != sp.header.hashBlockHeader()
        ) {
            return false;
        }

        return
            LibTrieProof.verify({
                stateRoot: sp.header.stateRoot,
                addr: resolver.resolve(destChainId, "bridge", false),
                slot: LibBridgeStatus.getMessageStatusSlot(msgHash),
                value: bytes32(uint256(LibBridgeStatus.MessageStatus.FAILED)),
                mkproof: sp.proof
            });
    }
}
