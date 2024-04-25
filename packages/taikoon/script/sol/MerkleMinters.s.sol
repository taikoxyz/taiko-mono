// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script, console } from "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import { UtilsScript } from "./Utils.s.sol";
import { Merkle } from "murky/Merkle.sol";
import "./CsvParser.sol";
import { MerkleWhitelist } from "../../contracts/MerkleWhitelist.sol";
import { TaikoonToken } from "../../contracts/TaikoonToken.sol";

contract MerkleMintersScript is Script {
    using stdJson for string;

    UtilsScript public utils;
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    TaikoonToken token;

    // bytes32[] public leaves;

    //  bytes32[] public holeskyLeaves;

    bytes32 public holeskyRoot;

    bytes32 public localhostRoot;

    string public hardhatTreeJson;
    string public holeskyTreeJson;

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

        hardhatTreeJson = vm.readFile(
            string.concat(vm.projectRoot(), '/data/whitelist/hardhat.json')
        );
        //bytes memory treeRaw = hardhatTreeJson.parseRaw('.tree');
        // leaves = abi.decode(treeRaw, (bytes32[]));

        bytes memory rootRaw = hardhatTreeJson.parseRaw('.root');
        localhostRoot = abi.decode(rootRaw, (bytes32));

        holeskyTreeJson = vm.readFile(
            string.concat(vm.projectRoot(), '/data/whitelist/holesky.json')
        );

        // treeRaw = holeskyTreeJson.parseRaw('.tree');
        //   holeskyLeaves = abi.decode(treeRaw, (bytes32[]));
        rootRaw = holeskyTreeJson.parseRaw('.root');
        holeskyRoot = abi.decode(rootRaw, (bytes32));
    }

    function getMerkleRoot() public view returns (bytes32) {
        uint256 chainId = block.chainid;
        if (chainId == 31337) {
            return localhostRoot;
        } else if (chainId == 17000) {
            return holeskyRoot;
        } else {
            revert('Unsupported chainId');
        }
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        uint256 chainId = block.chainid;

        bytes32 root = getMerkleRoot();
        bytes32[] memory leaves;
        if (chainId == 31337) {
            // hardhat/localhost
            bytes memory treeRaw = hardhatTreeJson.parseRaw('.tree');
            leaves = abi.decode(treeRaw, (bytes32[]));
        } else if (chainId == 17000) {
            // holesky
            bytes memory treeRaw = holeskyTreeJson.parseRaw('.tree');
            leaves = abi.decode(treeRaw, (bytes32[]));
        } else {
            revert('Unsupported chainId');
        }

        Merkle tree = new Merkle();

        root = tree.getRoot(leaves);

        token.updateRoot(root);

        vm.stopBroadcast();
    }
}
