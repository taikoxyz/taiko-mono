// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BuildProposal.sol";

interface ITestDelegateOwnedV2 {
    function withdraw(address _token, address _to, uint256 _amount) external;
}

contract Proposal0002 is BuildProposal {
    // L2 Contracts
    address public constant DELEGATE_OWNERE_NEW_IMPL = 0xdC2FaA24e73207C32314E6E1595Da454F53c7f34;
    address public constant TEST_CONTRACT = 0xB0de2DD046732Ae94B2570d4785dcd55F79a19c0;
    address public constant TEST_CONTRACT_NEW_IMPL = 0xd1934807041B168f383870A0d8F565aDe2DF9D7D;

    // L1 contracts
    address public constant TAIKO_DAO_CONTROLLER_NEW_IMPL =
        0x6aC624FD2b3Bf8fbf1b121f7Aba0d1eC51f4c347;

    // FOUNDRY_PROFILE=layer1 forge test --mt test_proposal_0002 -vvv
    function test_proposal_0002() public pure {
        buildProposal({ txId: 0, l2AllowFailure: true, l2Executor: L2_PERMISSIONLESS_EXECUTOR });
    }

    function buildL1Calls()
        internal
        pure
        override
        returns (TaikoDAOController.Call[] memory calls)
    {
        calls = new TaikoDAOController.Call[](1);

        // Upgrade TaikoDAOController to a new implementation
        calls[0] = buildL1UpgradeCall(L1_TAIKO_DAO_CONTROLLER, TAIKO_DAO_CONTROLLER_NEW_IMPL);
    }

    function buildL2Calls() internal pure override returns (Multicall3.Call3[] memory calls) {
        calls = new Multicall3.Call3[](5);

        // Upgrade DelegateOwner to a new implementation
        calls[0] = buildL2UpgradeCall(L2_DELEGATE_OWNER, DELEGATE_OWNERE_NEW_IMPL);

        // Transfer 1 TAIKO to the delegate owner
        calls[1].target = L2_TAIKO_TOKEN;
        calls[1].callData = abi.encodeCall(IERC20.transfer, (L2_DELEGATE_OWNER, 1 ether));

        // Upgrade TestDelegateOwned to a new implementation
        calls[2] = buildL2UpgradeCall(TEST_CONTRACT, TEST_CONTRACT_NEW_IMPL);

        // Transfer 0.001 Ether from TestDelegateOwned to the delegate owner (the ether will stuck there)
        calls[3].target = TEST_CONTRACT;
        calls[3].callData =
            abi.encodeCall(ITestDelegateOwnedV2.withdraw, (address(0), L2_DELEGATE_OWNER, 0.001 ether));

        // Transfer 1 TAIKO from TestDelegateOwned to the delegate owner
        calls[4].target = TEST_CONTRACT;
        calls[4].callData =
            abi.encodeCall(ITestDelegateOwnedV2.withdraw, (L2_TAIKO_TOKEN, L2_DELEGATE_OWNER, 1 ether));
    }
}
