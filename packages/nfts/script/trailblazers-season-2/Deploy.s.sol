// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsScript, MockBlacklist } from "./Utils.s.sol";
import { Script, console } from "forge-std/src/Script.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TrailblazersBadges } from "../../contracts/trailblazers-badges/TrailblazersBadges.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";
import { TrailblazersBadgesS2 } from
    "../../contracts/trailblazers-season-2/TrailblazersBadgesS2.sol";
import { TrailblazersBadgesV4 } from
    "../../contracts/trailblazers-season-2/TrailblazersS1BadgesV4.sol";
import { BadgeRecruitment } from "../../contracts/trailblazers-season-2/BadgeRecruitment.sol";

contract DeployS2Script is Script {
    UtilsScript public utils;
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    BadgeRecruitment recruitment;

    // Taiko Mainnet Values
    /*
    //address owner = 0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be;
    address claimMintSigner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address recruitmentSigner = 0x9Fc8d56c7376f9b062FEe7E02BAdFA670d603248;
    string baseURI =
    "https://taikonfts.4everland.link/ipfs/bafybeiatuzeeeznd3hi5qiulslxcjd22ebu45t4fra2jvi3smhocr2c66a";
    IMinimalBlacklist blacklist = IMinimalBlacklist(0xfA5EA6f9A13532cd64e805996a941F101CCaAc9a);

    uint256 public MAX_INFLUENCES = 5;
    uint256 public COOLDOWN_RECRUITMENT = 24 hours;
    uint256 public COOLDOWN_INFLUENCE = 30 minutes;
    uint256 public INFLUENCE_WEIGHT_PERCENT = 9;
    uint256 public MAX_INFLUENCES_DIVIDER = 100;
    uint256 public DEFAULT_CYCLE_DURATION = 7 days;
    uint256 public s1EndDate = 1_734_350_400; // Dec 16th 2024, noon UTC
    uint256 public S1_LOCK_DURATION = (s1EndDate - block.timestamp);
    */
    // Hekla Testnet Values
    string baseURI =
        "https://taikonfts.4everland.link/ipfs/bafybeiatuzeeeznd3hi5qiulslxcjd22ebu45t4fra2jvi3smhocr2c66a";

    IMinimalBlacklist blacklist = IMinimalBlacklist(0xe61E9034b5633977eC98E302b33e321e8140F105);
    address claimMintSigner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address recruitmentSigner = 0x3cda4F2EaC3fc2FdE78B3DFFe1A1A1Eff88c68c5;

    uint256 public MAX_INFLUENCES = 5;
    uint256 public COOLDOWN_RECRUITMENT = 5 minutes;
    uint256 public COOLDOWN_INFLUENCE = 1 minutes;
    uint256 public INFLUENCE_WEIGHT_PERCENT = 9;
    uint256 public MAX_INFLUENCES_DIVIDER = 100;
    uint256 public DEFAULT_CYCLE_DURATION = 7 days;
    uint256 public S1_LOCK_DURATION = 365 days;

    address s1Contract = 0xa20a8856e00F5ad024a55A663F06DCc419FFc4d5;

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();

        jsonLocation = utils.getContractJsonLocation();

        deployerPrivateKey = utils.getPrivateKey();
        deployerAddress = utils.getAddress();
    }

    function run() public {
        string memory jsonRoot = "root";
        address owner = deployerAddress;
        require(owner != address(0), "Owner must be specified");

        address impl;
        address proxy;
        TrailblazersBadgesV4 s1Token;
        TrailblazersBadgesS2 s2Token;

        vm.startBroadcast(deployerPrivateKey);

        if (block.chainid == 167_000) {
            // mainnet, use existing contract
            s1Token = TrailblazersBadgesV4(s1Contract);
        } else {
            // hekla/localhost, deploy a s1 contract
            impl = address(new TrailblazersBadges());
            blacklist = new MockBlacklist();
            proxy = address(
                new ERC1967Proxy(
                    impl,
                    abi.encodeCall(
                        TrailblazersBadges.initialize, (owner, baseURI, claimMintSigner, blacklist)
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
        }

        // deploy s2 contract
        impl = address(new TrailblazersBadgesS2());
        proxy = address(
            new ERC1967Proxy(
                impl, abi.encodeCall(TrailblazersBadgesS2.initialize, (address(owner), baseURI))
            )
        );

        s2Token = TrailblazersBadgesS2(proxy);

        // deploy the recruitment contract

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
        recruitment = BadgeRecruitment(proxy);

        // assign relations
        s1Token.setRecruitmentContract(address(recruitment));
        s2Token.setMinter(address(recruitment));

        // set the lock duration
        s1Token.setRecruitmentLockDuration(S1_LOCK_DURATION);

        console.log("Token Base URI:", baseURI);
        console.log("Deployed TrailblazersBadgesS2 to:", address(s2Token));
        console.log("Deployed BadgeRecruitment to:", address(recruitment));

        // Register deployment
        vm.serializeAddress(jsonRoot, "TrailblazersBadges", address(s1Token));
        vm.serializeAddress(jsonRoot, "TrailblazersBadgesS2", address(s2Token));
        vm.serializeAddress(jsonRoot, "BadgeRecruitment", address(recruitment));
        string memory finalJson = vm.serializeAddress(jsonRoot, "Owner", s2Token.owner());
        vm.writeJson(finalJson, jsonLocation);

        vm.stopBroadcast();
    }
}
