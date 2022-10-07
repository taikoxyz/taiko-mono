// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../common/AddressResolver.sol";
import "../../common/IHeaderSync.sol";
import "../../libs/LibBlockHeader.sol";
import "../../libs/LibTrieProof.sol";

library LibBridgeSignal {
    using LibBlockHeader for BlockHeader;

    struct SignalProof {
        BlockHeader header;
        bytes proof;
    }

    modifier onlyValidSenderAndSignal(address sender, bytes32 signal) {
        require(sender != address(0), "B:sender");
        require(signal != 0, "B:signal");
        _;
    }

    function sendSignal(address sender, bytes32 signal)
        internal
        onlyValidSenderAndSignal(sender, signal)
    {
        bytes32 key = _key(sender, signal);
        assembly {
            sstore(key, 1)
        }
    }

    function isSignalSent(address sender, bytes32 signal)
        internal
        view
        onlyValidSenderAndSignal(sender, signal)
        returns (bool)
    {
        bytes32 key = _key(sender, signal);
        uint256 v;
        assembly {
            v := sload(key)
        }
        return v == 1;
    }

    function isSignalReceived(
        AddressResolver resolver,
        address srcBridge,
        address sender,
        bytes32 signal,
        bytes calldata proof
    ) internal view onlyValidSenderAndSignal(sender, signal) returns (bool) {
        require(srcBridge != address(0), "S:srcBridge");

        SignalProof memory mkp = abi.decode(proof, (SignalProof));
        LibTrieProof.verify(
            mkp.header.stateRoot,
            srcBridge,
            _key(sender, signal),
            bytes32(uint256(1)),
            mkp.proof
        );

        bytes32 syncedHeaderHash = IHeaderSync(resolver.resolve("taiko"))
            .getSyncedHeader(mkp.header.height);

        return
            syncedHeaderHash != 0 &&
            syncedHeaderHash == mkp.header.hashBlockHeader();
    }

    function _key(address sender, bytes32 signal)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(sender, signal));
    }
}
