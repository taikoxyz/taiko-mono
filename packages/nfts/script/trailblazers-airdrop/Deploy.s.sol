// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsScript } from "./Utils.s.sol";
import { Script, console } from "forge-std/src/Script.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TrailblazersBadges } from "../../contracts/trailblazers-badges/TrailblazersBadges.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";
import { ERC20Airdrop } from "../../contracts/trailblazers-airdrop/ERC20Airdrop.sol";
import { ERC20Mock } from "../../test/util/MockTokens.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { MockBlacklist } from "../../test/util/Blacklist.sol";

contract DeployScript is Script {
    UtilsScript public utils;
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    // only used for production
    IMinimalBlacklist blacklist = IMinimalBlacklist(0xe61E9034b5633977eC98E302b33e321e8140F105);

    ERC20Airdrop public airdrop;
    uint256 constant TOTAL_AVAILABLE_FUNDS = 1000 ether;

    uint256 constant CLAIM_AMOUNT = 10 ether;

    // hekla test root
    bytes32 public merkleRoot = 0xbe8ec647626f95185f551887b3eee43ea9e8965c7baf558a9f8cb22b020597f0;

    // rewards token
    ERC20Upgradeable public erc20;
    ERC20Mock public mockERC20;
    // start and end times for the claim
    uint64 constant CLAIM_DURATION = 30 days;
    uint64 public CLAIM_START = uint64(block.timestamp);
    uint64 public CLAIM_END = CLAIM_START + CLAIM_DURATION;

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();

        jsonLocation = utils.getContractJsonLocation();
        deployerPrivateKey = utils.getPrivateKey();
        deployerAddress = utils.getAddress();

        vm.startBroadcast(deployerPrivateKey);

        if (block.chainid != 167_000) {
            // not mainnet, create mock contracts
            blacklist = new MockBlacklist();
            mockERC20 = new ERC20Mock();
            // mint the necessary funds
            erc20 = ERC20Upgradeable(address(mockERC20));
        }

        vm.stopBroadcast();
    }

    function run() public {
        string memory jsonRoot = "root";

        vm.startBroadcast(deployerPrivateKey);

        // deploy token with empty root
        address impl = address(new ERC20Airdrop());
        address proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(
                    ERC20Airdrop.init,
                    (deployerAddress, CLAIM_START, CLAIM_END, merkleRoot, erc20, address(blacklist))
                )
            )
        );

        airdrop = ERC20Airdrop(proxy);

        // mint the necessary funds on hekla
        if (block.chainid != 167_000) {
            mockERC20.mint(address(airdrop), TOTAL_AVAILABLE_FUNDS);
        }
        console.log("ERC20 Token:", address(erc20));

        console.log("Deployed ERC20Airdrop to:", address(airdrop));

        vm.serializeBytes32(jsonRoot, "MerkleRoot", merkleRoot);
        string memory finalJson = vm.serializeAddress(jsonRoot, "ERC20Airdrop", address(airdrop));
        vm.writeJson(finalJson, jsonLocation);

        vm.stopBroadcast();
    }
}
