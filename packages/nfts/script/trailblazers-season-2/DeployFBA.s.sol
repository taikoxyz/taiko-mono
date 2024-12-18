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
import { FactionBattleArena } from "../../contracts/trailblazers-season-2/FactionBattleArena.sol";

contract DeployFBA is Script {
    UtilsScript public utils;
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    // Taiko Mainnet Values
    //address owner = 0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be;
    //bytes32 root = 0xa7e510d5aed347e65609cf6f0e0738cdd752ffdf5980749057c634489fd09fc3;
    // string baseURI = "bafybeierqzehlrqeqqeb6fwmil4dj3ij2p6exgoj4lysl53fsxwob6wbdy";
    // IMinimalBlacklist blacklist = IMinimalBlacklist(0xfA5EA6f9A13532cd64e805996a941F101CCaAc9a);

    // Hekla Testnet Values
    bytes32 root = 0xf1359c4c4ba41a72025f2534ea8ad23c6b941b55a715838ebdc71202a78c6c87;
    string baseURI =
        "https://taikonfts.4everland.link/ipfs/bafybeiebmvj6roz4iuoinackb5c6eeshvppctkydrckqrnxexdnzh6odq4";

    IMinimalBlacklist blacklist = IMinimalBlacklist(0xe61E9034b5633977eC98E302b33e321e8140F105);
    address mintSigner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    // Hardhat Testnet Values
    //  address owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    //   address mintSigner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    //  string baseURI =        "https://taikonfts.4everland.link/ipfs/bafybeierqzehlrqeqqeb6fwmil4dj3ij2p6exgoj4lysl53fsxwob6wbdy";
    //   IMinimalBlacklist blacklist =
    // IMinimalBlacklist(0xe61E9034b5633977eC98E302b33e321e8140F105);

    address s1Contract = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();

        jsonLocation = utils.getContractJsonLocation();

        string memory projectRoot = vm.projectRoot();
        jsonLocation = string.concat(
            projectRoot, "/deployments/trailblazers-badges/", utils.lowercaseNetworkKey(), ".json"
        );

        deployerPrivateKey = utils.getPrivateKey();
        deployerAddress = utils.getAddress();
    }

    function run() public {
        string memory jsonRoot = "root";
        address owner = deployerAddress;
        require(owner != address(0), "Owner must be specified");

        address impl;
        address proxy;
        TrailblazersBadges s1Token;
        TrailblazersBadgesS2 s2Token;
        FactionBattleArena fba;

        vm.startBroadcast(deployerPrivateKey);

        if (block.chainid == 167_000) {
            // mainnet, use existing contract
            s1Token = TrailblazersBadges(s1Contract);
        } else {
            // hekla/localhost, deploy a s1 contract
            impl = address(new TrailblazersBadges());
            blacklist = new MockBlacklist();
            proxy = address(
                new ERC1967Proxy(
                    impl,
                    abi.encodeCall(
                        TrailblazersBadges.initialize, (owner, baseURI, mintSigner, blacklist)
                    )
                )
            );

            s1Token = TrailblazersBadges(proxy);
        }
        /*
        // deploy s2 contract
        impl = address(new TrailblazersBadgesS2());
        proxy = address(
            new ERC1967Proxy(
                impl,
        abi.encodeCall(TrailblazersBadgesS2.initialize, (address(s1Token), mintSigner))
            )
        );
        */
        s2Token = TrailblazersBadgesS2(proxy);

        console.log("Token Base URI:", baseURI);
        console.log("Deployed TrailblazersBadgesS2 to:", address(s2Token));

        // Deploy Badge Champions
        impl = address(new FactionBattleArena());
        proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(FactionBattleArena.initialize, (address(s1Token), address(s2Token)))
            )
        );

        fba = FactionBattleArena(proxy);

        // Register deployment

        vm.serializeAddress(jsonRoot, "TrailblazersBadges", address(s1Token));
        vm.serializeAddress(jsonRoot, "TrailblazersBadgesS2", address(s2Token));
        vm.serializeAddress(jsonRoot, "FactionBattleArena", address(fba));
        string memory finalJson = vm.serializeAddress(jsonRoot, "Owner", s2Token.owner());
        vm.writeJson(finalJson, jsonLocation);

        vm.stopBroadcast();
    }
}
