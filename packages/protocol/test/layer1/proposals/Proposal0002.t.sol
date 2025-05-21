// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BuildProposal.sol";

interface ITestDelegateOwnedV2 {
    function withdraw(address _token, address _to, uint256 _amount) external;
}

contract Proposal0002 is BuildProposal {
    // L1 contracts
    address public constant L1_TAIKO_DAO_CONTROLLER_NEW_IMPL =
        0x6aC624FD2b3Bf8fbf1b121f7Aba0d1eC51f4c347;

    // L2 contracts
    address public constant L2_DELEGATE_OWNERE_NEW_IMPL = 0xdC2FaA24e73207C32314E6E1595Da454F53c7f34;
    address public constant L2_TEST_CONTRACT = 0xB0de2DD046732Ae94B2570d4785dcd55F79a19c0;
    address public constant L2_TEST_CONTRACT_NEW_IMPL = 0xd1934807041B168f383870A0d8F565aDe2DF9D7D;
    address public constant L2_DANIEL_WANG_ADDRESS = 0xf0A0d6Bd4aA94F53F3FB2c88488202a9E9eD2c55;

    // FOUNDRY_PROFILE=layer1 forge test --mt test_proposal_0002 -vvv
    function test_proposal_0002() public pure {
        buildProposal({ txId: 0, l2AllowFailure: true });
    }

    function buildL1Calls()
        internal
        pure
        override
        returns (TaikoDAOController.Action[] memory calls)
    {
        calls = new TaikoDAOController.Action[](1);

        // Upgrade TaikoDAOController to a new implementation
        calls[0] = buildL1UpgradeCall(L1_TAIKO_DAO_CONTROLLER, L1_TAIKO_DAO_CONTROLLER_NEW_IMPL);
    }

    function buildL2Calls() internal pure override returns (Multicall3.Call3[] memory calls) {
        calls = new Multicall3.Call3[](5);

        // Upgrade DelegateOwner to a new implementation
        calls[0] = buildL2UpgradeCall(L2_DELEGATE_OWNER, L2_DELEGATE_OWNERE_NEW_IMPL);

        // Transfer 1 TAIKO to Daniel Wang
        calls[1].target = L2_TAIKO_TOKEN;
        calls[1].callData = abi.encodeCall(IERC20.transfer, (L2_DANIEL_WANG_ADDRESS, 1 ether));

        // Upgrade TestDelegateOwned to a new implementation
        calls[2] = buildL2UpgradeCall(L2_TEST_CONTRACT, L2_TEST_CONTRACT_NEW_IMPL);

        // Transfer 0.001 Ether from TestDelegateOwned to Daniel Wang
        calls[3].target = L2_TEST_CONTRACT;
        calls[3].callData = abi.encodeCall(
            ITestDelegateOwnedV2.withdraw, (address(0), L2_DANIEL_WANG_ADDRESS, 0.001 ether)
        );

        // Transfer 1 TAIKO from TestDelegateOwned to Daniel Wang
        calls[4].target = L2_TEST_CONTRACT;
        calls[4].callData = abi.encodeCall(
            ITestDelegateOwnedV2.withdraw, (L2_TAIKO_TOKEN, L2_DANIEL_WANG_ADDRESS, 1 ether)
        );
    }
}
