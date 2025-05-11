// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/layer1/governance/TaikoDAOController.sol";
import "forge-std/src/Test.sol";
import "forge-std/src/console2.sol";

contract ProposalExercise1 is Test {
    address private constant TO_ADDRESS = 0x992E727e73a8b5b31865646Bb16F9DC3955373ae;

    address private constant TAIKO_DAO_CONTROLLER = 0xfC3C4ca95a8C4e5a587373f1718CD91301d6b2D3;
    address private constant TAIKO_TOKEN = 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;

    address private constant FOO_UPGRADEABLE = 0xD1Ed20C8fEc53db3274c2De09528f45dF6c06A65;
    address private constant FOO_UPGRADEABLE_V1 = 0xdC2FaA24e73207C32314E6E1595Da454F53c7f34;
    address private constant FOO_UPGRADEABLE_V2 = 0x4EBeC8a624ac6f01Bb6C7F13947E6Af3727319CA;

    // FOUNDRY_PROFILE=layer1 forge test --mt test_ProposalExercise1 -vvv
    function test_ProposalExercise1() public pure {
        TaikoDAOController.Call[] memory calls = new TaikoDAOController.Call[](3);

        // Upgrade FooUpgradeable's implementation from V1 to V2
        calls[0] = TaikoDAOController.Call({
            target: FOO_UPGRADEABLE,
            value: 0,
            data: abi.encodeCall(UUPSUpgradeable.upgradeTo, (FOO_UPGRADEABLE_V2))
        });

        // Send 1 TaikoToken from TaikoDAOController to DanielWang
        calls[1] = TaikoDAOController.Call({
            target: TAIKO_TOKEN,
            value: 0,
            data: abi.encodeCall(IERC20.transfer, (TO_ADDRESS, 1 ether))
        });

        // Send 0.001 Ether from TaikoDAOController to 0x992E727e73a8b5b31865646Bb16F9DC3955373ae
        calls[2] = TaikoDAOController.Call({ target: TO_ADDRESS, value: 0.001 ether, data: "" });

        bytes memory data = abi.encodeCall(TaikoDAOController.execute, (calls));

        console2.log("to:");
        console2.log(TAIKO_DAO_CONTROLLER);
        console2.log("value:");
        console2.logUint(0);
        console2.log("data:");
        console2.logBytes(data);
    }
}
