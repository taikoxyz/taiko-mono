// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer2/DelegateOwner.sol";
import "src/layer2/based/anchor/TaikoAnchor.sol";
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
                data: abi.encodeCall(TaikoAnchor.init, (address(0), l1ChainId, 0))
            })
        );
    }

    function deployDelegateOwner(
        address daoController,
        uint64 remoteChainId,
        address bridge
    )
        internal
        returns (DelegateOwner)
    {
        return DelegateOwner(
            payable(
                deploy({
                    name: "delegate_owner",
                    impl: address(new DelegateOwner(remoteChainId, bridge, daoController)),
                    data: abi.encodeCall(DelegateOwner.init, ())
                })
            )
        );
    }
}
