// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer2/governance/DelegateController.sol";
import "test/layer2/LibAnchorSigner.sol";
import "test/shared/CommonTest.sol";

abstract contract Layer2Test is CommonTest {
    function deployDelegateController(
        uint64 l1ChainId,
        address l2Bridge,
        address daoController
    )
        internal
        returns (DelegateController)
    {
        return DelegateController(
            payable(deploy({
                    name: "delegate_controller",
                    impl: address(new DelegateController(l1ChainId, l2Bridge, daoController)),
                    data: abi.encodeCall(DelegateController.init, ())
                }))
        );
    }
}
