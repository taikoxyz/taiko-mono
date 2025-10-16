// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsScript } from "./Utils.s.sol";
import { Script, console } from "forge-std/src/Script.sol";
import { BadgeRecruitment } from "../../contracts/trailblazers-season-2/BadgeRecruitment.sol";
import { BadgeRecruitmentV2 } from "../../contracts/trailblazers-season-2/BadgeRecruitmentV2.sol";

contract UpgradeRecruitmentsV2 is Script {
    UtilsScript public utils;
    string public jsonLocation;
    uint256 public deployerPrivateKey;

    address recruitmentAddress = 0xa9Ceb04F3aF71fF123409d426A92BABb5124970C;
    BadgeRecruitment public recruitmentV1;
    BadgeRecruitmentV2 public recruitmentV2;

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();

        jsonLocation = utils.getContractJsonLocation();
        deployerPrivateKey = utils.getPrivateKey();
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        recruitmentV1 = BadgeRecruitment(recruitmentAddress);

        recruitmentV1.upgradeToAndCall(
            address(new BadgeRecruitmentV2()), abi.encodeCall(BadgeRecruitmentV2.version, ())
        );

        recruitmentV2 = BadgeRecruitmentV2(address(recruitmentV1));

        console.log("Upgraded BadgeRecruitmentV2 to:", address(recruitmentV2));
    }
}
