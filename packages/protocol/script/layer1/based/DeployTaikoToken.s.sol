// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/shared/DeployCapability.sol";
import "src/layer1/token/TaikoToken.sol";

contract DeployTaikoToken is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    // MAINNET_SECURITY_COUNCIL: council.taiko.eth (0x7C50d60743D3FCe5a39FdbF687AFbAe5acFF49Fd)
    address public securityCouncil = vm.envAddress("SECURITY_COUNCIL");
    address public premintRecipient = vm.envAddress("TAIKO_TOKEN_PREMINT_RECIPIENT");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        // Deploy the TaikoToken contract, use securityCouncil address as the owner.
        deployProxy({
            name: "taiko_token",
            impl: address(new TaikoToken()),
            data: abi.encodeCall(TaikoToken.init, (securityCouncil, premintRecipient))
        });
    }
}
