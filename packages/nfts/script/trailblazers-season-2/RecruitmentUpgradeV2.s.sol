// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsScript, MockBlacklist } from "./Utils.s.sol";
import { Script, console } from "forge-std/src/Script.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TrailblazersBadges } from "../../contracts/trailblazers-badges/TrailblazersBadges.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";

import "../../contracts/trailblazers-season-2/TrailblazersBadgesS2.sol";

import "../../contracts/trailblazers-season-2/TrailblazersS1BadgesV5.sol";

contract UpgradeV2 is Script {
    // setup
    UtilsScript public utils;
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    // deployment vars
    TrailblazersBadgesV5 public tokenV5;
    BadgeRecruitmentV2 public badgeRecruitmentV2;

    // mainnet config
    address public s1TokenAddress = 0xa20a8856e00F5ad024a55A663F06DCc419FFc4d5;
    address public badgeRecruitmentAddress = 0xa9Ceb04F3aF71fF123409d426A92BABb5124970C;

    // hekla config
    string baseURI =
        "https://taikonfts.4everland.link/ipfs/bafybeiatuzeeeznd3hi5qiulslxcjd22ebu45t4fra2jvi3smhocr2c66a";

    IMinimalBlacklist blacklist = IMinimalBlacklist(0xe61E9034b5633977eC98E302b33e321e8140F105);
    address claimMintSigner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address recruitmentSigner = 0x3cda4F2EaC3fc2FdE78B3DFFe1A1A1Eff88c68c5;

    uint256 public MAX_INFLUENCES = 5;
    uint256 public COOLDOWN_RECRUITMENT = 10 minutes;
    uint256 public COOLDOWN_INFLUENCE = 5 minutes;
    uint256 public INFLUENCE_WEIGHT_PERCENT = 9;
    uint256 public MAX_INFLUENCES_DIVIDER = 100;
    uint256 public DEFAULT_CYCLE_DURATION = 7 days;
    uint256 public s1EndDate = 1_734_350_400; // Dec 16th 2024, noon UTC
    uint256 public S1_LOCK_DURATION = (s1EndDate - block.timestamp);

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();

        jsonLocation = utils.getContractJsonLocation();
        deployerPrivateKey = utils.getPrivateKey();
        deployerAddress = utils.getAddress();
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        address impl;
        address proxy;
        TrailblazersBadgesV4 s1Token;
        TrailblazersBadgesS2 s2Token;
        BadgeRecruitment badgeRecruitment;

        if (block.chainid == 167_000) {
            // mainnet, use existing contract
            s1Token = TrailblazersBadgesV4(s1TokenAddress);
            badgeRecruitment = BadgeRecruitment(badgeRecruitmentAddress);
        } else {
            // non-mainnet, deploy contract chain
            impl = address(new TrailblazersBadges());
            blacklist = new MockBlacklist();
            proxy = address(
                new ERC1967Proxy(
                    impl,
                    abi.encodeCall(
                        TrailblazersBadges.initialize,
                        (deployerAddress, baseURI, claimMintSigner, blacklist)
                    )
                )
            );

            TrailblazersBadges s1TokenV2 = TrailblazersBadges(proxy);

            // upgrade s1 contract to v4
            s1TokenV2.upgradeToAndCall(
                address(new TrailblazersBadgesV4()),
                abi.encodeCall(TrailblazersBadgesV4.version, ())
            );

            s1Token = TrailblazersBadgesV4(address(s1TokenV2));

            s1Token.setRecruitmentLockDuration(S1_LOCK_DURATION);

            // deploy recruitment contract
            BadgeRecruitment.Config memory config = BadgeRecruitment.Config(
                COOLDOWN_RECRUITMENT,
                COOLDOWN_INFLUENCE,
                INFLUENCE_WEIGHT_PERCENT,
                MAX_INFLUENCES,
                MAX_INFLUENCES_DIVIDER,
                DEFAULT_CYCLE_DURATION
            );
            impl = address(new BadgeRecruitment());
            proxy = address(
                new ERC1967Proxy(
                    impl,
                    abi.encodeCall(
                        BadgeRecruitment.initialize,
                        (address(s1Token), address(s2Token), recruitmentSigner, config)
                    )
                )
            );

            badgeRecruitment = BadgeRecruitment(proxy);

            // s2 token
            impl = address(new TrailblazersBadgesS2());
            proxy = address(
                new ERC1967Proxy(
                    impl,
                    abi.encodeCall(TrailblazersBadgesS2.initialize, (deployerAddress, baseURI))
                )
            );

            s2Token = TrailblazersBadgesS2(proxy);

            // overwrite json deployment data
            string memory jsonRoot = "root";
            vm.serializeAddress(jsonRoot, "TrailblazersBadges", address(s1Token));
            vm.serializeAddress(jsonRoot, "TrailblazersBadgesS2", address(s2Token));
            vm.serializeAddress(jsonRoot, "BadgeRecruitment", address(badgeRecruitment));
            string memory finalJson = vm.serializeAddress(jsonRoot, "Owner", s2Token.owner());
            vm.writeJson(finalJson, jsonLocation);
        }

        // upgrade token contract
        s1Token.upgradeToAndCall(
            address(new TrailblazersBadgesV5()), abi.encodeCall(TrailblazersBadgesV5.version, ())
        );

        tokenV5 = TrailblazersBadgesV5(address(s1Token));
        console.log("Upgraded TrailblazersBadgesV4 to:", address(tokenV5));

        // upgrade recruitment contract
        badgeRecruitment.upgradeToAndCall(
            address(new BadgeRecruitmentV2()), abi.encodeCall(BadgeRecruitmentV2.version, ())
        );

        badgeRecruitmentV2 = BadgeRecruitmentV2(address(badgeRecruitment));
        console.log("Upgraded BadgeRecruitment to:", address(badgeRecruitmentV2));

        // set upgraded recruitment contract
        tokenV5.setRecruitmentContractV2(address(badgeRecruitmentV2));
        console.log("Set recruitment contract to:", address(badgeRecruitmentV2));

        /*
        token.upgradeToAndCall(
        address(new TrailblazersBadgesS2()), abi.encodeCall(TrailblazersBadgesS2.version, ())
        );

        token = TrailblazersBadgesS2(address(token));

        console.log("Upgraded TrailblazersBadgesV3 to:", address(token));

        // update uri
        token.setUri(
        "https://taikonfts.4everland.link/ipfs/bafybeief7o4u6f676e6uz4yt4cv34ai4mesd7motoq6y4xxaoyjfbna5de"
        );
        console.log("Updated token URI");*/
    }
}
