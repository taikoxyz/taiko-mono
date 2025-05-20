// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/layer1/governance/TaikoDAOController.sol";
import "forge-std/src/Test.sol";
import "src/layer2/DelegateOwner.sol";
import "test/shared/thirdparty/Multicall3.sol";
import "src/shared/bridge/IBridge.sol";
import "./BuildProposal.sol";

interface ITestDelegateOwnedV2 {
    function withdraw(address _token, address _to, uint256 _amount) external;
}

// This proposal performs multiple actions on Taiko L2 via a self-owned contract called
// DelegateOwner. On L2, DelegateOwner is the owner of all core contracts. To execute transactions
// on these contracts, an L2 DAO proposal must be passed and bridged through the Taiko Bridge. The
// bridged message is then synchronously executed on L2 with DelegateOwner as the target, which
// triggers a series of delegated calls.

// The proposal executes the following actions on L2:
// 	•	Upgrade DelegateOwner to a new implementation (address TBD)
// 	•	Transfer 1 TAIKO token from DelegateOwner to the same EOA
// 	•	Upgrade the TestDelegateOwned contract (owned by DelegateOwner) to a new implementation
// 	•	Transfer 0.001 Ether from TestDelegateOwned to the same EOA
// 	•	Transfer 1 TAIKO token from TestDelegateOwned to the same EOA
contract TrainingModule3DanielWang is BuildProposal {
    // L2 Contracts
    address public constant DELEGATE_OWNERE_NEW_IMPL = 0xdC2FaA24e73207C32314E6E1595Da454F53c7f34;
    address public constant TEST_CONTRACT_PROXY = 0xB0de2DD046732Ae94B2570d4785dcd55F79a19c0;
    address public constant TEST_CONTRACT_NEW_IMPL = 0xd1934807041B168f383870A0d8F565aDe2DF9D7D;
    address public constant RECIPIENT = 0xe36C0F16d5fB473CC5181f5fb86b6Eb3299aD9cb;

    // L1 contracts
    address public constant TAIKO_DAO_CONTROLLER_NEW_IMPL = address(0); // TODO

    // FOUNDRY_PROFILE=layer1 forge test --mt test_proposal_0002 -vvv
    function test_proposal_0002() public pure {
        buildProposal(0);
    }

    function buildL1Calls()
        internal
        pure
        override
        returns (TaikoDAOController.Call[] memory calls)
    {
        calls = new TaikoDAOController.Call[](1);

        calls[0] = TaikoDAOController.Call({
            target: L1_TAIKO_DAO_CONTROLLER,
            value: 0,
            data: abi.encodeCall(UUPSUpgradeable.upgradeTo, (TAIKO_DAO_CONTROLLER_NEW_IMPL))
        });
    }

    function buildL2Calls() internal pure override returns (Multicall3.Call3[] memory calls) {
        calls = new Multicall3.Call3[](5);

        // Upgrade DelegateOwner to a new implementation
        calls[0].target = L2_DELEGATE_OWNER_PROXY;
        calls[0].allowFailure = true;
        calls[0].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (DELEGATE_OWNERE_NEW_IMPL));

        // Transfer 1 TAIKO to recipient
        calls[1].target = L2_TAIKO_TOKEN;
        calls[1].allowFailure = true;
        calls[1].callData = abi.encodeCall(IERC20.transfer, (RECIPIENT, 1 ether));

        // Upgrade TestDelegateOwned to a new implementation
        calls[2].target = TEST_CONTRACT_PROXY;
        calls[2].allowFailure = true;
        calls[2].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (TEST_CONTRACT_NEW_IMPL));

        // Transfer 0.001 Ether from TestDelegateOwned to recipient
        calls[3].target = TEST_CONTRACT_PROXY;
        calls[3].allowFailure = true;
        calls[3].callData =
            abi.encodeCall(ITestDelegateOwnedV2.withdraw, (address(0), RECIPIENT, 0.001 ether));

        // Transfer 1 TAIKO from TestDelegateOwned to recipient
        calls[4].target = TEST_CONTRACT_PROXY;
        calls[4].allowFailure = true;
        calls[4].callData =
            abi.encodeCall(ITestDelegateOwnedV2.withdraw, (L2_TAIKO_TOKEN, RECIPIENT, 1 ether));
    }
}
