// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script, console } from "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import { UtilsScript } from "./Utils.s.sol";
import { Merkle } from "murky/Merkle.sol";
import "./CsvParser.sol";
import { MerkleWhitelist } from "../contracts/MerkleWhitelist.sol";
import { TaikoonToken } from "../contracts/TaikoonToken.sol";

contract MerkleMintersScript is Script {
    using stdJson for string;

    UtilsScript public utils;
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    TaikoonToken token;

    bytes32[] public leaves;

    bytes32 public root;

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

        string memory treeJson =
            vm.readFile(string.concat(vm.projectRoot(), "/data/whitelist/hardhat.json"));
        bytes memory treeRaw = treeJson.parseRaw(".tree");
        leaves = abi.decode(treeRaw, (bytes32[]));

        bytes memory rootRaw = treeJson.parseRaw(".root");
        root = abi.decode(rootRaw, (bytes32));
    }
    /*
    function getHoleskyCsvMinters()
        public
        view
        returns (uint256[] memory freeMints, address[] memory minters)
    {
        string memory csvPath = './data/whitelist/holesky.csv';
        string memory line = vm.readLine(csvPath);
        // extract header
        line = vm.readLine(csvPath);

        freeMints = new uint256[](10);
        minters = new address[](10);

        // read the csv lines
        bool linesLeft = true;
        uint256 lineCount = 0;
        while (linesLeft) {
            (uint256 _freeMints, address _minter) = CSVParser.parseLine(line);

            freeMints[lineCount] = _freeMints;
            minters[lineCount] = _minter;

            console.log(
                'Free mints: %s, Paid mints: %s, Minter: %s',
                freeMints[lineCount],
                minters[lineCount]
            );

            lineCount++;

            line = vm.readLine(csvPath);
            linesLeft = bytes(line).length >= 27;
        }

        return (freeMints, minters);
    }

    */

    function getHardhatCsvMinters()
        public
        view
        returns (uint256[] memory freeMints, address[] memory minters, bytes32[] memory)
    {
        uint256 minterCount = 5;
        string memory csvPath = "./data/whitelist/hardhat.csv";
        string memory line = vm.readLine(csvPath);
        // extract header
        line = vm.readLine(csvPath);

        freeMints = new uint256[](minterCount);
        minters = new address[](minterCount);

        // read the csv lines
        bool linesLeft = true;
        uint256 lineCount = 0;
        while (linesLeft) {
            (uint256 _freeMints, address _minter) = CSVParser.parseLine(line);

            freeMints[lineCount] = _freeMints;
            minters[lineCount] = _minter;

            console.log("Free mints: %s, Minter: %s", freeMints[lineCount], minters[lineCount]);

            lineCount++;

            line = vm.readLine(csvPath);
            linesLeft = bytes(line).length >= 27;
        }

        return (freeMints, minters, leaves);
    }

    function getMerkleData()
        public
        view
        returns (uint256[] memory freeMints, address[] memory minters, bytes32[] memory)
    {
        uint256 chainId = block.chainid;

        if (chainId == 31_337) {
            return getHardhatCsvMinters();
        } /*else if (chainId == 17000) {
            return getHoleskyCsvMinters();
        }*/ else {
            revert("Unsupported chainId");
        }
    }

    function getMerkleInfo() public view returns (bytes32, bytes32[] memory) {
        return (root, leaves);
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        Merkle tree = new Merkle();

        root = tree.getRoot(leaves);

        token.updateRoot(root);

        vm.stopBroadcast();
    }
}
