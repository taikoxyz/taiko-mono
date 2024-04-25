// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../test/DeployCapability.sol";
import "../contracts/L1/TaikoToken.sol";

contract DeployTaikoToken is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public securityCouncil = vm.envAddress("SECURITY_COUNCIL");
    string public tokenName = vm.envString("TAIKO_TOKEN_NAME");
    string public tokenSymbol = vm.envString("TAIKO_TOKEN_SYMBOL");
    address public premintRecipient = vm.envAddress("TAIKO_TOKEN_PREMINT_RECIPIENT");
    address public labMultisig = vm.envAddress("LAB_MULTI_SIG");
    address public treasuryMultisig = vm.envAddress("TREASURY_MULTI_SIG");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        address taikoToken = deployProxy({
            name: "taiko_token",
            impl: address(new TaikoToken()),
            data: abi.encodeCall(
                TaikoToken.init, (securityCouncil, tokenName, tokenSymbol, premintRecipient)
                )
        });

        TaikoToken(taikoToken).transfer(labMultisig, 1_000_000_000 ether / 2);
        TaikoToken(taikoToken).transfer(treasuryMultisig, 1_000_000_000 ether / 2);
    }
}
