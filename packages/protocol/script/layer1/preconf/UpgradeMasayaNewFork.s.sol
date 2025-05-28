// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/DeployCapability.sol";
import "src/layer1/devnet/DevnetInbox.sol";
import "src/layer1/fork-router/PacayaForkRouter.sol";

contract UpgradeMasayaNewFork is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        address oldFork = 0x738944F4F2cEBb02a39c65995e666BA4dca9f727;
        address newForkForOldPacayaForkRouter = 0x968e883f6E3C75921FD491BBDC93eE60c3A519E3;
        address oldPacayaForkRouter = 0x91fB29469450f0Aef0Fd9A1A8e0C41d073648681;
        address taikoWrapper = 0xBB18fAB616E90B396408CA0F84036cD2c504e446;
        address verifier = 0xf8e2351de104497D74Da1355034f9013204F9a8C;
        address bondToken = 0xCC8cbD7c8Fd796E46b08e1C7202D79ce145e63a3;
        address signalService = 0xd7Df34aB958f60A7522eADb35FdE74b748f1fC75;
        address taikoInbox = 0xd25769EFD97d42076fCB7Ae568D7F7d315f52A1f;
        uint24 PRECONF_COOLDOWN_WINDOW = 0 hours;

        // Register taiko
        address newFork = address(
            new DevnetInbox(
                167_011, PRECONF_COOLDOWN_WINDOW, taikoWrapper, verifier, bondToken, signalService
            )
        );
        UUPSUpgradeable(taikoInbox).upgradeTo(address(new PacayaForkRouter(oldFork, newFork)));
    }
}
