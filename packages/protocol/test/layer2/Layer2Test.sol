// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer2/DelegateOwner.sol";
import "src/layer2/based/LibEIP1559.sol";
import "src/layer2/based/TaikoAnchor.sol";
import "test/layer2/LibAnchorSigner.sol";
import "test/shared/CommonTest.sol";

abstract contract Layer2Test is CommonTest {
    function deployAnchor(
        address taikoAnchorImpl,
        uint64 l1ChainId
    )
        internal
        returns (TaikoAnchor)
    {
        return TaikoAnchor(
            deploy({
                name: "taiko",
                impl: taikoAnchorImpl,
                data: abi.encodeCall(TaikoAnchor.init, (address(0), address(resolver), l1ChainId, 0))
            })
        );
    }

    function deployDelegateOwner(
        address remoteOwner,
        uint64 remoteChainId
    )
        internal
        returns (DelegateOwner)
    {
        return DelegateOwner(
            deploy({
                name: "delegate_owner",
                impl: address(new DelegateOwner()),
                data: abi.encodeCall(
                    DelegateOwner.init, (remoteOwner, address(resolver), remoteChainId, address(0))
                )
            })
        );
    }
}
