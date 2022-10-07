// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../common/EssentialContract.sol";
import "../common/IHeaderSync.sol";
import "../libs/LibBlockHeader.sol";
import "../libs/LibTrieProof.sol";

struct MKProof {
    BlockHeader header;
    bytes proof;
}

interface IMessager {
    function sendMessage(bytes32 message) external;

    function isMessageReceived(
        address sender,
        bytes32 message,
        uint256 srcChainId,
        bytes calldata proof
    ) external view returns (bool);
}

contract Messager is EssentialContract, IMessager {
    using LibBlockHeader for BlockHeader;

    uint256[50] private __gap;

    /// @dev Initializer to be called after being deployed behind a proxy.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    function sendMessage(bytes32 message) external override {
        bytes32 key = _key(msg.sender, message);
        assembly {
            sstore(key, 1)
        }
    }

    function isMessageSent(address sender, bytes32 message)
        public
        view
        returns (bool)
    {
        bytes32 key = _key(sender, message);
        uint256 v;
        assembly {
            v := sload(key)
        }
        return v == uint256(1);
    }

    function isMessageReceived(
        address sender,
        bytes32 message,
        uint256 srcChainId,
        bytes calldata proof
    ) public view override returns (bool) {
        MKProof memory mkp = abi.decode(proof, (MKProof));
        require(srcChainId != block.chainid, "B:chainId");

        bytes32 key = _key(sender, message);

        LibTrieProof.verify(
            mkp.header.stateRoot,
            resolve(srcChainId, "messanger"),
            key,
            bytes32(uint256(1)),
            mkp.proof
        );

        bytes32 syncedHeaderHash = IHeaderSync(resolve("taiko"))
            .getSyncedHeader(mkp.header.height);

        return
            syncedHeaderHash != 0 &&
            syncedHeaderHash == mkp.header.hashBlockHeader();
    }

    function _key(address sender, bytes32 message)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(sender, message));
    }
}
