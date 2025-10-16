// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script, console } from "forge-std/src/Script.sol";
import "forge-std/src/StdJson.sol";
import { UtilsScript } from "./Utils.s.sol";
import { Merkle } from "murky/Merkle.sol";
import "./CsvParser.sol";
import { MerkleWhitelist } from "../../../contracts/taikoon/MerkleWhitelist.sol";
import { TaikoonToken } from "../../../contracts/taikoon/TaikoonToken.sol";

contract MerkleMintersScript is Script {
    using stdJson for string;

    UtilsScript public utils;
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    TaikoonToken token;

    bytes32 public holeskyRoot;
    bytes32 public localhostRoot;
    bytes32 public devnetRoot;

    string public hardhatTreeJson;
    string public holeskyTreeJson;
    string public devnetTreeJson;

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();

        deployerPrivateKey = utils.getPrivateKey();
        deployerAddress = utils.getAddress();

        string memory path = utils.getContractJsonLocation();
        string memory json = vm.readFile(path);

        // TaikoonToken
        bytes memory addressRaw = json.parseRaw(".TaikoonToken");
        address tokenAddress = abi.decode(addressRaw, (address));
        token = TaikoonToken(tokenAddress);

        // load hardhat's tree and root
        hardhatTreeJson =
            vm.readFile(string.concat(vm.projectRoot(), "/data/taikoon/whitelist/hardhat.json"));

        bytes memory rootRaw = hardhatTreeJson.parseRaw(".root");
        localhostRoot = abi.decode(rootRaw, (bytes32));

        // load holesky's tree and root
        holeskyTreeJson =
            vm.readFile(string.concat(vm.projectRoot(), "/data/taikoon/whitelist/holesky.json"));

        rootRaw = holeskyTreeJson.parseRaw(".root");
        holeskyRoot = abi.decode(rootRaw, (bytes32));

        // load devnet's tree and root
        devnetTreeJson =
            vm.readFile(string.concat(vm.projectRoot(), "/data/taikoon/whitelist/devnet.json"));
        rootRaw = devnetTreeJson.parseRaw(".root");
        devnetRoot = abi.decode(rootRaw, (bytes32));
    }

    function getMerkleRoot() public view returns (bytes32) {
        uint256 chainId = block.chainid;
        if (chainId == 31_337) {
            return localhostRoot;
        } else if (chainId == 17_000) {
            return holeskyRoot;
        } else if (chainId == 167_001) {
            return devnetRoot;
        } else {
            revert("Unsupported chainId");
        }
    }
}
