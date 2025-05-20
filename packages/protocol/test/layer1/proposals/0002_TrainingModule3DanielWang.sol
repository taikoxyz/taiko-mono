// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/layer1/governance/TaikoDAOController.sol";
import "forge-std/src/Test.sol";
import "src/layer2/DelegateOwner.sol";
import "test/shared/thirdparty/Multicall3.sol";
import "src/shared/bridge/IBridge.sol";

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
// 	•	Transfer 0.001 Ether from DelegateOwner to a specified EOA
// 	•	Transfer 1 TAIKO token from DelegateOwner to the same EOA
// 	•	Upgrade the TestDelegateOwned contract (owned by DelegateOwner) to a new implementation
// 	•	Transfer 0.001 Ether from TestDelegateOwned to the same EOA
// 	•	Transfer 1 TAIKO token from TestDelegateOwned to the same EOA
contract TrainingModule3DanielWang is Test {
    // L2 Contracts
    address private constant DELEGATE_OWNER_PROXY = 0xEfc270A7c1B34683Ff51e7cCe1B64626293237ed;
    address private constant DELEGATE_OWNERE_NEW_IMPL = 0xdC2FaA24e73207C32314E6E1595Da454F53c7f34;

    address private constant TEST_CONTRACT_PROXY = 0xB0de2DD046732Ae94B2570d4785dcd55F79a19c0;
    address private constant TEST_CONTRACT_NEW_IMPL = 0xd1934807041B168f383870A0d8F565aDe2DF9D7D;

    address private constant RECIPIENT = 0xe36C0F16d5fB473CC5181f5fb86b6Eb3299aD9cb;
    address private constant TAIKO_TOKEN_L2 = 0xA9d23408b9bA935c230493c40C73824Df71A0975;

    address private constant MULLTICALL3 = 0xcA11bde05977b3631167028862bE2a173976CA11;

    // L1 contracts

    address private constant L1_BRIDGE = 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC;
    address private constant TAIKO_DAO_CONTROLLER = 0xfC3C4ca95a8C4e5a587373f1718CD91301d6b2D3;
    address private constant TAIKO_DAO_CONTROLLER_NEW_IMPL = address(0); // TODO

    // FOUNDRY_PROFILE=layer1 forge test --mt test_gentx_0002_TrainingModule3DanielWang -vvv
    function test_gentx_0002_TrainingModule3DanielWang() public pure {
        IBridge.Message memory message;
        {
            Multicall3.Call3Value[] memory calls = new Multicall3.Call3Value[](6);

            // Upgrade DelegateOwner to a new implementation
            calls[0].target = DELEGATE_OWNER_PROXY;
            calls[0].allowFailure = false;
            calls[0].value = 0;
            calls[0].callData =
                abi.encodeCall(UUPSUpgradeable.upgradeTo, (DELEGATE_OWNERE_NEW_IMPL));

            // Transfer 0.001 Ether from DelegateOwner to a specified EOA
            calls[1].target = RECIPIENT;
            calls[1].allowFailure = false;
            calls[1].value = 0.001 ether;
            calls[1].callData = "";

            calls[2].target = TAIKO_TOKEN_L2;
            calls[2].allowFailure = false;
            calls[2].value = 0;
            calls[2].callData = abi.encodeCall(IERC20.transfer, (RECIPIENT, 1 ether));

            calls[3].target = TEST_CONTRACT_PROXY;
            calls[3].allowFailure = false;
            calls[3].value = 0;
            calls[3].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (TEST_CONTRACT_NEW_IMPL));

            calls[4].target = TEST_CONTRACT_PROXY;
            calls[4].allowFailure = false;
            calls[4].value = 0;
            calls[4].callData =
                abi.encodeCall(ITestDelegateOwnedV2.withdraw, (address(0), RECIPIENT, 0.001 ether));

            calls[5].target = TEST_CONTRACT_PROXY;
            calls[5].allowFailure = false;
            calls[5].value = 0;
            calls[5].callData =
                abi.encodeCall(ITestDelegateOwnedV2.withdraw, (TAIKO_TOKEN_L2, RECIPIENT, 1 ether));

            bytes memory data = abi.encode(
                DelegateOwner.Call(
                    uint64(0), // nextTxId
                    MULLTICALL3,
                    true, // DELEGATECALL
                    abi.encodeCall(Multicall3.aggregate3Value, (calls))
                )
            );

            message.destChainId = 167_000;
            message.srcChainId = 1;
            message.destOwner = RECIPIENT;
            message.data = abi.encodeCall(DelegateOwner.onMessageInvocation, (data));
            message.to = DELEGATE_OWNER_PROXY;
        }

        TaikoDAOController.Call[] memory _calls = new TaikoDAOController.Call[](2);

        // Upgrade FooUpgradeable's implementation from V1 to V2
        _calls[0] = TaikoDAOController.Call({
            target: TAIKO_DAO_CONTROLLER,
            value: 0,
            data: abi.encodeCall(UUPSUpgradeable.upgradeTo, (TAIKO_DAO_CONTROLLER_NEW_IMPL))
        });

        // Send 1 TaikoToken from TaikoDAOController to DanielWang
        _calls[1] = TaikoDAOController.Call({
            target: L1_BRIDGE,
            value: 0,
            data: abi.encodeCall(IBridge.sendMessage, (message))
        });

        for (uint256 i = 0; i < _calls.length; i++) {
            console2.log("-------------- call", i, "--------------");
            console2.log(_calls[i].target);
            console2.log(_calls[i].value);
            console2.logBytes(_calls[i].data);
        }
    }
}
