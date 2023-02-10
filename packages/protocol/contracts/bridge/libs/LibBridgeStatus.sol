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

/**
 * @author dantaik <dan@taiko.xyz>
 */
library LibBridgeStatus {
    using LibBlockHeader for BlockHeader;

    enum MessageStatus {
        NEW,
        RETRIABLE,
        DONE,
        FAILED
    }

    event MessageStatusChanged(
        bytes32 indexed msgHash,
        MessageStatus status,
        address transactor
    );

    /**
     * @dev If messageStatus is same as in the messageStatus mapping,
     *      does nothing.
     * @param msgHash The messageHash of the message.
     * @param status The status of the message.
     */
    function updateMessageStatus(
        bytes32 msgHash,
        MessageStatus status
    ) internal {
        if (getMessageStatus(msgHash) != status) {
            _setMessageStatus(msgHash, status);
            emit LibBridgeStatus.MessageStatusChanged(
                msgHash,
                status,
                msg.sender
            );
        }
    }

    function getMessageStatus(
        bytes32 msgHash
    ) internal view returns (MessageStatus) {
        bytes32 slot = getMessageStatusSlot(msgHash);
        uint256 value;
        assembly {
            value := sload(slot)
        }
        return MessageStatus(value);
    }

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
                slot: getMessageStatusSlot(msgHash),
                value: bytes32(uint256(LibBridgeStatus.MessageStatus.FAILED)),
                mkproof: sp.proof
            });
    }

    function getMessageStatusSlot(
        bytes32 msgHash
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("MESSAGE_STATUS", msgHash));
    }

    function _setMessageStatus(bytes32 msgHash, MessageStatus status) private {
        bytes32 slot = getMessageStatusSlot(msgHash);
        uint256 value = uint256(status);
        assembly {
            sstore(slot, value)
        }
    }
}
