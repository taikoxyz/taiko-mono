// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { Bridge } from "../contracts/bridge/Bridge.sol";
import { ICrossChainSync } from "../contracts/common/ICrossChainSync.sol";

abstract contract TestBase is Test {
    uint256 private _seed = 0x12345678;

    function getRandomAddress() internal returns (address) {
        bytes32 randomHash = keccak256(abi.encodePacked("address", _seed++));
        return address(bytes20(randomHash));
    }

    function getRandomBytes32() internal returns (bytes32) {
        return keccak256(abi.encodePacked("bytes32", _seed++));
    }

    function getRandomUint256() internal returns (uint256) {
        return uint256(keccak256(abi.encodePacked("uint256", _seed++)));
    }

    address internal Alice = getRandomAddress();
    address internal Bob = getRandomAddress();
    address internal Carol = getRandomAddress();
    address internal David = getRandomAddress();
    address internal Emma = getRandomAddress();
    address internal Frank = getRandomAddress();
    address internal Grace = getRandomAddress();
    address internal Henry = getRandomAddress();
    address internal Isabella = getRandomAddress();
    address internal James = getRandomAddress();
    address internal Katherine = getRandomAddress();
    address internal Liam = getRandomAddress();
    address internal Mia = getRandomAddress();
    address internal Noah = getRandomAddress();
    address internal Olivia = getRandomAddress();
    address internal Patrick = getRandomAddress();
    address internal Quinn = getRandomAddress();
    address internal Rachel = getRandomAddress();
    address internal Samuel = getRandomAddress();
    address internal Taylor = getRandomAddress();
    address internal Ulysses = getRandomAddress();
    address internal Victoria = getRandomAddress();
    address internal William = getRandomAddress();
    address internal Xavier = getRandomAddress();
    address internal Yasmine = getRandomAddress();
    address internal Zachary = getRandomAddress();
}

contract BadReceiver {
    receive() external payable {
        revert("can not send to this contract");
    }

    fallback() external payable {
        revert("can not send to this contract");
    }

    function transfer() public pure {
        revert("this fails");
    }
}

contract GoodReceiver {
    receive() external payable { }

    function forward(address addr) public payable {
        payable(addr).transfer(address(this).balance / 2);
    }
}

// NonNftContract
contract NonNftContract {
    uint256 dummyData;

    constructor(uint256 _dummyData) {
        dummyData = _dummyData;
    }
}

contract SkipProofCheckBridge is Bridge {
    function shouldCheckProof() internal pure override returns (bool) {
        return false;
    }
}

contract DummyCrossChainSync is ICrossChainSync {
    bytes32 private _blockHash;
    bytes32 private _signalRoot;

    function setCrossChainBlockHeader(bytes32 blockHash) external {
        _blockHash = blockHash;
    }

    function setCrossChainSignalRoot(bytes32 signalRoot) external {
        _signalRoot = signalRoot;
    }

    function getCrossChainBlockHash(uint64) external view returns (bytes32) {
        return _blockHash;
    }

    function getCrossChainSignalRoot(uint64) external view returns (bytes32) {
        return _signalRoot;
    }
}
