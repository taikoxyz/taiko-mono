// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../contracts/TokenUnlocking.sol";

contract VestToken is Script {
    using stdJson for string;

    struct VestTokenRecipient {
        bytes32 nameBytes; // Conversion from json "string" to bytes32 will take place in foundry,
            // cannot use string here, as json parser cannot interpret string from json, everything
            // is bytes-chunks. It is more of informational to script executor anyways.
        address recipient;
        address unlockingContractProxyAddress;
        uint256 vestAmount;
    }

    struct VestTokenJsonData {
        VestTokenRecipient[] tokenVests;
    }

    uint256 public CONTRACT_DEPLOYER_PRIV_KEY = vm.envUint("CONTRACT_DEPLOYER_PK"); // Who can call
        // the vest() function
    uint256 public VAULT_OWNER_PRIV_KEY = vm.envUint("VAULT_OWNER_PK"); // Who can call the
        // approve()
        // function
    address public TAIKO_TOKEN = vm.envAddress("TAIKO_TOKEN");

    string internal vestingDataJsonPath = "/script/vesting-token-data/example-vest-token-data.json";

    function setUp() public { }

    function run() external {
        string memory vestingsJsonStr =
            vm.readFile(string.concat(vm.projectRoot(), vestingDataJsonPath));
        bytes memory vestingsPacked = vm.parseJson(vestingsJsonStr);

        console2.logBytes(vestingsPacked);

        VestTokenJsonData memory recipients = abi.decode(vestingsPacked, (VestTokenJsonData));

        for (uint256 i; i < recipients.tokenVests.length; i++) {
            address recipientUnlockingContract =
                recipients.tokenVests[i].unlockingContractProxyAddress;
            uint128 vestAmount = uint128(recipients.tokenVests[i].vestAmount * 1e18);

            console2.log("Grantee address:", recipients.tokenVests[i].recipient);
            console2.log("Grantee unlocking contract address:", recipientUnlockingContract);
            console2.log("Vest amount(inTKO):", vestAmount);
            console2.log("\n");

            vm.startBroadcast(VAULT_OWNER_PRIV_KEY);
            ERC20(TAIKO_TOKEN).approve(recipientUnlockingContract, vestAmount);
            vm.stopBroadcast();

            vm.startBroadcast(CONTRACT_DEPLOYER_PRIV_KEY);
            TokenUnlocking(recipientUnlockingContract).vest(vestAmount);
            vm.stopBroadcast();
        }

        vm.stopBroadcast();
    }
}
