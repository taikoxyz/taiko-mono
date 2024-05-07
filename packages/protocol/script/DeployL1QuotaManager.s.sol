// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../test/DeployCapability.sol";
import "../contracts/bridge/QuotaManager.sol";

contract DeployL1QuotaManager is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    // MAINNET_SECURITY_COUNCIL: council.taiko.eth (0x7C50d60743D3FCe5a39FdbF687AFbAe5acFF49Fd)
    address public addressManager = vm.envAddress("L1_ROLLUP_ADDRESS_MANAGER");
    address public owner = vm.envAddress("OWNER");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        // Deploy the QuotaManager contract with a 15 minute quota period
        QuotaManager qm = QuotaManager(
            deployProxy({
                name: "quota_manager",
                impl: address(new QuotaManager()),
                data: abi.encodeCall(QuotaManager.init, (owner, addressManager, 15 minutes))
            })
        );

        // L2-to-L1 Ether per 15 minutes
        qm.updateQuota(address(0), 50 ether);

        // L2-to-L1 TKO per 15 minutes: 100_000 (0.01% total supply)
        qm.updateQuota(0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800, 100_000 ether);
    }
}
