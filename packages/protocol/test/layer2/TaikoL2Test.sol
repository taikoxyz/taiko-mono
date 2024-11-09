// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer2/DelegateOwner.sol";
import "src/layer2/based/LibEIP1559.sol";
import "src/layer2/based/TaikoL2.sol";
import "test/layer2/LibL2Signer.sol";
import "test/shared/TaikoTest.sol";

abstract contract TaikoL2Test is TaikoTest {
    function deployTaikoL2(address taikoL2Impl, uint64 l1ChainId) internal returns (TaikoL2) {
        return TaikoL2(
            deploy({
                name: "taiko",
                impl: taikoL2Impl,
                data: abi.encodeCall(TaikoL2.init, (address(0), address(resolver), l1ChainId, 0))
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
