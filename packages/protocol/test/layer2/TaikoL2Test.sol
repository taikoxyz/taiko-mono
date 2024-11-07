// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer2/DelegateOwner.sol";
import "src/layer2/based/LibEIP1559.sol";
import "src/layer2/based/TaikoL2.sol";
import "test/layer2/LibL2Signer.sol";
import "test/shared/TaikoTest.sol";

abstract contract TaikoL2Test is TaikoTest {
    function deployDelegateOwner(
        DefaultResolver resolver,
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
                ),
                resolver: resolver
            })
        );
    }
}
