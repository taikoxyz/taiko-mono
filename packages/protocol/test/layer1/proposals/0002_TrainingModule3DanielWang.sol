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
    address private constant DELEGATE_OWNER_PROXY = 0xEfc270A7c1B34683Ff51e7cCe1B64626293237ed;
    address private constant DELEGATE_OWNERE_NEW_IMPL = 0xdC2FaA24e73207C32314E6E1595Da454F53c7f34;

    address private constant TEST_CONTRACT_PROXY = 0xB0de2DD046732Ae94B2570d4785dcd55F79a19c0;
    address private constant TEST_CONTRACT_NEW_IMPL = 0xd1934807041B168f383870A0d8F565aDe2DF9D7D;

    address private constant RECIPIENT = 0xe36C0F16d5fB473CC5181f5fb86b6Eb3299aD9cb;
    address private constant TAIKO_TOKEN_L2 = 0xA9d23408b9bA935c230493c40C73824Df71A0975;

    address private constant MULLTICALL3 = 0xcA11bde05977b3631167028862bE2a173976CA11;

    address private constant L1_BRIDGE = 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC;

    // FOUNDRY_PROFILE=layer1 forge test --mt test_gentx_0002_TrainingModule3DanielWang -vvv
    function test_gentx_0002_TrainingModule3DanielWang() public pure {
        Multicall3.Call3Value[] memory calls = new Multicall3.Call3Value[](6);

        // Upgrade DelegateOwner to a new implementation
        calls[0].target = DELEGATE_OWNER_PROXY;
        calls[0].allowFailure = false;
        calls[0].value = 0;
        calls[0].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (DELEGATE_OWNERE_NEW_IMPL));

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

        calls[5].target = MULLTICALL3;
        calls[5].allowFailure = false;
        calls[5].value = 0;
        calls[5].callData =
            abi.encodeCall(ITestDelegateOwnedV2.withdraw, (TAIKO_TOKEN_L2, RECIPIENT, 1 ether));

        bytes memory data = abi.encode(
            DelegateOwner.Call(
                uint64(0),
                MULLTICALL3,
                true, // DELEGATECALL
                abi.encodeCall(Multicall3.aggregate3Value, (calls))
            )
        );

        IBridge.Message memory message;
        message.destChainId = 167_000;
        message.srcChainId = 1;
        message.destOwner = RECIPIENT;
        message.data = abi.encodeCall(DelegateOwner.onMessageInvocation, (data));
        message.to = DELEGATE_OWNER_PROXY;

        console.log("To:", L1_BRIDGE);
        bytes memory txData = abi.encodeCall(IBridge.sendMessage, (message));
        console.logBytes(txData);
    }
}
