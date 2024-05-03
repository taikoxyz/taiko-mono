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
        // Deploy the TaikoToken contract, use securityCouncil address as the owner.
        QuotaManager qm = QuotaManager(
            deployProxy({
                name: "quota_manager",
                impl: address(new QuotaManager()),
                data: abi.encodeCall(QuotaManager.init, (owner, addressManager))
            })
        );

        // L2-to-L1 Ether per day: 25_000 Ether
        qm.updateDailyQuota(address(0), 25_000 ether);

        // L2-to-L1 TKO per day: 10 million (1% total supply)
        qm.updateDailyQuota(0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800, 10_000_000 ether);
    }
}
